defmodule CanopyWeb.SpawnController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{Agent, Session}
  import Ecto.Query

  # Governance gate: spawning an agent requires approval unless the requester
  # holds an auto-approved role (e.g. admin) or the workspace policy opts out.
  plug CanopyWeb.Plugs.Governance, [action: :spawn_agent] when action in [:create]

  def create(conn, params) do
    agent_id = params["agent_id"]
    context = params["context"] || params["prompt"] || ""
    user_workspace_ids = conn.assigns[:user_workspace_ids] || []

    with %Agent{} = agent <- Repo.get(Agent, agent_id),
         true <- user_workspace_ids == [] or agent.workspace_id in user_workspace_ids do
      session_params = %{
        "agent_id" => agent_id,
        "workspace_id" => agent.workspace_id,
        "model" => params["model"] || agent.model,
        "started_at" => DateTime.utc_now() |> DateTime.truncate(:second),
        "context" => context,
        "status" => "active"
      }

      changeset = Session.changeset(%Session{}, session_params)

      case Repo.insert(changeset) do
        {:ok, session} ->
          Task.Supervisor.start_child(Canopy.HeartbeatRunner, fn ->
            Canopy.Heartbeat.run(agent_id, context: context, session_id: session.id)
          end)

          conn
          |> put_status(201)
          |> json(%{session: %{id: session.id, status: session.status}})

        {:error, cs} ->
          conn
          |> put_status(422)
          |> json(%{error: "validation_failed", details: format_errors(cs)})
      end
    else
      nil -> conn |> put_status(404) |> json(%{error: "agent_not_found"})
      false -> conn |> put_status(403) |> json(%{error: "forbidden"})
    end
  end

  def active(conn, _params) do
    user_workspace_ids = conn.assigns[:user_workspace_ids] || []

    query =
      from s in Session,
        where: s.status == "active",
        order_by: [desc: s.started_at]

    query =
      if user_workspace_ids != [] do
        where(query, [s], s.workspace_id in ^user_workspace_ids)
      else
        query
      end

    sessions = Repo.all(query)

    json(conn, %{
      instances:
        Enum.map(sessions, fn s ->
          %{
            id: s.id,
            agent_id: s.agent_id,
            model: s.model,
            status: s.status,
            started_at: s.started_at
          }
        end)
    })
  end

  def kill(conn, %{"id" => id}) do
    case Repo.get(Session, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      session ->
        case session
             |> Ecto.Changeset.change(
               status: "cancelled",
               completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
             )
             |> Repo.update() do
          {:ok, _} ->
            json(conn, %{ok: true})

          {:error, _changeset} ->
            conn |> put_status(500) |> json(%{error: "update_failed"})
        end
    end
  end

  def history(conn, params) do
    limit = min(String.to_integer(params["limit"] || "50"), 100)
    user_workspace_ids = conn.assigns[:user_workspace_ids] || []

    query =
      from s in Session,
        where: s.status in ["completed", "failed", "cancelled"],
        order_by: [desc: s.completed_at],
        limit: ^limit

    query =
      if user_workspace_ids != [] do
        where(query, [s], s.workspace_id in ^user_workspace_ids)
      else
        query
      end

    sessions = Repo.all(query)

    json(conn, %{
      history:
        Enum.map(sessions, fn s ->
          %{
            id: s.id,
            agent_id: s.agent_id,
            model: s.model,
            status: s.status,
            started_at: s.started_at,
            completed_at: s.completed_at,
            cost_cents: s.cost_cents
          }
        end)
    })
  end

  # --- Private helpers ---

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
