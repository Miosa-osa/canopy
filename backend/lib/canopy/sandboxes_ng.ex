defmodule Canopy.SandboxesNg do
  @moduledoc """
  Public API for the Sandboxes super-module.

  This is the operational data layer for the **Sandbox Operator** agent —
  the runtime persona that provisions, monitors, and reaps MIOSA-backed
  sandboxes on behalf of other agents and humans.

  ## Architecture

  ```
  Sandbox Operator agent ─tools─▶ Canopy.Tools.Sandboxes
                                       │
                                       ▼
                          Canopy.SandboxesNg ──▶ Canopy.Miosa.Client (HTTP)
                                       │
                                       ▼
                              Postgres tables:
                                sandbox_lifecycle_events
                                sandbox_snapshots
                                sandbox_port_forwards
                                sandbox_alerts
  ```

  Tools call this module exclusively — no direct Repo access from tools.
  This module is the only writer to the four `sandbox_*` tables.

  Note: the existing `CanopyWeb.SandboxesController` reads sandbox data
  off the `sessions` table (legacy session-attached model). This module
  is the new operator surface that treats sandboxes as first-class
  entities with their own lifecycle, snapshots, ports, and alerts.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Repo
  alias Canopy.SandboxesNg.Alert
  alias Canopy.SandboxesNg.LifecycleEvent
  alias Canopy.SandboxesNg.PortForward
  alias Canopy.SandboxesNg.Snapshot

  require Logger

  @default_event_limit 200
  @default_snapshot_limit 100
  @default_port_limit 100

  # Default retention windows by snapshot kind (seconds).
  @retention_filesystem_seconds nil
  @retention_directory_seconds 30 * 24 * 60 * 60
  @retention_memory_seconds 7 * 24 * 60 * 60

  # ---------------------------------------------------------------------------
  # Lifecycle events
  # ---------------------------------------------------------------------------

  @doc """
  Records a single lifecycle event. Non-blocking on caller's perspective —
  errors are logged and swallowed so MIOSA hot-paths are never impacted.

  ## Examples

      iex> Canopy.SandboxesNg.record_event(%{
      ...>   sandbox_id: "sbx_abc",
      ...>   state: "running",
      ...>   prior_state: "provisioning"
      ...> })
      :ok
  """
  @spec record_event(map()) :: :ok
  def record_event(attrs) do
    attrs = Map.put_new_lazy(attrs, :ts, fn -> DateTime.utc_now() end)

    case %LifecycleEvent{} |> LifecycleEvent.changeset(attrs) |> Repo.insert() do
      {:ok, _} ->
        :ok

      {:error, changeset} ->
        Logger.warning("[SandboxesNg] lifecycle insert failed: #{inspect(changeset.errors)}")

        :ok
    end
  end

  @doc """
  Lists lifecycle events for one sandbox or a filter set.

  Options:
  - `:sandbox_id` — exact sandbox match
  - `:state` — filter by state
  - `:owner_agent_id` — filter by owning agent
  - `:workspace_slug` — workspace scope
  - `:from` / `:to` — DateTime window
  - `:limit` — default 200
  """
  @spec list_events(keyword()) :: [LifecycleEvent.t()]
  def list_events(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_event_limit)

    from(e in LifecycleEvent, order_by: [desc: e.ts], limit: ^limit)
    |> filter(:sandbox_id, opts[:sandbox_id])
    |> filter(:state, opts[:state])
    |> filter(:owner_agent_id, opts[:owner_agent_id])
    |> filter(:workspace_slug, opts[:workspace_slug])
    |> filter_window(opts[:from], opts[:to])
    |> Repo.all()
  end

  @doc """
  Returns the most-recent lifecycle event per sandbox — i.e., the current
  state of every sandbox the operator has ever touched. The result is the
  source of truth for the lifecycle status grid.
  """
  @spec list_current_states(keyword()) :: [LifecycleEvent.t()]
  def list_current_states(opts \\ []) do
    workspace = opts[:workspace_slug]

    base =
      from(e in LifecycleEvent,
        distinct: e.sandbox_id,
        order_by: [asc: e.sandbox_id, desc: e.ts]
      )

    base
    |> filter(:workspace_slug, workspace)
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # Snapshots
  # ---------------------------------------------------------------------------

  @doc """
  Creates a snapshot record. Called after the underlying MIOSA snapshot
  call returns successfully — this stores the metadata for retention
  policy and dependency tracking.
  """
  @spec create_snapshot(map()) :: {:ok, Snapshot.t()} | {:error, Ecto.Changeset.t()}
  def create_snapshot(attrs) do
    attrs = stringify_keys(attrs)
    kind = attrs["kind"]

    attrs =
      Map.put_new_lazy(attrs, "retention_until", fn -> default_retention_until(kind) end)

    %Snapshot{} |> Snapshot.changeset(attrs) |> Repo.insert()
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  @doc "Lists snapshots with optional filters."
  @spec list_snapshots(keyword()) :: [Snapshot.t()]
  def list_snapshots(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_snapshot_limit)

    from(s in Snapshot,
      order_by: [desc: s.inserted_at],
      limit: ^limit
    )
    |> filter(:sandbox_id, opts[:sandbox_id])
    |> filter(:kind, opts[:kind])
    |> filter(:workspace_slug, opts[:workspace_slug])
    |> filter(:created_by_agent_id, opts[:created_by_agent_id])
    |> maybe_active_only(opts[:active_only])
    |> Repo.all()
  end

  @doc "Fetches a snapshot by slug (raises if not found)."
  @spec get_snapshot!(String.t()) :: Snapshot.t()
  def get_snapshot!(slug), do: Repo.get_by!(Snapshot, slug: slug)

  @doc """
  Marks a snapshot as reaped (retention-expired or explicitly deleted).
  Soft-delete; row remains for audit but is filtered from `active_only`
  queries.
  """
  @spec reap_snapshot(Snapshot.t()) :: {:ok, Snapshot.t()} | {:error, Ecto.Changeset.t()}
  def reap_snapshot(%Snapshot{} = snap) do
    snap
    |> Snapshot.changeset(%{reaped_at: DateTime.utc_now()})
    |> Repo.update()
  end

  @doc """
  Returns snapshots whose retention has expired and have not yet been
  reaped. The Sandbox Operator heartbeat pulls this list and calls
  `reap_snapshot/1` on each (after deleting in MIOSA).
  """
  @spec list_expired_snapshots(keyword()) :: [Snapshot.t()]
  def list_expired_snapshots(opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now())

    from(s in Snapshot,
      where:
        not is_nil(s.retention_until) and
          s.retention_until <= ^now and
          is_nil(s.reaped_at),
      order_by: [asc: s.retention_until]
    )
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # Port forwards
  # ---------------------------------------------------------------------------

  @doc "Creates a port-forward record after MIOSA returns the public URL."
  @spec create_port_forward(map()) :: {:ok, PortForward.t()} | {:error, Ecto.Changeset.t()}
  def create_port_forward(attrs) do
    %PortForward{} |> PortForward.changeset(attrs) |> Repo.insert()
  end

  @doc "Lists port forwards with optional filters."
  @spec list_port_forwards(keyword()) :: [PortForward.t()]
  def list_port_forwards(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_port_limit)

    from(p in PortForward,
      order_by: [desc: p.inserted_at],
      limit: ^limit
    )
    |> filter(:sandbox_id, opts[:sandbox_id])
    |> filter(:visibility, opts[:visibility])
    |> filter(:workspace_slug, opts[:workspace_slug])
    |> filter(:opened_by_agent_id, opts[:opened_by_agent_id])
    |> maybe_open_only(opts[:open_only])
    |> Repo.all()
  end

  @doc """
  Returns the active forward for a sandbox+port pair, if any.
  """
  @spec get_active_forward(String.t(), pos_integer()) :: PortForward.t() | nil
  def get_active_forward(sandbox_id, port)
      when is_binary(sandbox_id) and is_integer(port) do
    Repo.one(
      from(p in PortForward,
        where:
          p.sandbox_id == ^sandbox_id and
            p.internal_port == ^port and
            is_nil(p.closed_at),
        limit: 1
      )
    )
  end

  @doc "Updates the visibility tier of an active forward."
  @spec update_visibility(PortForward.t(), String.t()) ::
          {:ok, PortForward.t()} | {:error, Ecto.Changeset.t()}
  def update_visibility(%PortForward{} = forward, visibility) do
    forward
    |> PortForward.changeset(%{visibility: visibility})
    |> Repo.update()
  end

  @doc "Closes a port forward (releases the sandbox+port pair)."
  @spec close_port_forward(PortForward.t()) ::
          {:ok, PortForward.t()} | {:error, Ecto.Changeset.t()}
  def close_port_forward(%PortForward{} = forward) do
    forward
    |> PortForward.changeset(%{closed_at: DateTime.utc_now()})
    |> Repo.update()
  end

  # ---------------------------------------------------------------------------
  # Alerts
  # ---------------------------------------------------------------------------

  @doc "Lists configured alerts."
  @spec list_alerts(keyword()) :: [Alert.t()]
  def list_alerts(opts \\ []) do
    from(a in Alert, order_by: [asc: a.name])
    |> filter(:enabled, opts[:enabled])
    |> filter(:metric, opts[:metric])
    |> filter(:workspace_slug, opts[:workspace_slug])
    |> Repo.all()
  end

  @doc "Creates an alert."
  @spec create_alert(map()) :: {:ok, Alert.t()} | {:error, Ecto.Changeset.t()}
  def create_alert(attrs) do
    %Alert{} |> Alert.changeset(attrs) |> Repo.insert()
  end

  @doc "Records that an alert fired (updates last_fired_at + fire_count)."
  @spec record_fire(Alert.t()) :: {:ok, Alert.t()} | {:error, Ecto.Changeset.t()}
  def record_fire(%Alert{} = alert) do
    alert
    |> Alert.changeset(%{
      last_fired_at: DateTime.utc_now(),
      last_evaluated_at: DateTime.utc_now(),
      fire_count: alert.fire_count + 1
    })
    |> Repo.update()
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp filter(query, _field, nil), do: query

  defp filter(query, field, value) do
    from(q in query, where: field(q, ^field) == ^value)
  end

  defp filter_window(query, nil, nil), do: query

  defp filter_window(query, from, nil) do
    from(q in query, where: q.ts >= ^from)
  end

  defp filter_window(query, nil, to) do
    from(q in query, where: q.ts <= ^to)
  end

  defp filter_window(query, from, to) do
    from(q in query, where: q.ts >= ^from and q.ts <= ^to)
  end

  defp maybe_active_only(query, true) do
    from(q in query, where: is_nil(q.reaped_at))
  end

  defp maybe_active_only(query, _), do: query

  defp maybe_open_only(query, true) do
    from(q in query, where: is_nil(q.closed_at))
  end

  defp maybe_open_only(query, _), do: query

  defp default_retention_until("filesystem"), do: @retention_filesystem_seconds
  defp default_retention_until(:filesystem), do: @retention_filesystem_seconds

  defp default_retention_until(kind) when kind in ["directory", :directory] do
    DateTime.add(DateTime.utc_now(), @retention_directory_seconds, :second)
  end

  defp default_retention_until(kind) when kind in ["memory", :memory] do
    DateTime.add(DateTime.utc_now(), @retention_memory_seconds, :second)
  end

  defp default_retention_until(_), do: nil
end
