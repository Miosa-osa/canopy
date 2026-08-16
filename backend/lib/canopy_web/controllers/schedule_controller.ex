defmodule CanopyWeb.ScheduleController do
  @moduledoc """
  HTTP API for the Schedule super-module.

  Routes:
    GET    /api/v1/schedule/specs                — list specs
    POST   /api/v1/schedule/specs                — create spec
    GET    /api/v1/schedule/specs/:slug          — show spec
    PATCH  /api/v1/schedule/specs/:slug          — update spec
    POST   /api/v1/schedule/specs/:slug/pause    — pause spec
    POST   /api/v1/schedule/specs/:slug/unpause  — unpause spec
    DELETE /api/v1/schedule/specs/:slug          — archive spec
    GET    /api/v1/schedule/runs                 — list runs (timeline feed)
    GET    /api/v1/schedule/runs/aggregate       — bucketed run metrics
    GET    /api/v1/schedule/overlaps             — overlap detection rows
    GET    /api/v1/schedule/alerts               — list alerts (incidents)
    POST   /api/v1/schedule/alerts               — open an incident
    POST   /api/v1/schedule/alerts/:slug/close   — close an incident
    POST   /api/v1/schedule/alerts/:slug/ack     — acknowledge an incident
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Schedule
  alias CanopyWeb.Schemas.ScheduleSchema

  action_fallback CanopyWeb.FallbackController

  tags ["schedule"]

  @max_limit 1000
  @default_limit 100
  @slug_regex ~r/\A[a-z0-9][a-z0-9_-]{0,127}\z/
  @uuid_regex ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  # ---------------------------------------------------------------------------
  # Specs
  # ---------------------------------------------------------------------------

  operation :specs_index,
    summary: "List schedule specs",
    parameters: [
      status: [in: :query, type: :string, required: false],
      agent_slug: [in: :query, type: :string, required: false],
      workspace_slug: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Spec list", "application/json", ScheduleSchema.SpecList}]

  @spec specs_index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def specs_index(conn, params) do
    opts =
      []
      |> maybe_put(:status, params["status"])
      |> maybe_put(:agent_slug, params["agent_slug"])
      |> maybe_put(:workspace_slug, params["workspace_slug"])
      |> maybe_put(:limit, parse_limit(params["limit"]))

    json(conn, %{data: Schedule.list_specs(opts)})
  end

  operation :specs_create,
    summary: "Create a schedule spec",
    request_body: {"Spec create", "application/json", ScheduleSchema.SpecCreate},
    responses: [
      created: {"Spec", "application/json", ScheduleSchema.Spec}
    ]

  @spec specs_create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def specs_create(conn, params) do
    with :ok <- validate_slug_opt(params["slug"]) do
      case Schedule.create_spec(params) do
        {:ok, spec} ->
          conn |> put_status(:created) |> json(spec)

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :specs_show,
    summary: "Show a schedule spec",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [ok: {"Spec", "application/json", ScheduleSchema.Spec}]

  @spec specs_show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def specs_show(conn, %{"slug" => slug}) do
    with :ok <- validate_slug(slug) do
      try do
        json(conn, Schedule.get_spec_by_slug!(slug))
      rescue
        Ecto.NoResultsError ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "spec_not_found", slug: slug})
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :specs_update,
    summary: "Update a schedule spec",
    parameters: [slug: [in: :path, type: :string, required: true]],
    request_body: {"Spec update", "application/json", ScheduleSchema.SpecUpdate},
    responses: [ok: {"Spec", "application/json", ScheduleSchema.Spec}]

  @spec specs_update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def specs_update(conn, %{"slug" => slug} = params) do
    with :ok <- validate_slug(slug) do
      try do
        spec = Schedule.get_spec_by_slug!(slug)

        case Schedule.update_spec(spec, params) do
          {:ok, updated} -> json(conn, updated)
          {:error, changeset} -> {:error, changeset}
        end
      rescue
        Ecto.NoResultsError ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "spec_not_found", slug: slug})
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :specs_pause,
    summary: "Pause a spec",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [ok: {"Spec", "application/json", ScheduleSchema.Spec}]

  @spec specs_pause(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def specs_pause(conn, %{"slug" => slug} = params) do
    with :ok <- validate_slug(slug) do
      mutate_spec(conn, slug, fn spec ->
        Schedule.pause_spec(spec, params["reason"])
      end)
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :specs_unpause,
    summary: "Unpause a spec",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [ok: {"Spec", "application/json", ScheduleSchema.Spec}]

  @spec specs_unpause(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def specs_unpause(conn, %{"slug" => slug}) do
    with :ok <- validate_slug(slug) do
      mutate_spec(conn, slug, &Schedule.unpause_spec/1)
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :specs_archive,
    summary: "Archive (soft-delete) a spec",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [ok: {"Spec", "application/json", ScheduleSchema.Spec}]

  @spec specs_archive(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def specs_archive(conn, %{"slug" => slug}) do
    with :ok <- validate_slug(slug) do
      mutate_spec(conn, slug, &Schedule.archive_spec/1)
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Runs
  # ---------------------------------------------------------------------------

  operation :runs_index,
    summary: "List schedule runs (timeline feed)",
    parameters: [
      spec_slug: [in: :query, type: :string, required: false],
      spec_id: [in: :query, type: :string, required: false],
      status: [in: :query, type: :string, required: false],
      since: [in: :query, type: :string, required: false],
      until: [in: :query, type: :string, required: false],
      agent_slug: [in: :query, type: :string, required: false],
      workspace_slug: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Run list", "application/json", ScheduleSchema.RunList}]

  @spec runs_index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def runs_index(conn, params) do
    with {:ok, since} <- parse_dt_opt(params["since"]),
         {:ok, until} <- parse_dt_opt(params["until"]),
         :ok <- validate_window(since, until),
         {:ok, spec_id} <- validate_uuid_opt(params["spec_id"]) do
      opts =
        []
        |> maybe_put(:spec_slug, params["spec_slug"])
        |> maybe_put(:spec_id, spec_id)
        |> maybe_put(:status, params["status"])
        |> maybe_put(:since, since)
        |> maybe_put(:until, until)
        |> maybe_put(:agent_slug, params["agent_slug"])
        |> maybe_put(:workspace_slug, params["workspace_slug"])
        |> maybe_put(:limit, parse_limit(params["limit"]))

      json(conn, %{data: Schedule.list_runs(opts)})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :runs_aggregate,
    summary: "Aggregate runs into time buckets",
    parameters: [
      granularity: [in: :query, type: :string, required: false],
      from: [in: :query, type: :string, required: false],
      to: [in: :query, type: :string, required: false],
      spec_slug: [in: :query, type: :string, required: false],
      agent_slug: [in: :query, type: :string, required: false],
      workspace_slug: [in: :query, type: :string, required: false]
    ],
    responses: [ok: {"Run buckets", "application/json", ScheduleSchema.RunBuckets}]

  @spec runs_aggregate(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def runs_aggregate(conn, params) do
    with {:ok, from} <- parse_dt_opt(params["from"]),
         {:ok, to} <- parse_dt_opt(params["to"]),
         :ok <- validate_window(from, to) do
      granularity = parse_granularity(params["granularity"])

      opts =
        [granularity: granularity]
        |> maybe_put(:from, from)
        |> maybe_put(:to, to)
        |> maybe_put(:spec_slug, params["spec_slug"])
        |> maybe_put(:agent_slug, params["agent_slug"])
        |> maybe_put(:workspace_slug, params["workspace_slug"])

      rows = Schedule.aggregate_runs(opts)
      json(conn, %{granularity: to_string(granularity), rows: rows})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Overlaps
  # ---------------------------------------------------------------------------

  operation :overlaps_index,
    summary: "List overlap detections in a window",
    parameters: [
      since: [in: :query, type: :string, required: false],
      tolerance_seconds: [in: :query, type: :integer, required: false],
      spec_id: [in: :query, type: :string, required: false]
    ],
    responses: [
      ok: {"Overlap list", "application/json", ScheduleSchema.OverlapList}
    ]

  @spec overlaps_index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def overlaps_index(conn, params) do
    with {:ok, since} <- parse_dt_opt(params["since"]),
         {:ok, spec_id} <- validate_uuid_opt(params["spec_id"]) do
      opts =
        []
        |> maybe_put(:since, since)
        |> maybe_put(:spec_id, spec_id)
        |> maybe_put(:tolerance_seconds, parse_int(params["tolerance_seconds"]))

      json(conn, %{data: Schedule.detect_overlaps(opts)})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Alerts
  # ---------------------------------------------------------------------------

  operation :alerts_index,
    summary: "List schedule alerts (incidents)",
    parameters: [
      status: [in: :query, type: :string, required: false],
      severity: [in: :query, type: :string, required: false],
      category: [in: :query, type: :string, required: false],
      workspace_slug: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Alert list", "application/json", ScheduleSchema.AlertList}]

  @spec alerts_index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def alerts_index(conn, params) do
    opts =
      []
      |> maybe_put(:status, params["status"])
      |> maybe_put(:severity, params["severity"])
      |> maybe_put(:category, params["category"])
      |> maybe_put(:workspace_slug, params["workspace_slug"])
      |> maybe_put(:limit, parse_limit(params["limit"]))

    json(conn, %{data: Schedule.list_alerts(opts)})
  end

  operation :alerts_create,
    summary: "Open a schedule incident",
    request_body: {"Alert create", "application/json", ScheduleSchema.AlertCreate},
    responses: [
      created: {"Alert", "application/json", ScheduleSchema.Alert}
    ]

  @spec alerts_create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def alerts_create(conn, params) do
    with :ok <- validate_slug_opt(params["slug"]) do
      case Schedule.open_alert(params) do
        {:ok, alert} ->
          conn |> put_status(:created) |> json(alert)

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :alerts_close,
    summary: "Close an incident",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [ok: {"Alert", "application/json", ScheduleSchema.Alert}]

  @spec alerts_close(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def alerts_close(conn, %{"slug" => slug} = params) do
    with :ok <- validate_slug(slug) do
      mutate_alert(conn, slug, fn alert ->
        Schedule.close_alert(alert, params["resolution_note"])
      end)
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :alerts_acknowledge,
    summary: "Acknowledge an incident",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [ok: {"Alert", "application/json", ScheduleSchema.Alert}]

  @spec alerts_acknowledge(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def alerts_acknowledge(conn, %{"slug" => slug} = params) do
    with :ok <- validate_slug(slug) do
      by = Map.get(params, "by", "user")
      mutate_alert(conn, slug, fn alert -> Schedule.acknowledge_alert(alert, by) end)
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp mutate_spec(conn, slug, fun) do
    try do
      spec = Schedule.get_spec_by_slug!(slug)

      case fun.(spec) do
        {:ok, updated} -> json(conn, updated)
        {:error, changeset} -> {:error, changeset}
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "spec_not_found", slug: slug})
    end
  end

  defp mutate_alert(conn, slug, fun) do
    try do
      alert = Schedule.get_alert_by_slug!(slug)

      case fun.(alert) do
        {:ok, updated} -> json(conn, updated)
        {:error, changeset} -> {:error, changeset}
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "alert_not_found", slug: slug})
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, ""), do: opts
  defp maybe_put(opts, key, value), do: [{key, value} | opts]

  defp parse_dt_opt(nil), do: {:ok, nil}
  defp parse_dt_opt(""), do: {:ok, nil}

  defp parse_dt_opt(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> {:ok, dt}
      _ -> {:error, "invalid timestamp: #{str}"}
    end
  end

  defp parse_dt_opt(_), do: {:error, "invalid timestamp"}

  defp validate_window(nil, _), do: :ok
  defp validate_window(_, nil), do: :ok

  defp validate_window(from, to) do
    if DateTime.compare(from, to) in [:lt, :eq] do
      :ok
    else
      {:error, "from must be ≤ to"}
    end
  end

  defp validate_uuid_opt(nil), do: {:ok, nil}
  defp validate_uuid_opt(""), do: {:ok, nil}

  defp validate_uuid_opt(str) when is_binary(str) do
    if Regex.match?(@uuid_regex, str) do
      {:ok, str}
    else
      {:error, "invalid uuid"}
    end
  end

  defp validate_uuid_opt(_), do: {:error, "invalid uuid"}

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

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(n) when is_integer(n), do: n

  defp parse_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp parse_int(_), do: nil

  defp parse_granularity(nil), do: :day
  defp parse_granularity("hour"), do: :hour
  defp parse_granularity("day"), do: :day
  defp parse_granularity("week"), do: :week
  defp parse_granularity("month"), do: :month
  defp parse_granularity(_), do: :day

  defp bad_request(conn, reason) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: to_string(reason)})
  end
end
