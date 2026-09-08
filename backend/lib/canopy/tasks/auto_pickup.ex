defmodule Canopy.Tasks.AutoPickup do
  @moduledoc """
  Oban worker that drives the agent-kanban auto-pickup loop.

  Every tick (registered via `Oban.Plugins.Cron`, default `* * * * *`),
  this worker walks the set of hired agents that have `config["auto_pickup"]`
  enabled, and for each one:

    1. Resolves the agent's capabilities (`config["capabilities"]`).
    2. Asks `Tasks.Kanban.next_unclaimed/2` for the highest-priority task
       whose `required_skills` are a subset of those capabilities.
    3. Runs `AutoPickup.Dispatch.should_pickup?/3` for the final go/no-go.
    4. On `:pickup` — atomically claims via `Tasks.Kanban.claim_task/2`,
       then hands the task to `Tasks.Dispatcher.dispatch/1` to spawn the
       session. On dispatcher failure, releases the claim back to Backlog.

  The claim is the load-bearing piece — `claim_task/2` uses
  `SELECT … FOR UPDATE SKIP LOCKED` so two ticks running on top of each
  other (or two nodes in a cluster) cannot double-pick the same task.

  ## Cron registration

  This module is referenced from `config/config.exs` via:

      {"* * * * *", Canopy.Tasks.AutoPickup}

  ## Logging

  Every pickup decision is logged. Successful pickups log at `:info`;
  skips and dispatch errors log at `:debug` to keep the noise floor low.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  alias Canopy.Agents
  alias Canopy.Agents.Agent
  alias Canopy.Repo
  alias Canopy.Sessions.Session
  alias Canopy.Tasks.AutoPickup.Dispatch
  alias Canopy.Tasks.Dispatcher
  alias Canopy.Tasks.Kanban
  alias Canopy.Tasks.Task

  import Ecto.Query, only: [from: 2]

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    {picked, skipped} = run_tick()
    Logger.info("[Tasks.AutoPickup] tick complete picked=#{picked} skipped=#{skipped}")
    {:ok, %{picked: picked, skipped: skipped}}
  end

  @doc """
  Runs a single tick of the loop. Exposed for tests and manual invocation.

  Returns `{picked_count, skipped_count}`.
  """
  @spec run_tick() :: {non_neg_integer(), non_neg_integer()}
  def run_tick do
    {:ok, agents} = Agents.list_hired()

    Enum.reduce(agents, {0, 0}, fn agent, {picked, skipped} ->
      case try_pickup_for_agent(agent) do
        :picked -> {picked + 1, skipped}
        :skipped -> {picked, skipped + 1}
      end
    end)
  end

  @doc """
  Attempts a single pickup for `agent`. Returns `:picked` on success,
  `:skipped` otherwise. Side effects: DB writes, dispatcher invocation,
  log lines.
  """
  @spec try_pickup_for_agent(Agent.t()) :: :picked | :skipped
  def try_pickup_for_agent(%Agent{} = agent) do
    skills = capabilities(agent)
    candidate = Kanban.next_unclaimed(skills)

    case candidate do
      nil ->
        :skipped

      %Task{} = task ->
        ctx = %{active_session_count: active_session_count(agent.slug)}

        case Dispatch.should_pickup?(agent, task, ctx) do
          :pickup ->
            attempt_claim_and_dispatch(agent, task)

          {:skip, reason} ->
            Logger.debug(
              "[Tasks.AutoPickup] skip agent=#{agent.slug} task=#{task.short_id} reason=#{reason}"
            )

            :skipped
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Internals
  # ---------------------------------------------------------------------------

  defp attempt_claim_and_dispatch(%Agent{} = agent, %Task{} = task) do
    case Kanban.claim_task(task.short_id, agent.slug) do
      {:ok, claimed} ->
        case Dispatcher.dispatch(claimed) do
          {:ok, %{session_id: sid}} ->
            Logger.info(
              "[Tasks.AutoPickup] pickup agent=#{agent.slug} task=#{task.short_id} session=#{sid}"
            )

            :picked

          {:error, reason} ->
            Logger.warning(
              "[Tasks.AutoPickup] dispatch failed — releasing task=#{task.short_id} reason=#{inspect(reason)}"
            )

            _ = Kanban.release_task(task.short_id)
            :skipped
        end

      {:error, :already_claimed} ->
        Logger.debug("[Tasks.AutoPickup] race lost — task=#{task.short_id} already claimed")

        :skipped

      {:error, :not_found} ->
        :skipped
    end
  end

  @spec capabilities(Agent.t()) :: [String.t()]
  defp capabilities(%Agent{config: config}) when is_map(config) do
    case Map.get(config, "capabilities") do
      list when is_list(list) -> Enum.filter(list, &is_binary/1)
      _ -> []
    end
  end

  defp capabilities(_), do: []

  @spec active_session_count(String.t()) :: non_neg_integer()
  defp active_session_count(agent_slug) do
    Repo.aggregate(
      from(s in Session,
        where: s.agent_slug == ^agent_slug and s.status in ["pending", "running"]
      ),
      :count,
      :id
    )
  end
end
