defmodule CanopyWeb.AnalyticsController do
  @moduledoc """
  HTTP API for the Analytics super-module.

  Routes:
    GET    /api/v1/analytics/telemetry              — query telemetry events
    GET    /api/v1/analytics/costs                  — aggregated cost buckets
    GET    /api/v1/analytics/breadcrumbs/:run_id    — breadcrumbs for a run
    GET    /api/v1/analytics/insights               — list insights
    POST   /api/v1/analytics/insights               — create insight
    POST   /api/v1/analytics/insights/:slug/ack     — acknowledge an insight
    GET    /api/v1/analytics/alerts                 — list alerts
    POST   /api/v1/analytics/alerts                 — create alert
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Analytics
  alias CanopyWeb.Schemas.AnalyticsSchema

  action_fallback CanopyWeb.FallbackController

  tags ["analytics"]

  @max_limit 1000
  @default_limit 100
  @slug_regex ~r/\A[a-z0-9][a-z0-9_-]{0,127}\z/
  @uuid_regex ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  # ---------------------------------------------------------------------------
  # Telemetry
  # ---------------------------------------------------------------------------

  operation :telemetry,
    summary: "Query telemetry events",
    description: "Returns telemetry events with optional filters, sorted by timestamp descending.",
    parameters: [
      event: [in: :query, type: :string, required: false],
      agent_id: [in: :query, type: :string, required: false],
      session_id: [in: :query, type: :string, required: false],
      run_id: [in: :query, type: :string, required: false],
      workspace_slug: [in: :query, type: :string, required: false],
      runtime: [in: :query, type: :string, required: false],
      from: [in: :query, type: :string, required: false],
      to: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Telemetry list", "application/json", AnalyticsSchema.TelemetryList}]

  @spec telemetry(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def telemetry(conn, params) do
    with {:ok, from} <- parse_dt_opt(params["from"]),
         {:ok, to} <- parse_dt_opt(params["to"]),
         :ok <- validate_window(from, to),
         {:ok, agent_id} <- validate_uuid_opt(params["agent_id"]),
         {:ok, session_id} <- validate_uuid_opt(params["session_id"]),
         {:ok, run_id} <- validate_uuid_opt(params["run_id"]) do
      opts =
        []
        |> maybe_put(:event, params["event"])
        |> maybe_put(:agent_id, agent_id)
        |> maybe_put(:session_id, session_id)
        |> maybe_put(:run_id, run_id)
        |> maybe_put(:workspace_slug, params["workspace_slug"])
        |> maybe_put(:runtime, params["runtime"])
        |> maybe_put(:from, from)
        |> maybe_put(:to, to)
        |> maybe_put(:limit, parse_limit(params["limit"]))

      json(conn, %{data: Analytics.query_telemetry(opts)})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Costs
  # ---------------------------------------------------------------------------

  operation :costs,
    summary: "Aggregate cost telemetry into time buckets",
    parameters: [
      granularity: [in: :query, type: :string, required: false],
      from: [in: :query, type: :string, required: false],
      to: [in: :query, type: :string, required: false],
      agent_id: [in: :query, type: :string, required: false],
      workspace_slug: [in: :query, type: :string, required: false],
      runtime: [in: :query, type: :string, required: false]
    ],
    responses: [ok: {"Cost buckets", "application/json", AnalyticsSchema.CostBuckets}]

  @spec costs(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def costs(conn, params) do
    with {:ok, from} <- parse_dt_opt(params["from"]),
         {:ok, to} <- parse_dt_opt(params["to"]),
         :ok <- validate_window(from, to),
         {:ok, agent_id} <- validate_uuid_opt(params["agent_id"]) do
      granularity = parse_granularity(params["granularity"])

      opts =
        [granularity: granularity]
        |> maybe_put(:from, from)
        |> maybe_put(:to, to)
        |> maybe_put(:agent_id, agent_id)
        |> maybe_put(:workspace_slug, params["workspace_slug"])
        |> maybe_put(:runtime, params["runtime"])

      rows = Analytics.aggregate_costs(opts)
      json(conn, %{granularity: to_string(granularity), rows: rows})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Breadcrumbs
  # ---------------------------------------------------------------------------

  operation :breadcrumbs,
    summary: "List breadcrumbs for a run",
    parameters: [
      run_id: [in: :path, type: :string, required: true],
      level: [in: :query, type: :string, required: false],
      type: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Breadcrumb list", "application/json", AnalyticsSchema.BreadcrumbList}]

  @spec breadcrumbs(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def breadcrumbs(conn, %{"run_id" => run_id} = params) do
    with {:ok, run_id} <- validate_uuid(run_id, "run_id") do
      opts =
        []
        |> maybe_put(:level, params["level"])
        |> maybe_put(:type, params["type"])
        |> maybe_put(:limit, parse_limit(params["limit"]))

      crumbs = Analytics.list_breadcrumbs(run_id, opts)
      json(conn, %{run_id: run_id, count: length(crumbs), data: crumbs})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Insights
  # ---------------------------------------------------------------------------

  operation :insights_index,
    summary: "List insights",
    parameters: [
      severity: [in: :query, type: :string, required: false],
      kind: [in: :query, type: :string, required: false],
      workspace_slug: [in: :query, type: :string, required: false],
      since: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Insight list", "application/json", AnalyticsSchema.InsightList}]

  @spec insights_index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def insights_index(conn, params) do
    with {:ok, since} <- parse_dt_opt(params["since"]) do
      opts =
        []
        |> maybe_put(:severity, params["severity"])
        |> maybe_put(:kind, params["kind"])
        |> maybe_put(:workspace_slug, params["workspace_slug"])
        |> maybe_put(:since, since)
        |> maybe_put(:limit, parse_limit(params["limit"]))

      json(conn, %{data: Analytics.list_insights(opts)})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :insights_create,
    summary: "Create an insight",
    request_body: {"Insight create", "application/json", AnalyticsSchema.InsightCreate},
    responses: [
      created: {"Insight", "application/json", AnalyticsSchema.Insight}
    ]

  @spec insights_create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def insights_create(conn, params) do
    with :ok <- validate_slug_opt(params["slug"]) do
      case Analytics.create_insight(params) do
        {:ok, insight} ->
          conn |> put_status(:created) |> json(insight)

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :insights_acknowledge,
    summary: "Acknowledge an insight",
    parameters: [
      slug: [in: :path, type: :string, required: true]
    ],
    request_body:
      {"Acknowledge", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           by: %OpenApiSpex.Schema{type: :string},
           feedback: %OpenApiSpex.Schema{type: :string, nullable: true}
         },
         required: [:by]
       }},
    responses: [ok: {"Insight", "application/json", AnalyticsSchema.Insight}]

  @spec insights_acknowledge(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def insights_acknowledge(conn, %{"slug" => slug} = params) do
    with :ok <- validate_slug(slug),
         {:ok, feedback} <- validate_feedback(params["feedback"]) do
      try do
        insight = Analytics.get_insight!(slug)
        by = Map.get(params, "by", "user")

        case Analytics.acknowledge_insight(insight, by, feedback) do
          {:ok, updated} -> json(conn, updated)
          {:error, changeset} -> {:error, changeset}
        end
      rescue
        Ecto.NoResultsError ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "insight_not_found", slug: slug})
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Alerts
  # ---------------------------------------------------------------------------

  operation :alerts_index,
    summary: "List alerts",
    parameters: [
      enabled: [in: :query, type: :string, required: false],
      metric: [in: :query, type: :string, required: false],
      workspace_slug: [in: :query, type: :string, required: false]
    ],
    responses: [ok: {"Alert list", "application/json", AnalyticsSchema.AlertList}]

  @spec alerts_index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def alerts_index(conn, params) do
    opts =
      []
      |> maybe_put(:enabled, parse_bool(params["enabled"]))
      |> maybe_put(:metric, params["metric"])
      |> maybe_put(:workspace_slug, params["workspace_slug"])

    json(conn, %{data: Analytics.list_alerts(opts)})
  end

  operation :alerts_create,
    summary: "Create an alert",
    request_body: {"Alert create", "application/json", AnalyticsSchema.AlertCreate},
    responses: [
      created: {"Alert", "application/json", AnalyticsSchema.Alert}
    ]

  @spec alerts_create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def alerts_create(conn, params) do
    with :ok <- validate_slug_opt(params["slug"]) do
      case Analytics.create_alert(params) do
        {:ok, alert} -> conn |> put_status(:created) |> json(alert)
        {:error, changeset} -> {:error, changeset}
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, ""), do: opts
  defp maybe_put(opts, key, value), do: [{key, value} | opts]

  # ── Optional ISO-8601 timestamp parsing ────────────────────────────────────

  defp parse_dt_opt(nil), do: {:ok, nil}
  defp parse_dt_opt(""), do: {:ok, nil}

  defp parse_dt_opt(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> {:ok, dt}
      _ -> {:error, "invalid timestamp: #{str}"}
    end
  end

  defp parse_dt_opt(_), do: {:error, "invalid timestamp"}

  # ── Window validation ──────────────────────────────────────────────────────

  defp validate_window(nil, _), do: :ok
  defp validate_window(_, nil), do: :ok

  defp validate_window(from, to) do
    if DateTime.compare(from, to) in [:lt, :eq] do
      :ok
    else
      {:error, "from must be ≤ to"}
    end
  end

  # ── UUID validation ────────────────────────────────────────────────────────

  defp validate_uuid_opt(nil), do: {:ok, nil}
  defp validate_uuid_opt(""), do: {:ok, nil}
  defp validate_uuid_opt(str) when is_binary(str), do: validate_uuid(str, "uuid")
  defp validate_uuid_opt(_), do: {:error, "invalid uuid"}

  defp validate_uuid(str, field_name) when is_binary(str) do
    if Regex.match?(@uuid_regex, str) do
      {:ok, str}
    else
      {:error, "invalid #{field_name}: must be a UUID"}
    end
  end

  defp validate_uuid(_, field_name), do: {:error, "invalid #{field_name}"}

  # ── Slug validation ────────────────────────────────────────────────────────

  defp validate_slug_opt(nil), do: :ok
  defp validate_slug_opt(""), do: {:error, "slug cannot be empty"}
  defp validate_slug_opt(str) when is_binary(str), do: validate_slug(str)
  defp validate_slug_opt(_), do: {:error, "slug must be a string"}

  defp validate_slug(str) when is_binary(str) do
    if Regex.match?(@slug_regex, str) do
      :ok
    else
      {:error,
       "invalid slug: must be lowercase alphanumeric, dashes, underscores; max 128 chars; must start with letter or digit"}
    end
  end

  defp validate_slug(_), do: {:error, "slug must be a string"}

  # ── Feedback validation ────────────────────────────────────────────────────

  defp validate_feedback(nil), do: {:ok, nil}
  defp validate_feedback(""), do: {:ok, nil}
  defp validate_feedback("true_positive"), do: {:ok, "true_positive"}
  defp validate_feedback("false_positive"), do: {:ok, "false_positive"}
  defp validate_feedback("unverified"), do: {:ok, "unverified"}
  defp validate_feedback(_), do: {:error, "invalid feedback value"}

  # ── Bounded limit ──────────────────────────────────────────────────────────

  defp parse_limit(nil), do: @default_limit
  defp parse_limit(""), do: @default_limit
  defp parse_limit(n) when is_integer(n) and n > 0, do: min(n, @max_limit)

  defp parse_limit(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, ""} when n > 0 -> min(n, @max_limit)
      _ -> @default_limit
    end
  end

  defp parse_limit(_), do: @default_limit

  # ── Granularity ────────────────────────────────────────────────────────────

  defp parse_granularity(nil), do: :day
  defp parse_granularity("hour"), do: :hour
  defp parse_granularity("day"), do: :day
  defp parse_granularity("week"), do: :week
  defp parse_granularity("month"), do: :month
  defp parse_granularity(_), do: :day

  defp parse_bool(nil), do: nil
  defp parse_bool("true"), do: true
  defp parse_bool("false"), do: false
  defp parse_bool(_), do: nil

  # ── Error response ─────────────────────────────────────────────────────────

  defp bad_request(conn, reason) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: to_string(reason)})
  end
end
