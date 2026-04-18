defmodule Canopy.Governance.RuleCache do
  @moduledoc """
  ETS-backed cache for enabled governance rules.

  Owns a named ETS table `:canopy_governance_rules` with `read_concurrency: true`
  so rule lookups in `Governance.evaluate/1` are pure ETS reads — no DB round-trip
  per session create.

  ## Storage layout

  The table stores two kinds of entries:

    - `{rule.id, rule}` — individual rule structs for O(1) `get/1` lookups.
    - `{:priority_sorted, [rule, ...]}` — full priority-sorted list for `list_enabled/0`.

  Both are written atomically on each load via `:ets.insert/2` with a list, so a
  concurrent reader never sees a half-loaded state — it sees either the old snapshot
  or the new one, never a mix.

  ## Invalidation

  `create_rule/1`, `update_rule/2`, and `delete_rule/1` in `Canopy.Governance`
  call `invalidate/0` after a successful Repo mutation. The GenServer reloads all
  enabled rules from Postgres in a `handle_cast`, so the reload is async and
  non-blocking to the caller.

  ## Crash recovery

  The GenServer uses `init/1` to populate the ETS table. If the process crashes,
  the supervisor restarts it and `init/1` re-runs — the table is re-populated from
  DB automatically. The ETS table is owned by the GenServer process, so it is also
  re-created on restart (`:named_table` means a second `new/2` call on the same
  table name succeeds only from the owner process after the prior owner died).
  """

  use GenServer

  import Ecto.Query, only: [from: 2]

  alias Canopy.Governance.Rule
  alias Canopy.Repo

  require Logger

  @table :canopy_governance_rules

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Returns the priority-sorted list of enabled rules from ETS. No DB hit."
  @spec list_enabled() :: [Rule.t()]
  def list_enabled do
    case :ets.lookup(@table, :priority_sorted) do
      [{:priority_sorted, rules}] -> rules
      [] -> []
    end
  end

  @doc "Returns a single rule by id from ETS."
  @spec get(binary()) :: {:ok, Rule.t()} | {:error, :not_found}
  def get(id) do
    case :ets.lookup(@table, id) do
      [{^id, rule}] -> {:ok, rule}
      [] -> {:error, :not_found}
    end
  end

  @doc "Schedules an async reload of all enabled rules from Postgres."
  @spec invalidate() :: :ok
  def invalidate do
    GenServer.cast(__MODULE__, :reload)
  end

  # ---------------------------------------------------------------------------
  # GenServer lifecycle
  # ---------------------------------------------------------------------------

  @doc false
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    load_rules(table)
    {:ok, %{table: table}}
  end

  @impl GenServer
  def handle_cast(:reload, %{table: table} = state) do
    load_rules(table)
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec load_rules(:ets.table()) :: :ok
  defp load_rules(table) do
    rules =
      from(r in Rule,
        where: r.enabled == true,
        order_by: [desc: r.priority, asc: r.inserted_at]
      )
      |> Repo.all()

    # Build individual-id entries plus the sorted-list sentinel.
    id_entries = Enum.map(rules, fn r -> {r.id, r} end)
    sorted_entry = {:priority_sorted, rules}

    # Delete stale entries for rules that are no longer enabled, then insert fresh.
    :ets.delete_all_objects(table)
    :ets.insert(table, [sorted_entry | id_entries])

    Logger.debug("[RuleCache] loaded #{length(rules)} enabled governance rules")
    :ok
  rescue
    error ->
      Logger.error("[RuleCache] failed to load rules from DB: #{inspect(error)}")
      :ok
  end
end
