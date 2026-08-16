defmodule Canopy.Analytics do
  @moduledoc """
  Public API for the Analytics super-module.

  This is the operational data layer for **Iris**, Canopy's Analytics agent.
  Exposes telemetry ingestion, breadcrumb capture, insight persistence, and
  alert configuration.

  ## Architecture

  ```
  Adapters / Heartbeats / Governance ─emit─▶ Telemetry events
  Per-run trail (ETS ring buffer) ─flush─▶ Breadcrumbs
  Iris (Analytics agent) ─writes─▶ Insights
  Iris / User ─configures─▶ Alerts
  Frontend /analytics ─reads─▶ all of the above
  ```

  Iris's tool surface (`analytics.*`) calls this module exclusively — no
  direct Repo access from tools.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Analytics.Alert
  alias Canopy.Analytics.Breadcrumb
  alias Canopy.Analytics.Insight
  alias Canopy.Analytics.Telemetry, as: Event
  alias Canopy.Repo

  require Logger

  @default_telemetry_limit 500
  @default_breadcrumb_limit 200
  @default_insight_limit 50

  # ---------------------------------------------------------------------------
  # Telemetry ingestion
  # ---------------------------------------------------------------------------

  @doc """
  Records a single telemetry event. Non-blocking on caller's perspective —
  errors are logged and swallowed so adapter execution is never impacted.

  ## Examples

      iex> Canopy.Analytics.record(%{event: "agent.run.started", agent_id: id, ts: DateTime.utc_now()})
      :ok
  """
  @spec record(map()) :: :ok
  def record(attrs) do
    attrs =
      attrs
      |> Map.put_new_lazy(:ts, fn -> DateTime.utc_now() end)
      |> coerce_atoms_to_strings()

    case %Event{} |> Event.changeset(attrs) |> Repo.insert() do
      {:ok, _} ->
        :ok

      {:error, changeset} ->
        Logger.warning("[Analytics] telemetry insert failed: #{inspect(changeset.errors)}")
        :ok
    end
  end

  @doc """
  Queries telemetry events matching the given filters.

  Options:
  - `:event` — exact event name match
  - `:run_id` / `:session_id` / `:agent_id` — UUID scope
  - `:workspace_slug` — workspace scope
  - `:runtime` — runtime type filter
  - `:from` / `:to` — DateTime window
  - `:limit` — default 500
  """
  @spec query_telemetry(keyword()) :: [Event.t()]
  def query_telemetry(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_telemetry_limit)

    from(e in Event, order_by: [desc: e.ts], limit: ^limit)
    |> filter(:event, opts[:event])
    |> filter(:run_id, opts[:run_id])
    |> filter(:session_id, opts[:session_id])
    |> filter(:agent_id, opts[:agent_id])
    |> filter(:workspace_slug, opts[:workspace_slug])
    |> filter(:runtime, opts[:runtime])
    |> filter_window(opts[:from], opts[:to])
    |> Repo.all()
  end

  @doc """
  Aggregates cost telemetry into period buckets.

  Returns `[%{bucket: DateTime, cost_cents: integer, count: integer}, ...]`
  for the given window grouped by `:hour`, `:day`, `:week`, or `:month`.

  ## Why hand-built SQL fragments per granularity

  Postgres requires GROUP BY / ORDER BY expressions to literally match the
  SELECT expression. When `date_trunc` is parameterised via `^var`, the
  driver binds it as separate `$N` parameters in each position — so the
  planner sees three distinct expressions and refuses (`column must appear
  in GROUP BY`). Inlining the granularity as a literal string in the
  fragment avoids this. Granularity is a controlled set, so no injection
  risk.
  """
  @spec aggregate_costs(keyword()) :: [map()]
  def aggregate_costs(opts \\ []) do
    granularity = Keyword.get(opts, :granularity, :day)
    from = Keyword.get(opts, :from, DateTime.add(DateTime.utc_now(), -30, :day))
    to = Keyword.get(opts, :to, DateTime.utc_now())

    base =
      from(e in Event,
        where: not is_nil(e.cost_cents) and e.ts >= ^from and e.ts <= ^to
      )
      |> filter(:agent_id, opts[:agent_id])
      |> filter(:workspace_slug, opts[:workspace_slug])
      |> filter(:runtime, opts[:runtime])

    aggregate_query =
      case granularity do
        :hour ->
          from e in base,
            group_by: fragment("date_trunc('hour', ?)", e.ts),
            order_by: fragment("date_trunc('hour', ?)", e.ts),
            select: %{
              bucket: fragment("date_trunc('hour', ?)", e.ts),
              cost_cents: sum(e.cost_cents),
              count: count(e.id)
            }

        :day ->
          from e in base,
            group_by: fragment("date_trunc('day', ?)", e.ts),
            order_by: fragment("date_trunc('day', ?)", e.ts),
            select: %{
              bucket: fragment("date_trunc('day', ?)", e.ts),
              cost_cents: sum(e.cost_cents),
              count: count(e.id)
            }

        :week ->
          from e in base,
            group_by: fragment("date_trunc('week', ?)", e.ts),
            order_by: fragment("date_trunc('week', ?)", e.ts),
            select: %{
              bucket: fragment("date_trunc('week', ?)", e.ts),
              cost_cents: sum(e.cost_cents),
              count: count(e.id)
            }

        :month ->
          from e in base,
            group_by: fragment("date_trunc('month', ?)", e.ts),
            order_by: fragment("date_trunc('month', ?)", e.ts),
            select: %{
              bucket: fragment("date_trunc('month', ?)", e.ts),
              cost_cents: sum(e.cost_cents),
              count: count(e.id)
            }

        _ ->
          from e in base,
            group_by: fragment("date_trunc('day', ?)", e.ts),
            order_by: fragment("date_trunc('day', ?)", e.ts),
            select: %{
              bucket: fragment("date_trunc('day', ?)", e.ts),
              cost_cents: sum(e.cost_cents),
              count: count(e.id)
            }
      end

    Repo.all(aggregate_query)
  end

  # ---------------------------------------------------------------------------
  # Breadcrumbs (persistent)
  # ---------------------------------------------------------------------------

  @doc """
  Persists a single breadcrumb. Normally called by `Breadcrumbs.flush_run/1`
  after the in-memory ring buffer fills or the run completes.
  """
  @spec record_breadcrumb(map()) :: {:ok, Breadcrumb.t()} | {:error, Ecto.Changeset.t()}
  def record_breadcrumb(attrs) do
    attrs = Map.put_new_lazy(attrs, :ts, fn -> DateTime.utc_now() end)

    %Breadcrumb{} |> Breadcrumb.changeset(attrs) |> Repo.insert()
  end

  @doc "Persists many breadcrumbs in one insert_all call."
  @spec record_breadcrumbs([map()]) :: {non_neg_integer(), nil}
  def record_breadcrumbs(entries) when is_list(entries) do
    now = DateTime.utc_now()

    rows =
      Enum.map(entries, fn attrs ->
        attrs
        |> Map.put_new(:id, Ecto.UUID.generate())
        |> Map.put_new(:ts, now)
        |> Map.put_new(:level, "info")
        |> Map.put_new(:data, %{})
        |> Map.put_new(:inserted_at, now)
      end)

    Repo.insert_all(Breadcrumb, rows)
  end

  @doc """
  Lists breadcrumbs for a single run, ordered by sequence.
  """
  @spec list_breadcrumbs(Ecto.UUID.t(), keyword()) :: [Breadcrumb.t()]
  def list_breadcrumbs(run_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_breadcrumb_limit)

    from(b in Breadcrumb,
      where: b.run_id == ^run_id,
      order_by: [asc: b.sequence],
      limit: ^limit
    )
    |> filter(:level, opts[:level])
    |> filter(:type, opts[:type])
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # Insights
  # ---------------------------------------------------------------------------

  @doc "Lists insights with optional filters (severity, kind, workspace, since)."
  @spec list_insights(keyword()) :: [Insight.t()]
  def list_insights(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_insight_limit)
    since = Keyword.get(opts, :since)

    query =
      from(i in Insight,
        order_by: [desc: i.detected_at],
        limit: ^limit
      )

    query
    |> filter(:severity, opts[:severity])
    |> filter(:kind, opts[:kind])
    |> filter(:workspace_slug, opts[:workspace_slug])
    |> filter(:created_by_agent_id, opts[:created_by_agent_id])
    |> maybe_since(since)
    |> Repo.all()
  end

  @doc "Fetches a single insight by slug."
  @spec get_insight!(String.t()) :: Insight.t()
  def get_insight!(slug), do: Repo.get_by!(Insight, slug: slug)

  @doc "Creates an insight."
  @spec create_insight(map()) :: {:ok, Insight.t()} | {:error, Ecto.Changeset.t()}
  def create_insight(attrs) do
    %Insight{} |> Insight.changeset(attrs) |> Repo.insert()
  end

  @doc "Acknowledges an insight (sets acknowledged_at + by + feedback)."
  @spec acknowledge_insight(Insight.t(), String.t(), String.t() | nil) ::
          {:ok, Insight.t()} | {:error, Ecto.Changeset.t()}
  def acknowledge_insight(%Insight{} = insight, by, feedback \\ nil) do
    insight
    |> Insight.changeset(%{
      acknowledged_at: DateTime.utc_now(),
      acknowledged_by: by,
      feedback: feedback
    })
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

  defp maybe_since(query, nil), do: query

  defp maybe_since(query, since) do
    from(q in query, where: q.detected_at >= ^since)
  end

  defp coerce_atoms_to_strings(%{event: e} = attrs) when is_atom(e) do
    %{attrs | event: Atom.to_string(e)}
  end

  defp coerce_atoms_to_strings(attrs), do: attrs
end
