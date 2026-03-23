defmodule CanopyWeb.ActivityController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{ActivityEvent, Agent}
  import Ecto.Query

  def index(conn, params) do
    workspace_id = params["workspace_id"]
    agent_id = params["agent_id"]
    event_type = params["event_type"]
    level = params["level"]
    limit = min(String.to_integer(params["limit"] || "50"), 200)
    offset = String.to_integer(params["offset"] || "0")

    query =
      from e in ActivityEvent,
        left_join: a in Agent,
        on: e.agent_id == a.id,
        order_by: [desc: e.inserted_at],
        limit: ^limit,
        offset: ^offset,
        select: {e, a.name}

    user_workspace_ids = conn.assigns[:user_workspace_ids] || []

    query =
      cond do
        workspace_id -> where(query, [e], e.workspace_id == ^workspace_id)
        user_workspace_ids != [] -> where(query, [e], e.workspace_id in ^user_workspace_ids)
        true -> query
      end

    query = if agent_id, do: where(query, [e], e.agent_id == ^agent_id), else: query
    query = if event_type, do: where(query, [e], e.event_type == ^event_type), else: query
    query = if level, do: where(query, [e], e.level == ^level), else: query

    results = Repo.all(query)

    # Build filtered count query with the same conditions (without limit/offset/select)
    count_query = from e in ActivityEvent

    count_query =
      cond do
        workspace_id -> where(count_query, [e], e.workspace_id == ^workspace_id)
        user_workspace_ids != [] -> where(count_query, [e], e.workspace_id in ^user_workspace_ids)
        true -> count_query
      end

    count_query = if agent_id, do: where(count_query, [e], e.agent_id == ^agent_id), else: count_query
    count_query = if event_type, do: where(count_query, [e], e.event_type == ^event_type), else: count_query
    count_query = if level, do: where(count_query, [e], e.level == ^level), else: count_query
    total = Repo.aggregate(count_query, :count)

    json(conn, %{events: Enum.map(results, fn {e, agent_name} -> serialize(e, agent_name) end), total: total})
  end

  def stream(conn, params) do
    topic =
      case params["workspace_id"] do
        nil -> Canopy.EventBus.activity_topic()
        workspace_id -> Canopy.EventBus.workspace_topic(workspace_id)
      end

    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("x-accel-buffering", "no")
      |> send_chunked(200)

    Canopy.EventBus.subscribe(topic)

    stream_loop(conn)
  end

  defp stream_loop(conn) do
    receive do
      %{event: event_type} = event ->
        data = Jason.encode!(event)

        case Plug.Conn.chunk(conn, "event: #{event_type}\ndata: #{data}\n\n") do
          {:ok, conn} -> stream_loop(conn)
          {:error, _} -> conn
        end

      %{} = event ->
        data = Jason.encode!(event)

        case Plug.Conn.chunk(conn, "data: #{data}\n\n") do
          {:ok, conn} -> stream_loop(conn)
          {:error, _} -> conn
        end

      _non_map ->
        # Ignore non-map messages (e.g. {:plug_conn, :sent} from send_chunked)
        stream_loop(conn)
    after
      30_000 ->
        case Plug.Conn.chunk(conn, ": keepalive\n\n") do
          {:ok, conn} -> stream_loop(conn)
          {:error, _} -> conn
        end
    end
  end

  defp serialize(%ActivityEvent{} = e, agent_name) do
    %{
      id: e.id,
      type: e.event_type,
      event_type: e.event_type,
      agent_id: e.agent_id,
      agent_name: agent_name,
      title: e.message,
      detail: e.message,
      message: e.message,
      metadata: e.metadata,
      level: e.level,
      workspace_id: e.workspace_id,
      created_at: e.inserted_at,
      inserted_at: e.inserted_at
    }
  end
end
