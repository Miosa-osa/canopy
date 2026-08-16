defmodule Canopy.Orchestrator do
  @moduledoc """
  Multi-agent task orchestrator.

  Dispatches unclaimed tasks to idle agents, detects stalled claims,
  retries failed tasks, and unblocks milestones whose dependencies are met.

  ## API

  - `dispatch/0`              — one pass: match unclaimed tasks to idle agents by skill
  - `check_stalls/0`          — find tasks claimed > 10 min with no output → mark stalled
  - `retry/1`                 — re-queue a failed task (clear claim, increment retry_count)
  - `resolve_dependencies/1`  — for a mission, find milestones newly unblocked
  - `auto_dispatch/0`         — full sweep: stalls → dep resolution → dispatch
  - `status/0`                — queue snapshot for the status endpoint
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Agents
  alias Canopy.Agents.Agent
  alias Canopy.Missions
  alias Canopy.Missions.{Milestone, Mission}
  alias Canopy.Repo
  alias Canopy.Tasks.Dispatcher
  alias Canopy.Tasks.Kanban
  alias Canopy.Tasks.Task

  require Logger

  @stall_minutes 10

  # ---------------------------------------------------------------------------
  # auto_dispatch/0 — full sweep called by the Oban worker
  # ---------------------------------------------------------------------------

  @doc """
  Full orchestration sweep. Called every minute by `AutoDispatchWorker`.

  1. Check and mark stalled claims.
  2. Resolve milestone dependencies (unblock milestones whose deps are done).
  3. Dispatch unclaimed tasks to idle agents.
  """
  @spec auto_dispatch() :: %{stalled: non_neg_integer(), dispatched: non_neg_integer()}
  def auto_dispatch do
    stalled = check_stalls()
    _unblocked = resolve_all_active_missions()
    dispatched = dispatch()

    Logger.info(
      "[Orchestrator] sweep complete stalled=#{stalled} dispatched=#{dispatched}"
    )

    %{stalled: stalled, dispatched: dispatched}
  end

  # ---------------------------------------------------------------------------
  # dispatch/0 — match unclaimed tasks to idle agents
  # ---------------------------------------------------------------------------

  @doc """
  Finds idle agents and matches them to unclaimed auto-assignable tasks by skill.

  Returns the number of tasks successfully dispatched this pass.
  """
  @spec dispatch() :: non_neg_integer()
  def dispatch do
    {:ok, agents} = Agents.list_hired()

    idle_agents =
      agents
      |> Enum.filter(&auto_pickup_enabled?/1)
      |> Enum.filter(fn agent -> active_session_count(agent.slug) == 0 end)

    Enum.reduce(idle_agents, 0, fn agent, acc ->
      skills = agent_skills(agent)

      case Kanban.next_unclaimed(skills) do
        nil ->
          acc

        %Task{} = task ->
          case attempt_claim_and_dispatch(agent, task) do
            :dispatched -> acc + 1
            :failed -> acc
          end
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # check_stalls/0
  # ---------------------------------------------------------------------------

  @doc """
  Finds tasks claimed longer than `@stall_minutes` with no active session output.
  Releases the claim back to Backlog so another agent can pick up.

  Returns the number of tasks released.
  """
  @spec check_stalls() :: non_neg_integer()
  def check_stalls do
    stall_cutoff =
      DateTime.utc_now()
      |> DateTime.add(-@stall_minutes * 60, :second)

    stalled =
      Repo.all(
        from(t in Task,
          where:
            not is_nil(t.claimed_by_agent_id) and
              t.status != "done" and
              t.claimed_at < ^stall_cutoff and
              is_nil(t.session_id)
        )
      )

    Enum.each(stalled, fn task ->
      Logger.warning(
        "[Orchestrator] stall detected task=#{task.short_id} agent=#{task.claimed_by_agent_id} claimed_at=#{task.claimed_at}"
      )

      _ = Kanban.release_task(task.short_id)
    end)

    length(stalled)
  end

  # ---------------------------------------------------------------------------
  # retry/1
  # ---------------------------------------------------------------------------

  @doc """
  Re-queues a failed task.

  Clears claim fields, resets status to "todo", and increments a
  `retry_count` label so callers can cap retries if needed.
  """
  @spec retry(String.t()) :: {:ok, Task.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def retry(task_short_id) when is_binary(task_short_id) do
    with {:ok, task} <- Canopy.Tasks.get(task_short_id) do
      retry_count = current_retry_count(task) + 1
      labels = update_retry_label(task.labels, retry_count)

      task
      |> Task.changeset(%{
        status: "todo",
        claimed_by_agent_id: nil,
        claimed_at: nil,
        labels: labels
      })
      |> Repo.update()
    end
  end

  # ---------------------------------------------------------------------------
  # resolve_dependencies/1
  # ---------------------------------------------------------------------------

  @doc """
  For a given mission, finds milestones that are blocked/pending whose
  dependencies are all completed, and activates them.

  Returns the list of milestone IDs that were unblocked.
  """
  @spec resolve_dependencies(String.t()) :: [String.t()]
  def resolve_dependencies(mission_id) when is_binary(mission_id) do
    with {:ok, mission} <- Missions.get_mission(mission_id) do
      mission.milestones
      |> Enum.filter(&(&1.status in ["pending", "blocked"]))
      |> Enum.filter(&deps_completed?/1)
      |> Enum.map(fn milestone ->
        case milestone
             |> Milestone.changeset(%{status: "active"})
             |> Repo.update() do
          {:ok, updated} ->
            Logger.info(
              "[Orchestrator] milestone unblocked mission=#{mission_id} milestone=#{updated.id}"
            )

            updated.id

          {:error, reason} ->
            Logger.warning(
              "[Orchestrator] failed to unblock milestone=#{milestone.id} reason=#{inspect(reason)}"
            )

            nil
        end
      end)
      |> Enum.reject(&is_nil/1)
    else
      {:error, :not_found} -> []
    end
  end

  # ---------------------------------------------------------------------------
  # status/0
  # ---------------------------------------------------------------------------

  @doc """
  Returns a snapshot of the orchestration queue.

      %{
        unclaimed_tasks:  integer,
        claimed_tasks:    integer,
        idle_agents:      integer,
        stall_candidates: integer
      }
  """
  @spec status() :: map()
  def status do
    stall_cutoff =
      DateTime.utc_now()
      |> DateTime.add(-@stall_minutes * 60, :second)

    unclaimed =
      Repo.aggregate(
        from(t in Task,
          where:
            t.auto_assignable == true and is_nil(t.claimed_by_agent_id) and
              t.status in ["todo", "in_progress"]
        ),
        :count,
        :id
      )

    claimed =
      Repo.aggregate(
        from(t in Task,
          where: not is_nil(t.claimed_by_agent_id) and t.status != "done"
        ),
        :count,
        :id
      )

    stall_candidates =
      Repo.aggregate(
        from(t in Task,
          where:
            not is_nil(t.claimed_by_agent_id) and
              t.status != "done" and
              t.claimed_at < ^stall_cutoff and
              is_nil(t.session_id)
        ),
        :count,
        :id
      )

    {:ok, agents} = Agents.list_hired()

    idle_count =
      agents
      |> Enum.filter(&auto_pickup_enabled?/1)
      |> Enum.count(fn a -> active_session_count(a.slug) == 0 end)

    %{
      unclaimed_tasks: unclaimed,
      claimed_tasks: claimed,
      idle_agents: idle_count,
      stall_candidates: stall_candidates
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp resolve_all_active_missions do
    active_mission_ids =
      Repo.all(
        from(m in Mission,
          where: m.status == "active",
          select: m.id
        )
      )

    Enum.flat_map(active_mission_ids, &resolve_dependencies/1)
  end

  @spec attempt_claim_and_dispatch(Agent.t(), Task.t()) :: :dispatched | :failed
  defp attempt_claim_and_dispatch(%Agent{} = agent, %Task{} = task) do
    case Kanban.claim_task(task.short_id, agent.slug) do
      {:ok, claimed} ->
        case Dispatcher.dispatch(claimed) do
          {:ok, %{session_id: sid}} ->
            Logger.info(
              "[Orchestrator] dispatched agent=#{agent.slug} task=#{task.short_id} session=#{sid}"
            )

            :dispatched

          {:error, reason} ->
            Logger.warning(
              "[Orchestrator] dispatch failed task=#{task.short_id} reason=#{inspect(reason)} — releasing"
            )

            _ = Kanban.release_task(task.short_id)
            :failed
        end

      {:error, reason} when reason in [:already_claimed, :not_found] ->
        :failed
    end
  end

  @spec deps_completed?(Milestone.t()) :: boolean()
  defp deps_completed?(%Milestone{depends_on_ids: []}), do: true

  defp deps_completed?(%Milestone{depends_on_ids: dep_ids}) do
    count =
      Repo.aggregate(
        from(m in Milestone,
          where: m.id in ^dep_ids and m.status == "completed"
        ),
        :count,
        :id
      )

    count == length(dep_ids)
  end

  @spec auto_pickup_enabled?(Agent.t()) :: boolean()
  defp auto_pickup_enabled?(%Agent{config: cfg}) when is_map(cfg),
    do: Map.get(cfg, "auto_pickup") in [true, "true"]

  defp auto_pickup_enabled?(_), do: false

  @spec agent_skills(Agent.t()) :: [String.t()]
  defp agent_skills(%Agent{config: cfg}) when is_map(cfg) do
    case Map.get(cfg, "capabilities") do
      list when is_list(list) -> Enum.filter(list, &is_binary/1)
      _ -> []
    end
  end

  defp agent_skills(_), do: []

  @spec active_session_count(String.t()) :: non_neg_integer()
  defp active_session_count(agent_slug) do
    alias Canopy.Sessions.Session

    Repo.aggregate(
      from(s in Session,
        where: s.agent_slug == ^agent_slug and s.status in ["pending", "running"]
      ),
      :count,
      :id
    )
  end

  @spec current_retry_count(Task.t()) :: non_neg_integer()
  defp current_retry_count(%Task{labels: labels}) do
    labels
    |> Enum.find_value(0, fn label ->
      if String.starts_with?(label, "retry:") do
        case Integer.parse(String.trim_leading(label, "retry:")) do
          {n, ""} -> n
          _ -> nil
        end
      else
        nil
      end
    end)
  end

  @spec update_retry_label([String.t()], non_neg_integer()) :: [String.t()]
  defp update_retry_label(labels, count) do
    labels
    |> Enum.reject(&String.starts_with?(&1, "retry:"))
    |> then(&["retry:#{count}" | &1])
  end
end
