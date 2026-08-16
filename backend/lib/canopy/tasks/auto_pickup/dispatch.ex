defmodule Canopy.Tasks.AutoPickup.Dispatch do
  @moduledoc """
  Pure decision logic for the agent-kanban auto-pickup loop.

  Given an agent and a candidate task plus loop-time context, decides
  whether the agent should pick up the task. No side effects, no IO —
  the entire function is testable with plain structs.

  ## Decision criteria (all must pass)

  1. The agent is hired.
  2. The agent has `auto_pickup_enabled = true` in `config["auto_pickup"]`.
  3. Every task `required_skill` is present in the agent's
     `config["capabilities"]` list.
  4. The agent's monthly budget has remaining headroom (or no budget set).
  5. The agent has no currently-active session (no concurrent dispatch).

  Returns `:pickup` if all pass, `{:skip, reason}` otherwise.
  """

  alias Canopy.Agents.Agent
  alias Canopy.Tasks.Task

  @type context :: %{
          required(:active_session_count) => non_neg_integer(),
          optional(:budget_remaining_usd) => Decimal.t() | nil
        }

  @type decision :: :pickup | {:skip, atom()}

  @spec should_pickup?(Agent.t(), Task.t(), context()) :: decision()
  def should_pickup?(%Agent{} = agent, %Task{} = task, ctx) when is_map(ctx) do
    cond do
      not agent.hired ->
        {:skip, :agent_not_hired}

      not auto_pickup_enabled?(agent) ->
        {:skip, :auto_pickup_disabled}

      not skills_match?(agent, task) ->
        {:skip, :skill_mismatch}

      not budget_ok?(ctx) ->
        {:skip, :budget_exhausted}

      Map.get(ctx, :active_session_count, 0) > 0 ->
        {:skip, :agent_busy}

      not is_nil(task.claimed_by_agent_id) ->
        {:skip, :already_claimed}

      true ->
        :pickup
    end
  end

  # ---------------------------------------------------------------------------
  # Internals
  # ---------------------------------------------------------------------------

  @spec auto_pickup_enabled?(Agent.t()) :: boolean()
  defp auto_pickup_enabled?(%Agent{config: config}) when is_map(config) do
    case Map.get(config, "auto_pickup") do
      true -> true
      "true" -> true
      _ -> false
    end
  end

  defp auto_pickup_enabled?(_), do: false

  @spec skills_match?(Agent.t(), Task.t()) :: boolean()
  defp skills_match?(%Agent{} = agent, %Task{required_skills: required}) do
    required = required || []

    if required == [] do
      true
    else
      caps = capabilities(agent)
      Enum.all?(required, &(&1 in caps))
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

  # nil budget_remaining_usd or absent key → treat as unlimited.
  # Negative or zero remaining → exhausted.
  @spec budget_ok?(context()) :: boolean()
  defp budget_ok?(%{budget_remaining_usd: nil}), do: true
  defp budget_ok?(ctx) when not is_map_key(ctx, :budget_remaining_usd), do: true

  defp budget_ok?(%{budget_remaining_usd: %Decimal{} = remaining}) do
    Decimal.compare(remaining, Decimal.new("0")) == :gt
  end

  defp budget_ok?(_), do: true
end
