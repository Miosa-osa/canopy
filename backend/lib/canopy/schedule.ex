defmodule Canopy.Schedule do
  @moduledoc """
  Public API for the Schedule super-module.

  This is the operational data layer for the **Scheduling Agent**, Canopy's
  runtime owner of the temporal layer. The agent's persona file IS the
  module's configuration; this context module is the storage + query API.

  ## Architecture

  ```
  persona.md heartbeat: spec ─compile─▶ Canopy.Schedule.Spec rows
  Canopy.Heartbeat.Worker (Oban) ─emit─▶ Canopy.Schedule.Run rows
  Schedule.Dispatcher tick ─detect─▶ overlaps, miss, late, circuit-breaker
  Failed runs ─cluster─▶ Canopy.Schedule.Alert (incidents)
  Frontend /schedule ─reads─▶ all of the above
  ```

  The agent's tool surface (`schedule.*`, `heartbeat.*`, `incident.*`) calls
  this module exclusively — no direct Repo access from tools.

  ## Wraps existing primitives, does not replace

  Cron evaluation defers to `Canopy.Heartbeat.Registrar` (Oban-backed).
  Routine enable/disable defers to `Canopy.Routines.Routine` rows. This
  module adds the visualization + run history + overlap-policy + incident
  layer on top.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Repo
  alias Canopy.Schedule.Alert
  alias Canopy.Schedule.Run
  alias Canopy.Schedule.Spec

  require Logger

  @default_run_limit 200
  @default_alert_limit 100
  @default_spec_limit 200

  # ---------------------------------------------------------------------------
  # Specs (CRUD)
  # ---------------------------------------------------------------------------

  @doc "Lists schedule specs with optional filters."
  @spec list_specs(keyword()) :: [Spec.t()]
  def list_specs(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_spec_limit)

    from(s in Spec, order_by: [asc: s.name], limit: ^limit)
    |> filter(:status, opts[:status])
    |> filter(:agent_slug, opts[:agent_slug])
    |> filter(:workspace_slug, opts[:workspace_slug])
    |> filter(:concurrency_key, opts[:concurrency_key])
    |> Repo.all()
  end

  @doc "Fetches a single spec by slug."
  @spec get_spec_by_slug!(String.t()) :: Spec.t()
  def get_spec_by_slug!(slug), do: Repo.get_by!(Spec, slug: slug)

  @doc "Fetches a single spec by id."
  @spec get_spec(Ecto.UUID.t()) :: Spec.t() | nil
  def get_spec(id), do: Repo.get(Spec, id)

  @doc "Creates a spec."
  @spec create_spec(map()) :: {:ok, Spec.t()} | {:error, Ecto.Changeset.t()}
  def create_spec(attrs) do
    %Spec{} |> Spec.changeset(attrs) |> Repo.insert()
  end

  @doc "Updates a spec with the given patch map."
  @spec update_spec(Spec.t(), map()) :: {:ok, Spec.t()} | {:error, Ecto.Changeset.t()}
  def update_spec(%Spec{} = spec, attrs) do
    spec |> Spec.changeset(attrs) |> Repo.update()
  end

  @doc "Pauses a spec. Sets status, paused_at, and paused_reason."
  @spec pause_spec(Spec.t(), String.t() | nil) ::
          {:ok, Spec.t()} | {:error, Ecto.Changeset.t()}
  def pause_spec(%Spec{} = spec, reason \\ nil) do
    update_spec(spec, %{
      status: "paused",
      paused_at: DateTime.utc_now(),
      paused_reason: reason
    })
  end

  @doc "Unpauses a spec, returning it to active."
  @spec unpause_spec(Spec.t()) :: {:ok, Spec.t()} | {:error, Ecto.Changeset.t()}
  def unpause_spec(%Spec{} = spec) do
    update_spec(spec, %{
      status: "active",
      paused_at: nil,
      paused_reason: nil,
      consecutive_failures: 0
    })
  end

  @doc "Soft-deletes a spec by archiving it. Past runs retained."
  @spec archive_spec(Spec.t()) :: {:ok, Spec.t()} | {:error, Ecto.Changeset.t()}
  def archive_spec(%Spec{} = spec), do: update_spec(spec, %{status: "archived"})

  # ---------------------------------------------------------------------------
  # Runs (history + status updates)
  # ---------------------------------------------------------------------------

  @doc """
  Records a fire (or fire attempt) for a spec.

  Called by the dispatcher when a tick is enqueued. Status starts as
  `"enqueued"` and is transitioned via `update_run_status/3` as the
  underlying job runs.
  """
  @spec record_run(map()) :: {:ok, Run.t()} | {:error, Ecto.Changeset.t()}
  def record_run(attrs) do
    %Run{} |> Run.changeset(attrs) |> Repo.insert()
  end

  @doc "Records many runs in one insert. Used by batch dispatch ticks."
  @spec record_runs([map()]) :: {non_neg_integer(), nil}
  def record_runs(entries) when is_list(entries) do
    now = DateTime.utc_now()

    rows =
      Enum.map(entries, fn attrs ->
        attrs
        |> Map.put_new(:id, Ecto.UUID.generate())
        |> Map.put_new(:status, "enqueued")
        |> Map.put_new(:attempt, 1)
        |> Map.put_new(:payload, %{})
        |> Map.put_new(:inserted_at, now)
      end)

    Repo.insert_all(Run, rows)
  end

  @doc "Lists runs for a spec, ordered by scheduled_at descending."
  @spec list_runs(keyword()) :: [Run.t()]
  def list_runs(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_run_limit)

    from(r in Run, order_by: [desc: r.scheduled_at], limit: ^limit)
    |> filter(:spec_id, opts[:spec_id])
    |> filter(:spec_slug, opts[:spec_slug])
    |> filter(:status, opts[:status])
    |> filter(:agent_slug, opts[:agent_slug])
    |> filter(:workspace_slug, opts[:workspace_slug])
    |> filter_run_window(opts[:since], opts[:until])
    |> Repo.all()
  end

  @doc "Fetches a run by id."
  @spec get_run(Ecto.UUID.t()) :: Run.t() | nil
  def get_run(id), do: Repo.get(Run, id)

  @doc "Updates a run with the given patch map."
  @spec update_run(Run.t(), map()) :: {:ok, Run.t()} | {:error, Ecto.Changeset.t()}
  def update_run(%Run{} = run, attrs) do
    run |> Run.changeset(attrs) |> Repo.update()
  end

  @doc """
  Aggregates run telemetry into time buckets — same shape as
  `Canopy.Analytics.aggregate_costs/1`. Used by the timeline UI.

  Granularity: `:hour | :day | :week | :month`.
  """
  @spec aggregate_runs(keyword()) :: [map()]
  def aggregate_runs(opts \\ []) do
    granularity = Keyword.get(opts, :granularity, :day)
    from_at = Keyword.get(opts, :from, DateTime.add(DateTime.utc_now(), -7, :day))
    to_at = Keyword.get(opts, :to, DateTime.utc_now())

    base =
      from(r in Run,
        where: r.scheduled_at >= ^from_at and r.scheduled_at <= ^to_at
      )
      |> filter(:spec_id, opts[:spec_id])
      |> filter(:spec_slug, opts[:spec_slug])
      |> filter(:agent_slug, opts[:agent_slug])
      |> filter(:workspace_slug, opts[:workspace_slug])

    aggregate_query =
      case granularity do
        :hour ->
          from r in base,
            group_by: fragment("date_trunc('hour', ?)", r.scheduled_at),
            order_by: fragment("date_trunc('hour', ?)", r.scheduled_at),
            select: %{
              bucket: fragment("date_trunc('hour', ?)", r.scheduled_at),
              total: count(r.id),
              succeeded: fragment("count(*) filter (where ? = 'completed')", r.status),
              failed: fragment("count(*) filter (where ? = 'failed')", r.status),
              missed: fragment("count(*) filter (where ? = 'missed')", r.status),
              late: fragment("count(*) filter (where ? = 'late')", r.status)
            }

        :day ->
          from r in base,
            group_by: fragment("date_trunc('day', ?)", r.scheduled_at),
            order_by: fragment("date_trunc('day', ?)", r.scheduled_at),
            select: %{
              bucket: fragment("date_trunc('day', ?)", r.scheduled_at),
              total: count(r.id),
              succeeded: fragment("count(*) filter (where ? = 'completed')", r.status),
              failed: fragment("count(*) filter (where ? = 'failed')", r.status),
              missed: fragment("count(*) filter (where ? = 'missed')", r.status),
              late: fragment("count(*) filter (where ? = 'late')", r.status)
            }

        :week ->
          from r in base,
            group_by: fragment("date_trunc('week', ?)", r.scheduled_at),
            order_by: fragment("date_trunc('week', ?)", r.scheduled_at),
            select: %{
              bucket: fragment("date_trunc('week', ?)", r.scheduled_at),
              total: count(r.id),
              succeeded: fragment("count(*) filter (where ? = 'completed')", r.status),
              failed: fragment("count(*) filter (where ? = 'failed')", r.status),
              missed: fragment("count(*) filter (where ? = 'missed')", r.status),
              late: fragment("count(*) filter (where ? = 'late')", r.status)
            }

        :month ->
          from r in base,
            group_by: fragment("date_trunc('month', ?)", r.scheduled_at),
            order_by: fragment("date_trunc('month', ?)", r.scheduled_at),
            select: %{
              bucket: fragment("date_trunc('month', ?)", r.scheduled_at),
              total: count(r.id),
              succeeded: fragment("count(*) filter (where ? = 'completed')", r.status),
              failed: fragment("count(*) filter (where ? = 'failed')", r.status),
              missed: fragment("count(*) filter (where ? = 'missed')", r.status),
              late: fragment("count(*) filter (where ? = 'late')", r.status)
            }

        _ ->
          from r in base,
            group_by: fragment("date_trunc('day', ?)", r.scheduled_at),
            order_by: fragment("date_trunc('day', ?)", r.scheduled_at),
            select: %{
              bucket: fragment("date_trunc('day', ?)", r.scheduled_at),
              total: count(r.id),
              succeeded: fragment("count(*) filter (where ? = 'completed')", r.status),
              failed: fragment("count(*) filter (where ? = 'failed')", r.status),
              missed: fragment("count(*) filter (where ? = 'missed')", r.status),
              late: fragment("count(*) filter (where ? = 'late')", r.status)
            }
      end

    Repo.all(aggregate_query)
  end

  # ---------------------------------------------------------------------------
  # Overlap detection
  # ---------------------------------------------------------------------------

  @doc """
  Finds runs whose `scheduled_at` overlap (within `tolerance_seconds`) for the
  same spec — i.e. two ticks landing in the same window. The dispatcher uses
  this to pick the right overlap policy. The frontend uses it to render
  collision indicators on the timeline.
  """
  @spec detect_overlaps(keyword()) :: [map()]
  def detect_overlaps(opts \\ []) do
    tolerance = Keyword.get(opts, :tolerance_seconds, 60)
    since = Keyword.get(opts, :since, DateTime.add(DateTime.utc_now(), -7, :day))

    base =
      from(r in Run,
        where: r.scheduled_at >= ^since,
        order_by: [asc: r.spec_id, asc: r.scheduled_at]
      )
      |> filter(:spec_id, opts[:spec_id])

    rows = Repo.all(base)

    rows
    |> Enum.chunk_by(& &1.spec_id)
    |> Enum.flat_map(fn group -> find_overlapping_pairs(group, tolerance) end)
  end

  defp find_overlapping_pairs(rows, tolerance) do
    rows
    |> Enum.zip(Enum.drop(rows, 1))
    |> Enum.filter(fn {a, b} ->
      DateTime.diff(b.scheduled_at, a.scheduled_at, :second) <= tolerance and
        a.status in ["running", "enqueued"]
    end)
    |> Enum.map(fn {a, b} ->
      %{
        spec_id: a.spec_id,
        spec_slug: a.spec_slug,
        running_run_id: a.id,
        incoming_run_id: b.id,
        gap_seconds: DateTime.diff(b.scheduled_at, a.scheduled_at, :second),
        detected_at: DateTime.utc_now()
      }
    end)
  end

  # ---------------------------------------------------------------------------
  # Alerts (incidents)
  # ---------------------------------------------------------------------------

  @doc "Lists alerts/incidents."
  @spec list_alerts(keyword()) :: [Alert.t()]
  def list_alerts(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_alert_limit)

    from(a in Alert, order_by: [desc: a.last_seen_at], limit: ^limit)
    |> filter(:status, opts[:status])
    |> filter(:severity, opts[:severity])
    |> filter(:category, opts[:category])
    |> filter(:spec_id, opts[:spec_id])
    |> filter(:workspace_slug, opts[:workspace_slug])
    |> Repo.all()
  end

  @doc "Fetches an alert by slug."
  @spec get_alert_by_slug!(String.t()) :: Alert.t()
  def get_alert_by_slug!(slug), do: Repo.get_by!(Alert, slug: slug)

  @doc "Opens a new alert (incident)."
  @spec open_alert(map()) :: {:ok, Alert.t()} | {:error, Ecto.Changeset.t()}
  def open_alert(attrs) do
    now = DateTime.utc_now()

    # Normalize keys to strings so we don't mix atom + string keys when the
    # caller passes a string-keyed map (e.g. from a controller).
    attrs =
      attrs
      |> stringify_keys()
      |> Map.put_new("first_seen_at", now)
      |> Map.put_new("last_seen_at", now)
      |> Map.put_new("status", "open")

    %Alert{} |> Alert.changeset(attrs) |> Repo.insert()
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  @doc "Closes an alert with an optional resolution note."
  @spec close_alert(Alert.t(), String.t() | nil) ::
          {:ok, Alert.t()} | {:error, Ecto.Changeset.t()}
  def close_alert(%Alert{} = alert, resolution_note \\ nil) do
    alert
    |> Alert.changeset(%{
      status: "closed",
      closed_at: DateTime.utc_now(),
      resolution_note: resolution_note
    })
    |> Repo.update()
  end

  @doc "Acknowledges an alert (records who saw it but doesn't close it)."
  @spec acknowledge_alert(Alert.t(), String.t()) ::
          {:ok, Alert.t()} | {:error, Ecto.Changeset.t()}
  def acknowledge_alert(%Alert{} = alert, by) do
    alert
    |> Alert.changeset(%{
      status: "acknowledged",
      acknowledged_at: DateTime.utc_now(),
      acknowledged_by: by
    })
    |> Repo.update()
  end

  @doc """
  Increments an alert's failure_count, updates last_seen_at, and appends a
  related run id. Used when grouping failures into the same incident.
  """
  @spec record_alert_failure(Alert.t(), Ecto.UUID.t()) ::
          {:ok, Alert.t()} | {:error, Ecto.Changeset.t()}
  def record_alert_failure(%Alert{} = alert, run_id) do
    alert
    |> Alert.changeset(%{
      last_seen_at: DateTime.utc_now(),
      failure_count: alert.failure_count + 1,
      related_run_ids: Enum.uniq([run_id | alert.related_run_ids])
    })
    |> Repo.update()
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp filter(query, _field, nil), do: query
  defp filter(query, _field, ""), do: query

  defp filter(query, field, value) do
    from(q in query, where: field(q, ^field) == ^value)
  end

  defp filter_run_window(query, nil, nil), do: query

  defp filter_run_window(query, since, nil) do
    from(q in query, where: q.scheduled_at >= ^since)
  end

  defp filter_run_window(query, nil, until) do
    from(q in query, where: q.scheduled_at <= ^until)
  end

  defp filter_run_window(query, since, until) do
    from(q in query, where: q.scheduled_at >= ^since and q.scheduled_at <= ^until)
  end
end
