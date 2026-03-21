defmodule CanopyWeb.AgentController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{Agent, ActivityEvent, CostEvent, Session, Schedule}
  import Ecto.Query

  def index(conn, params) do
    workspace_id = params["workspace_id"]

    query = from a in Agent, order_by: [asc: a.name]
    query = if workspace_id, do: where(query, [a], a.workspace_id == ^workspace_id), else: query

    agents = Repo.all(query)
    serialized = Enum.map(agents, &serialize_with_skills/1)
    json(conn, %{agents: serialized, count: length(serialized)})
  end

  def create(conn, params) do
    changeset = Agent.changeset(%Agent{}, params)

    case Repo.insert(changeset) do
      {:ok, agent} ->
        Canopy.EventBus.broadcast(
          Canopy.EventBus.workspace_topic(agent.workspace_id),
          %{event: "agent.hired", agent_id: agent.id, name: agent.name}
        )

        conn |> put_status(201) |> json(%{agent: serialize_with_skills(agent)})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_failed", details: format_errors(changeset)})
    end
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(Agent, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      agent ->
        last_session =
          Repo.one(
            from s in Session,
              where: s.agent_id == ^id,
              order_by: [desc: s.started_at],
              limit: 1
          )

        total_cost =
          Repo.one(
            from s in Session,
              where: s.agent_id == ^id,
              select: coalesce(sum(s.cost_cents), 0)
          ) || 0

        total_sessions =
          Repo.aggregate(from(s in Session, where: s.agent_id == ^id), :count)

        json(conn,
          serialize_with_skills(agent)
          |> Map.merge(%{
            last_session:
              last_session &&
                %{
                  id: last_session.id,
                  status: last_session.status,
                  model: last_session.model,
                  started_at: last_session.started_at,
                  cost_cents: last_session.cost_cents
                },
            total_cost_cents: total_cost,
            total_sessions: total_sessions
          })
        )
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Repo.get(Agent, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      agent ->
        changeset = Agent.changeset(agent, params)

        case Repo.update(changeset) do
          {:ok, updated} ->
            json(conn, %{agent: serialize_with_skills(updated)})

          {:error, changeset} ->
            conn
            |> put_status(422)
            |> json(%{error: "validation_failed", details: format_errors(changeset)})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repo.get(Agent, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      agent ->
        Repo.delete!(agent)

        Canopy.EventBus.broadcast(
          Canopy.EventBus.workspace_topic(agent.workspace_id),
          %{event: "agent.terminated", agent_id: agent.id}
        )

        json(conn, %{ok: true})
    end
  end

  # --- Lifecycle actions ---

  def wake(conn, %{"agent_id" => id}) do
    transition_status(conn, id, "active", "agent.heartbeat_started")
  end

  def sleep(conn, %{"agent_id" => id}) do
    case Repo.get(Agent, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      agent ->
        Repo.update_all(
          from(s in Schedule, where: s.agent_id == ^id),
          set: [enabled: false]
        )

        {:ok, updated} =
          agent
          |> Ecto.Changeset.change(status: "sleeping")
          |> Repo.update()

        broadcast_status(updated, "agent.sleeping")
        json(conn, %{agent: serialize_with_skills(updated)})
    end
  end

  def pause(conn, %{"agent_id" => id}) do
    transition_status(conn, id, "paused", "agent.paused")
  end

  def resume(conn, %{"agent_id" => id}) do
    transition_status(conn, id, "idle", "agent.resumed")
  end

  def focus(conn, %{"agent_id" => id}) do
    transition_status(conn, id, "working", "agent.focused")
  end

  def terminate(conn, %{"agent_id" => id}) do
    case Repo.get(Agent, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      agent ->
        Repo.delete!(agent)
        broadcast_status(agent, "agent.terminated")
        json(conn, %{ok: true})
    end
  end

  # --- Queries ---

  def runs(conn, %{"agent_id" => id}) do
    sessions =
      Repo.all(
        from s in Session,
          where: s.agent_id == ^id,
          order_by: [desc: s.started_at],
          limit: 50
      )

    json(conn, %{
      runs:
        Enum.map(sessions, fn s ->
          %{
            id: s.id,
            model: s.model,
            status: s.status,
            started_at: s.started_at,
            completed_at: s.completed_at,
            tokens_input: s.tokens_input,
            tokens_output: s.tokens_output,
            cost_cents: s.cost_cents
          }
        end)
    })
  end

  def inbox(conn, %{"agent_id" => id} = params) do
    unread_only = params["unread"] == "true"
    limit = min(String.to_integer(params["limit"] || "50"), 200)
    offset = String.to_integer(params["offset"] || "0")

    query =
      from e in ActivityEvent,
        where: e.agent_id == ^id and e.level == "notification",
        order_by: [desc: e.inserted_at],
        limit: ^limit,
        offset: ^offset

    query =
      if unread_only do
        where(
          query,
          [e],
          fragment("COALESCE((?->>'read')::boolean, false) = false", e.metadata)
        )
      else
        query
      end

    messages = Repo.all(query)

    unread_count =
      Repo.aggregate(
        from(e in ActivityEvent,
          where:
            e.agent_id == ^id and
              e.level == "notification" and
              fragment("COALESCE((?->>'read')::boolean, false) = false", e.metadata)
        ),
        :count
      )

    json(conn, %{
      messages: Enum.map(messages, &serialize_inbox_message/1),
      unread_count: unread_count
    })
  end

  def hierarchy(conn, _params) do
    agents = Repo.all(from a in Agent, order_by: [asc: a.name])

    json(conn, %{
      agents:
        Enum.map(agents, fn a ->
          %{
            id: a.id,
            name: a.name,
            role: a.role,
            status: a.status,
            adapter: a.adapter,
            reports_to: a.reports_to,
            workspace_id: a.workspace_id
          }
        end)
    })
  end

  # --- Private helpers ---

  # Applies a status transition and broadcasts the lifecycle event.
  # Uses Ecto.Changeset.change/2 (bypasses validation) because lifecycle
  # state machine transitions are controller-controlled, not user-input driven.
  defp transition_status(conn, id, new_status, event_type) do
    case Repo.get(Agent, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      agent ->
        {:ok, updated} =
          agent
          |> Ecto.Changeset.change(status: new_status)
          |> Repo.update()

        broadcast_status(updated, event_type)
        json(conn, %{agent: serialize_with_skills(updated)})
    end
  end

  defp broadcast_status(agent, event_type) do
    Canopy.EventBus.broadcast(
      Canopy.EventBus.workspace_topic(agent.workspace_id),
      %{event: event_type, agent_id: agent.id, status: agent.status}
    )
  end

  defp serialize_with_skills(%Agent{} = a) do
    skill_ids =
      Repo.all(
        from as_ in "agent_skills",
          where: as_.agent_id == type(^a.id, :binary_id),
          select: type(as_.skill_id, :binary_id)
      )

    today = Date.utc_today()
    beginning_of_today = DateTime.new!(today, ~T[00:00:00], "Etc/UTC")

    today_stats =
      Repo.one(
        from ce in CostEvent,
          where: ce.agent_id == ^a.id and ce.inserted_at >= ^beginning_of_today,
          select: %{
            cost_cents: coalesce(sum(ce.cost_cents), 0),
            tokens_input: coalesce(sum(ce.tokens_input), 0),
            tokens_output: coalesce(sum(ce.tokens_output), 0),
            tokens_cache: coalesce(sum(ce.tokens_cache), 0)
          }
      )

    last_active_at =
      Repo.one(
        from s in Session,
          where: s.agent_id == ^a.id,
          order_by: [desc: s.updated_at],
          limit: 1,
          select: s.updated_at
      )

    serialize(a, today_stats, last_active_at) |> Map.put(:skills, skill_ids)
  end

  defp serialize(%Agent{} = a, today_stats, last_active_at) do
    cost_today_cents = if today_stats, do: today_stats.cost_cents, else: 0

    token_usage_today =
      if today_stats do
        %{
          input: today_stats.tokens_input,
          output: today_stats.tokens_output,
          cache_read: today_stats.tokens_cache,
          cache_write: 0
        }
      else
        %{input: 0, output: 0, cache_read: 0, cache_write: 0}
      end

    %{
      id: a.id,
      slug: a.slug,
      name: a.name,
      display_name: a.name,
      avatar_emoji: a.avatar_emoji || "🤖",
      role: a.role,
      adapter: a.adapter,
      model: a.model,
      status: a.status,
      temperature: a.temperature,
      max_concurrent_runs: a.max_concurrent_runs,
      config: a.config,
      system_prompt: a.system_prompt,
      workspace_id: a.workspace_id,
      reports_to: a.reports_to,
      schedule_id: nil,
      budget_policy_id: nil,
      current_task: nil,
      last_active_at: last_active_at,
      token_usage_today: token_usage_today,
      cost_today_cents: cost_today_cents,
      created_at: a.inserted_at,
      inserted_at: a.inserted_at,
      updated_at: a.updated_at
    }
  end

  defp serialize_inbox_message(%ActivityEvent{} = e) do
    %{
      id: e.id,
      type: e.event_type,
      event_type: e.event_type,
      message: e.message,
      title: e.message,
      body: e.message,
      level: e.level,
      metadata: e.metadata,
      agent_id: e.agent_id,
      workspace_id: e.workspace_id,
      read: get_in(e.metadata || %{}, ["read"]) == true,
      status: if(get_in(e.metadata || %{}, ["read"]) == true, do: "read", else: "unread"),
      created_at: e.inserted_at,
      inserted_at: e.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
