defmodule CanopyWeb.SessionController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{Session, SessionEvent, Agent}
  import Ecto.Query

  def index(conn, params) do
    limit = min(String.to_integer(params["limit"] || "50"), 100)
    offset = String.to_integer(params["offset"] || "0")
    agent_id = params["agent_id"]
    status = params["status"]

    query =
      from s in Session,
        join: a in Agent,
        on: s.agent_id == a.id,
        order_by: [desc: s.started_at],
        limit: ^limit,
        offset: ^offset,
        select: %{
          id: s.id,
          agent_id: s.agent_id,
          agent_name: a.name,
          title: a.name,
          model: s.model,
          status: s.status,
          message_count: 0,
          token_usage: %{
            input: s.tokens_input,
            output: s.tokens_output,
            cache_read: s.tokens_cache,
            cache_write: 0
          },
          tokens_input: s.tokens_input,
          tokens_output: s.tokens_output,
          tokens_cache: s.tokens_cache,
          cost_cents: s.cost_cents,
          started_at: s.started_at,
          completed_at: s.completed_at,
          created_at: s.started_at
        }

    query = if agent_id, do: where(query, [s], s.agent_id == ^agent_id), else: query
    query = if status, do: where(query, [s], s.status == ^status), else: query

    sessions = Repo.all(query)
    total = Repo.aggregate(Session, :count)
    json(conn, %{sessions: sessions, total: total})
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(Session, id) |> Repo.preload(:agent) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      session ->
        json(conn, %{
          session: %{
            id: session.id,
            agent_id: session.agent_id,
            agent_name: session.agent.name,
            title: session.agent.name,
            model: session.model,
            status: session.status,
            message_count: 0,
            token_usage: %{
              input: session.tokens_input,
              output: session.tokens_output,
              cache_read: session.tokens_cache,
              cache_write: 0
            },
            tokens_input: session.tokens_input,
            tokens_output: session.tokens_output,
            tokens_cache: session.tokens_cache,
            cost_cents: session.cost_cents,
            workspace_path: session.workspace_path,
            workspace_branch: session.workspace_branch,
            started_at: session.started_at,
            completed_at: session.completed_at,
            created_at: session.started_at
          }
        })
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repo.get(Session, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      session ->
        {:ok, updated} =
          session
          |> Ecto.Changeset.change(status: "cancelled", completed_at: DateTime.utc_now() |> DateTime.truncate(:second))
          |> Repo.update()

        Canopy.EventBus.broadcast(
          Canopy.EventBus.session_topic(id),
          %{event: "run.cancelled", session_id: id}
        )

        json(conn, %{session: %{id: updated.id, status: updated.status}})
    end
  end

  def transcript(conn, %{"session_id" => session_id}) do
    events =
      Repo.all(
        from e in SessionEvent,
          where: e.session_id == ^session_id,
          order_by: [asc: e.id],
          select: %{
            id: e.id,
            event_type: e.event_type,
            data: e.data,
            tokens: e.tokens,
            inserted_at: e.inserted_at
          }
      )

    json(conn, %{events: events})
  end

  def message(conn, %{"session_id" => session_id} = params) do
    body = params["body"] || params["message"] || ""

    case Repo.get(Session, session_id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      _session ->
        now = DateTime.utc_now()

        event = %SessionEvent{
          session_id: session_id,
          event_type: "user_message",
          data: %{"body" => body},
          tokens: 0,
          inserted_at: now
        }

        Repo.insert!(event)

        Canopy.EventBus.broadcast(
          Canopy.EventBus.session_topic(session_id),
          %{event: "user_message", body: body, session_id: session_id}
        )

        conn |> put_status(202) |> json(%{ok: true, session_id: session_id})
    end
  end

  def stream(conn, %{"session_id" => session_id}) do
    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("x-accel-buffering", "no")
      |> send_chunked(200)

    Canopy.EventBus.subscribe(Canopy.EventBus.session_topic(session_id))

    stream_loop(conn, session_id)
  end

  defp stream_loop(conn, session_id) do
    receive do
      %{event: event_type} = event ->
        data = Jason.encode!(event)

        case Plug.Conn.chunk(conn, "event: #{event_type}\ndata: #{data}\n\n") do
          {:ok, conn} -> stream_loop(conn, session_id)
          {:error, _} -> conn
        end
    after
      30_000 ->
        case Plug.Conn.chunk(conn, ": keepalive\n\n") do
          {:ok, conn} -> stream_loop(conn, session_id)
          {:error, _} -> conn
        end
    end
  end
end
