defmodule Canopy.Analytics.Breadcrumbs do
  @moduledoc """
  In-memory ring buffer of breadcrumbs per active run.

  Each `add/2` push goes to a per-run ring capped at the configured
  `max_per_run` (default 100, max 1000 — configurable per agent persona).
  When `flush_run/1` is called (on run completion, error, or shutdown),
  all buffered breadcrumbs are persisted via
  `Canopy.Analytics.record_breadcrumbs/1` and the run's buffer is dropped.

  ## Concurrency model

  Two ETS tables, both `:public` so any process writes directly:

  - `:canopy_analytics_breadcrumb_counters` (`:set`) — atomic monotonic
    sequence counter per `run_id`. Incremented via `:ets.update_counter/4`,
    which is atomic against concurrent writers.
  - `:canopy_analytics_breadcrumbs` (`:ordered_set`) — keyed by
    `{run_id, sequence}`. Range queries via `select_*` with bounded match
    specs are O(log n + k).

  The owning GenServer only manages table lifecycle. Reads and writes hit
  the tables directly with no GenServer round-trip.

  ## Trimming

  The ring keeps only the most recent `max` entries per run. Trim happens
  inline on every `add`. Because counter increments are atomic and ordered,
  the oldest entry to drop has key `{run_id, current - max}`.

  ## Usage

      Canopy.Analytics.Breadcrumbs.add(run_id, %{
        type: "tool_call",
        category: "read_file",
        level: "info",
        message: "read README.md",
        data: %{path: "README.md", bytes: 1234}
      })

      # On completion:
      Canopy.Analytics.Breadcrumbs.flush_run(run_id)
  """

  use GenServer

  alias Canopy.Analytics

  require Logger

  @table :canopy_analytics_breadcrumbs
  @counters :canopy_analytics_breadcrumb_counters
  @default_max 100
  @hard_max 1000

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Adds a breadcrumb for `run_id`. Returns `:ok` immediately; capped at the
  per-run `max` (oldest dropped first).

  `attrs` may contain: `type`, `category`, `level`, `message`, `data`,
  `session_id`, `ts` (defaults to `DateTime.utc_now/0`).

  Concurrent calls for the same `run_id` are safe — the sequence counter is
  incremented atomically.
  """
  @spec add(Ecto.UUID.t(), map(), pos_integer()) :: :ok
  def add(run_id, attrs, max \\ @default_max)
      when is_binary(run_id) and is_map(attrs) do
    max = clamp(max, 1, @hard_max)

    case next_sequence(run_id) do
      {:ok, seq} ->
        entry =
          attrs
          |> Map.put(:run_id, run_id)
          |> Map.put(:sequence, seq)
          |> Map.put_new(:ts, DateTime.utc_now())
          |> Map.put_new(:level, "info")
          |> Map.put_new(:data, %{})

        :ets.insert(@table, {{run_id, seq}, entry})
        trim(run_id, seq, max)
        :ok

      :not_initialized ->
        Logger.warning("[Breadcrumbs] add called before init; dropping for #{run_id}")
        :ok
    end
  end

  @doc """
  Returns all breadcrumbs currently buffered for `run_id`, ordered by sequence.
  """
  @spec list(Ecto.UUID.t()) :: [map()]
  def list(run_id) when is_binary(run_id) do
    pattern = [{{{run_id, :"$1"}, :"$2"}, [], [:"$2"]}]

    @table
    |> :ets.select(pattern)
    |> Enum.sort_by(& &1.sequence)
  rescue
    ArgumentError -> []
  end

  @doc """
  Returns the count of buffered breadcrumbs for `run_id`.
  """
  @spec count(Ecto.UUID.t()) :: non_neg_integer()
  def count(run_id) when is_binary(run_id) do
    pattern = [{{{run_id, :"$1"}, :_}, [], [true]}]
    :ets.select_count(@table, pattern)
  rescue
    ArgumentError -> 0
  end

  @doc """
  Persists buffered breadcrumbs for `run_id` to the database, then drops the
  in-memory buffer. Returns `{count_persisted, nil}` on success or `:empty` if
  no buffer.

  Atomically removes the counter and the buffer rows. Concurrent `add` calls
  occurring during the flush window may have a few entries persisted in the
  next flush instead — acceptable, never dropped silently.
  """
  @spec flush_run(Ecto.UUID.t()) :: {non_neg_integer(), nil} | :empty
  def flush_run(run_id) when is_binary(run_id) do
    case list(run_id) do
      [] ->
        drop(run_id)
        :empty

      entries ->
        result = Analytics.record_breadcrumbs(entries)
        drop(run_id)
        result
    end
  end

  @doc "Drops the in-memory buffer for `run_id` without persisting."
  @spec drop(Ecto.UUID.t()) :: :ok
  def drop(run_id) when is_binary(run_id) do
    :ets.match_delete(@table, {{run_id, :_}, :_})
    :ets.delete(@counters, run_id)
    :ok
  rescue
    ArgumentError -> :ok
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@table, [
      :ordered_set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    :ets.new(@counters, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    {:ok, %{}}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Atomic increment via :ets.update_counter/4.
  # Returns {:ok, new_seq} or :not_initialized when ETS tables don't exist
  # (e.g., add/3 called before the GenServer started).
  defp next_sequence(run_id) do
    {:ok, :ets.update_counter(@counters, run_id, {2, 1}, {run_id, -1})}
  rescue
    ArgumentError -> :not_initialized
  end

  # Trim entries older than `current_seq - max + 1` for this run.
  # Because sequences are monotonic per run, we can compute the cutoff
  # exactly without rescanning.
  defp trim(run_id, current_seq, max) do
    cutoff = current_seq - max

    if cutoff >= 0 do
      pattern = [
        {{{run_id, :"$1"}, :_}, [{:"=<", :"$1", cutoff}], [true]}
      ]

      :ets.select_delete(@table, pattern)
    end

    :ok
  end

  defp clamp(n, lo, hi) when is_integer(n), do: n |> max(lo) |> min(hi)
  defp clamp(_, _, hi), do: hi
end
