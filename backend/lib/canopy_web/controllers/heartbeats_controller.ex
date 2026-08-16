defmodule CanopyWeb.HeartbeatsController do
  @moduledoc """
  HTTP API for pty heartbeat telemetry and session stats.

  Routes:
    GET  /api/v1/heartbeats?session_id=...&limit=50
    GET  /api/v1/heartbeats?workspace_slug=...&limit=200
    GET  /api/v1/sessions/:id/stats
    GET  /api/v1/activity?workspace_slug=...&limit=50&type=...
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Activity
  alias Canopy.Heartbeats
  alias Canopy.Sessions
  alias CanopyWeb.Schemas.HeartbeatsSchema

  action_fallback CanopyWeb.FallbackController

  tags ["heartbeats"]

  operation :index,
    summary: "List heartbeats",
    description:
      "Returns heartbeats filtered by session_id or workspace_slug, most-recent-first.",
    parameters: [
      session_id: [in: :query, type: :string, required: false],
      workspace_slug: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [
      ok: {"Heartbeat list", "application/json", HeartbeatsSchema.HeartbeatList}
    ]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    limit = parse_int(params["limit"]) || 50

    heartbeats =
      cond do
        params["session_id"] ->
          Heartbeats.list_for_session(params["session_id"], limit: limit)

        params["workspace_slug"] ->
          Heartbeats.list_for_workspace(params["workspace_slug"], limit: limit)

        true ->
          Heartbeats.list_for_company(limit: limit)
      end

    json(conn, %{data: heartbeats, count: length(heartbeats)})
  end

  operation :stats,
    summary: "Session heartbeat stats",
    description: "Returns aggregate byte counts and timing for a session.",
    parameters: [
      id: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Session stats", "application/json", HeartbeatsSchema.SessionStats},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec stats(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def stats(conn, %{"id" => id}) do
    with {:ok, _session} <- Sessions.get(id) do
      result = Heartbeats.stats(id)
      json(conn, Map.put(result, :session_id, id))
    end
  end

  operation :activity,
    summary: "Unified activity feed",
    description:
      "Returns a time-sorted feed of events: session spawns/endings, task transitions, issue transitions.",
    parameters: [
      workspace_slug: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false],
      type: [in: :query, type: :string, required: false, description: "Filter by event type"]
    ],
    responses: [
      ok: {"Activity feed", "application/json", HeartbeatsSchema.ActivityFeed}
    ]

  @spec activity(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def activity(conn, params) do
    opts =
      []
      |> put_if(params["workspace_slug"], :workspace_slug, params["workspace_slug"])
      |> put_if(params["limit"], :limit, parse_int(params["limit"]))
      |> put_if(params["type"], :type, params["type"])

    events = Activity.feed(opts)
    json(conn, %{data: events, count: length(events)})
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp put_if(opts, nil, _key, _val), do: opts
  defp put_if(opts, "", _key, _val), do: opts
  defp put_if(opts, _truthy, key, val), do: Keyword.put(opts, key, val)

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_integer(val), do: val

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, ""} -> n
      _ -> nil
    end
  end
end
