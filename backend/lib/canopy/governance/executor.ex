defmodule Canopy.Governance.Executor do
  @moduledoc """
  Replays approved governance actions.

  When an approval transitions from "pending" to "approved", the Executor
  can automatically execute the originally-requested action (spawn, delete,
  budget override, etc.) based on the approval's stored context.
  """
  require Logger

  alias Canopy.Repo
  alias Canopy.Schemas.{Agent, Approval}

  @doc """
  Execute the action associated with an approved approval record.
  Returns `{:ok, result}` or `{:error, reason}`.
  """
  def execute(%Approval{status: "approved", context: context} = approval) when is_map(context) do
    gate_type = context["gate_type"]

    Logger.info("[Governance.Executor] Replaying approved action: #{gate_type} (approval #{approval.id})")

    case gate_type do
      "spawn_agent" ->
        execute_spawn(context)

      "delete_agent" ->
        execute_delete(context)

      "budget_override" ->
        execute_budget_override(context)

      "strategy" ->
        {:ok, :no_auto_execution}

      _ ->
        Logger.warning("[Governance.Executor] Unknown gate type: #{gate_type}")
        {:error, :unknown_gate_type}
    end
  end

  def execute(%Approval{status: status}) do
    {:error, {:not_approved, status}}
  end

  def execute(_), do: {:error, :invalid_approval}

  # Replay a spawn action
  defp execute_spawn(%{"entity_id" => agent_id}) when is_binary(agent_id) do
    case Repo.get(Agent, agent_id) do
      %Agent{} = agent ->
        Task.Supervisor.start_child(Canopy.HeartbeatRunner, fn ->
          Canopy.Heartbeat.run(agent.id)
        end)

        {:ok, :spawned}

      nil ->
        {:error, :agent_not_found}
    end
  end

  defp execute_spawn(_), do: {:error, :missing_agent_id}

  # Replay a delete action
  defp execute_delete(%{"entity_id" => agent_id}) when is_binary(agent_id) do
    case Repo.get(Agent, agent_id) do
      %Agent{} = agent ->
        agent
        |> Ecto.Changeset.change(status: "terminated")
        |> Repo.update()

      nil ->
        {:error, :agent_not_found}
    end
  end

  defp execute_delete(_), do: {:error, :missing_agent_id}

  # Replay a budget override (resolve the incident)
  defp execute_budget_override(%{"entity_id" => incident_id}) when is_binary(incident_id) do
    case Repo.get(Canopy.Schemas.BudgetIncident, incident_id) do
      nil ->
        {:error, :incident_not_found}

      incident ->
        incident
        |> Ecto.Changeset.change(
          resolved: true,
          resolved_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )
        |> Repo.update()
    end
  end

  defp execute_budget_override(_), do: {:error, :missing_incident_id}
end
