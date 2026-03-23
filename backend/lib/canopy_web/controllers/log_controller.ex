defmodule CanopyWeb.LogController do
  use CanopyWeb, :controller

  import Ecto.Query
  alias Canopy.Repo

  def index(conn, params) do
    limit = min(String.to_integer(params["limit"] || "200"), 500)
    offset = String.to_integer(params["offset"] || "0")

    query =
      from e in Canopy.Schemas.ActivityEvent,
        left_join: a in Canopy.Schemas.Agent, on: e.agent_id == a.id,
        order_by: [desc: e.inserted_at],
        limit: ^limit,
        offset: ^offset,
        select: %{
          id: e.id,
          level: e.level,
          source: e.event_type,
          message: e.message,
          agent_id: e.agent_id,
          agent_name: a.name,
          metadata: e.metadata,
          created_at: e.inserted_at
        }

    workspace_id = params["workspace_id"]
    user_workspace_ids = conn.assigns[:user_workspace_ids] || []

    query =
      cond do
        workspace_id -> where(query, [e], e.workspace_id == ^workspace_id)
        user_workspace_ids != [] -> where(query, [e], e.workspace_id in ^user_workspace_ids)
        true -> query
      end

    query = if params["level"],
      do: where(query, [e], e.level == ^params["level"]),
      else: query

    entries = Repo.all(query)
    json(conn, %{entries: entries})
  end

  def stream(conn, params) do
    level = params["level"]
    source = params["source"]

    topic =
      case params["workspace_id"] do
        nil -> Canopy.EventBus.logs_topic()
        workspace_id -> Canopy.EventBus.workspace_topic(workspace_id)
      end

    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("x-accel-buffering", "no")
      |> send_chunked(200)

    Canopy.EventBus.subscribe(topic)

    stream_loop(conn, level, source)
  end

  defp stream_loop(conn, level_filter, source_filter) do
    receive do
      %{event: event_type} = event ->
        if passes_filter?(event, level_filter, source_filter) do
          data = Jason.encode!(event)

          case Plug.Conn.chunk(conn, "event: #{event_type}\ndata: #{data}\n\n") do
            {:ok, conn} -> stream_loop(conn, level_filter, source_filter)
            {:error, _} -> conn
          end
        else
          stream_loop(conn, level_filter, source_filter)
        end

      %{} = event ->
        if passes_filter?(event, level_filter, source_filter) do
          data = Jason.encode!(event)

          case Plug.Conn.chunk(conn, "data: #{data}\n\n") do
            {:ok, conn} -> stream_loop(conn, level_filter, source_filter)
            {:error, _} -> conn
          end
        else
          stream_loop(conn, level_filter, source_filter)
        end

      _non_map ->
        # Ignore non-map messages (monitor refs, system messages, etc.)
        stream_loop(conn, level_filter, source_filter)
    after
      30_000 ->
        case Plug.Conn.chunk(conn, ": keepalive\n\n") do
          {:ok, conn} -> stream_loop(conn, level_filter, source_filter)
          {:error, _} -> conn
        end
    end
  end

  defp passes_filter?(event, level_filter, source_filter) do
    level_ok =
      case level_filter do
        nil -> true
        lvl -> Map.get(event, :level) == lvl or Map.get(event, "level") == lvl
      end

    source_ok =
      case source_filter do
        nil -> true
        src -> Map.get(event, :source) == src or Map.get(event, "source") == src
      end

    level_ok and source_ok
  end
end
