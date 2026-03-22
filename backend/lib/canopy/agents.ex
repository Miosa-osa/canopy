defmodule Canopy.Agents do
  @moduledoc "Agent management context."

  alias Canopy.Repo
  alias Canopy.Schemas.{Agent, Session, Schedule, ActivityEvent}
  import Ecto.Query

  def list_agents(opts \\ []) do
    query = from a in Agent, order_by: [asc: a.name]
    query = if ws = opts[:workspace_id], do: where(query, [a], a.workspace_id == ^ws), else: query
    Repo.all(query)
  end

  def get_agent(id), do: Repo.get(Agent, id)
  def get_agent!(id), do: Repo.get!(Agent, id)

  def create_agent(attrs) do
    result = %Agent{} |> Agent.changeset(attrs) |> Repo.insert()

    case result do
      {:ok, agent} ->
        Canopy.EventBus.broadcast(
          Canopy.EventBus.workspace_topic(agent.workspace_id),
          %{event: "agent.hired", agent_id: agent.id, name: agent.name}
        )

        persist_activity_event(agent, "agent.hired", "Agent #{agent.name} was hired")

        {:ok, agent}

      error ->
        error
    end
  end

  def update_agent(%Agent{} = agent, attrs) do
    agent |> Agent.changeset(attrs) |> Repo.update()
  end

  def delete_agent(%Agent{} = agent) do
    result = Repo.delete(agent)

    case result do
      {:ok, _} ->
        Canopy.EventBus.broadcast(
          Canopy.EventBus.workspace_topic(agent.workspace_id),
          %{event: "agent.terminated", agent_id: agent.id}
        )

        persist_activity_event(agent, "agent.terminated", "Agent #{agent.name} was terminated")

      _ ->
        :ok
    end

    result
  end

  def transition_status(%Agent{} = agent, new_status) do
    old_status = agent.status
    {:ok, updated} = agent |> Ecto.Changeset.change(status: new_status) |> Repo.update()

    Canopy.EventBus.broadcast(
      Canopy.EventBus.workspace_topic(updated.workspace_id),
      %{
        event: "agent.status_changed",
        agent_id: updated.id,
        from: old_status,
        to: new_status
      }
    )

    persist_activity_event(updated, "agent.status_changed", "Agent #{updated.name} status changed from #{old_status} to #{new_status}", %{from: old_status, to: new_status})

    {:ok, updated}
  end

  def sleep_agent(%Agent{} = agent) do
    Repo.update_all(
      from(s in Schedule, where: s.agent_id == ^agent.id),
      set: [enabled: false]
    )

    transition_status(agent, "sleeping")
  end

  def get_hierarchy do
    Repo.all(
      from a in Agent,
        order_by: [asc: a.name],
        select: %{
          id: a.id,
          name: a.name,
          role: a.role,
          status: a.status,
          adapter: a.adapter,
          reports_to: a.reports_to,
          workspace_id: a.workspace_id
        }
    )
  end

  def get_agent_stats(agent_id) do
    last_session =
      Repo.one(
        from s in Session,
          where: s.agent_id == ^agent_id,
          order_by: [desc: s.started_at],
          limit: 1
      )

    total_cost =
      Repo.one(
        from s in Session,
          where: s.agent_id == ^agent_id,
          select: coalesce(sum(s.cost_cents), 0)
      ) || 0

    total_sessions =
      Repo.aggregate(from(s in Session, where: s.agent_id == ^agent_id), :count)

    %{
      last_session: last_session,
      total_cost_cents: total_cost,
      total_sessions: total_sessions
    }
  end

  def list_agent_runs(agent_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Repo.all(
      from s in Session,
        where: s.agent_id == ^agent_id,
        order_by: [desc: s.started_at],
        limit: ^limit
    )
  end

  defp persist_activity_event(agent, event_type, message, metadata \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %ActivityEvent{}
    |> ActivityEvent.changeset(%{
      event_type: event_type,
      message: message,
      metadata: metadata,
      level: "info",
      workspace_id: agent.workspace_id,
      agent_id: agent.id
    })
    |> Ecto.Changeset.put_change(:inserted_at, now)
    |> Repo.insert()

    Canopy.EventBus.broadcast(
      Canopy.EventBus.activity_topic(),
      %{
        event: event_type,
        agent_id: agent.id,
        agent_name: agent.name,
        message: message,
        workspace_id: agent.workspace_id,
        metadata: metadata,
        created_at: now
      }
    )
  end
end
