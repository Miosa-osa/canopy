defmodule CanopyWeb.AgentController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{Agent, Approval, CostEvent, Session, Schedule}
  import Ecto.Query

  def index(conn, params) do
    workspace_id = params["workspace_id"]
    user_workspace_ids = conn.assigns[:user_workspace_ids] || []

    query = from a in Agent, order_by: [asc: a.name]

    query =
      cond do
        workspace_id -> where(query, [a], a.workspace_id == ^workspace_id)
        user_workspace_ids != [] -> where(query, [a], a.workspace_id in ^user_workspace_ids)
        true -> query
      end

    agents = Repo.all(query)

    agent_ids = Enum.map(agents, & &1.id)

    # Batch skill lookup — query all then filter to avoid binary_id encoding in IN clause
    skills_map =
      if agent_ids == [] do
        %{}
      else
        Repo.all(
          from as_ in "agent_skills",
            select: {type(as_.agent_id, :binary_id), type(as_.skill_id, :binary_id)}
        )
        |> Enum.filter(fn {aid, _} -> aid in agent_ids end)
        |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      end

    # Batch today's cost stats
    today = Date.utc_today()
    beginning_of_today = DateTime.new!(today, ~T[00:00:00], "Etc/UTC")

    cost_stats_map =
      if agent_ids == [] do
        %{}
      else
        Repo.all(
          from ce in CostEvent,
            where: ce.agent_id in ^agent_ids and ce.inserted_at >= ^beginning_of_today,
            group_by: ce.agent_id,
            select: {ce.agent_id, %{
              cost_cents: coalesce(sum(ce.cost_cents), 0),
              tokens_input: coalesce(sum(ce.tokens_input), 0),
              tokens_output: coalesce(sum(ce.tokens_output), 0),
              tokens_cache: coalesce(sum(ce.tokens_cache), 0)
            }}
        )
        |> Map.new()
      end

    # Batch last active
    last_active_map =
      if agent_ids == [] do
        %{}
      else
        Repo.all(
          from s in Session,
            where: s.agent_id in ^agent_ids,
            group_by: s.agent_id,
            select: {s.agent_id, max(s.updated_at)}
        )
        |> Map.new()
      end

    serialized =
      Enum.map(agents, fn agent ->
        skill_ids = Map.get(skills_map, agent.id, [])
        today_stats = Map.get(cost_stats_map, agent.id)
        last_active = Map.get(last_active_map, agent.id)
        serialize(agent, today_stats, last_active) |> Map.put(:skills, skill_ids)
      end)

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
            Canopy.EventBus.broadcast(
              Canopy.EventBus.workspace_topic(updated.workspace_id),
              %{event: "agent.updated", agent_id: updated.id}
            )

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
    # Re-enable schedules that were disabled by sleep
    from(s in Schedule, where: s.agent_id == ^id)
    |> Repo.update_all(set: [enabled: true, updated_at: DateTime.utc_now()])

    # Re-sync with Quantum scheduler
    agent_schedules =
      Repo.all(from s in Schedule, where: s.agent_id == ^id and s.enabled == true)

    Enum.each(agent_schedules, &Canopy.Scheduler.add_schedule/1)

    transition_status(conn, id, "idle", "agent.heartbeat_started")
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

        case agent
             |> Ecto.Changeset.change(status: "sleeping")
             |> Repo.update() do
          {:ok, updated} ->
            broadcast_status(updated, "agent.sleeping")
            json(conn, %{agent: serialize_with_skills(updated)})

          {:error, _changeset} ->
            conn |> put_status(500) |> json(%{error: "update_failed"})
        end
    end
  end

  def pause(conn, %{"agent_id" => id}) do
    transition_status(conn, id, "paused", "agent.paused")
  end

  def resume(conn, %{"agent_id" => id}) do
    transition_status(conn, id, "idle", "agent.resumed")
  end

  def focus(conn, %{"agent_id" => id}) do
    transition_status(conn, id, "running", "agent.focused")
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

  def runs(conn, %{"agent_id" => id} = params) do
    limit = min(String.to_integer(params["limit"] || "50"), 200)
    offset = String.to_integer(params["offset"] || "0")

    sessions =
      Repo.all(
        from s in Session,
          where: s.agent_id == ^id,
          order_by: [desc: s.started_at],
          limit: ^limit,
          offset: ^offset
      )

    total = Repo.aggregate(from(s in Session, where: s.agent_id == ^id), :count)

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
        end),
      total: total
    })
  end

  def inbox(conn, %{"agent_id" => id} = params) do
    status_filter = params["status"]
    limit = min(String.to_integer(params["limit"] || "50"), 200)
    offset = String.to_integer(params["offset"] || "0")

    # Primary inbox: approval requests made by this agent awaiting human review
    approval_query =
      from a in Approval,
        where: a.requested_by == ^id,
        order_by: [desc: a.inserted_at],
        limit: ^limit,
        offset: ^offset

    approval_query =
      if status_filter do
        where(approval_query, [a], a.status == ^status_filter)
      else
        approval_query
      end

    approvals = Repo.all(approval_query)

    pending_count =
      Repo.aggregate(
        from(a in Approval, where: a.requested_by == ^id and a.status == "pending"),
        :count
      )

    json(conn, %{
      items: Enum.map(approvals, &serialize_inbox_item/1),
      pending_count: pending_count
    })
  end

  def hierarchy(conn, params) do
    workspace_id = params["workspace_id"]
    user_workspace_ids = conn.assigns[:user_workspace_ids] || []

    query = from a in Agent, order_by: [asc: a.name]

    query =
      cond do
        workspace_id -> where(query, [a], a.workspace_id == ^workspace_id)
        user_workspace_ids != [] -> where(query, [a], a.workspace_id in ^user_workspace_ids)
        true -> query
      end
    agents = Repo.all(query)

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
        case agent
             |> Ecto.Changeset.change(status: new_status)
             |> Repo.update() do
          {:ok, updated} ->
            broadcast_status(updated, event_type)
            json(conn, %{agent: serialize_with_skills(updated)})

          {:error, _changeset} ->
            conn |> put_status(500) |> json(%{error: "update_failed"})
        end
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
      team_id: a.team_id,
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

  defp serialize_inbox_item(%Approval{} = a) do
    %{
      id: a.id,
      type: "approval",
      title: a.title,
      description: a.description,
      status: a.status,
      decision: a.decision,
      decision_comment: a.decision_comment,
      context: a.context,
      requested_by: a.requested_by,
      reviewer_id: a.reviewer_id,
      workspace_id: a.workspace_id,
      expires_at: a.expires_at,
      created_at: a.inserted_at,
      updated_at: a.updated_at
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
