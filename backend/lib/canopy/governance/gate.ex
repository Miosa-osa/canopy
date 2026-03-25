defmodule Canopy.Governance.Gate do
  @moduledoc """
  Governance gate checks for critical actions.

  Checks whether an action requires approval based on the workspace's governance
  configuration. Returns `:allowed` or `{:requires_approval, reason}`.

  Gate types:
    - :spawn_agent     — creating/spawning new agents
    - :delete_agent    — terminating/deleting agents
    - :budget_override — resolving budget incidents or modifying policies
    - :strategy        — modifying goals, decomposing strategies
  """
  alias Canopy.Repo
  alias Canopy.Schemas.Approval
  import Ecto.Query

  @type gate_type :: :spawn_agent | :delete_agent | :budget_override | :strategy
  @type gate_result :: :allowed | {:requires_approval, map()}

  @doc """
  Check whether an action is allowed or requires approval.

  Returns `:allowed` if the action can proceed, or
  `{:requires_approval, approval}` with the created approval record
  if the action needs human review.
  """
  @spec check(gate_type(), map()) :: gate_result()
  def check(gate_type, context) do
    workspace_id = context[:workspace_id]

    if governance_enabled?(workspace_id, gate_type) do
      # Check for existing pending approval for this exact action
      existing = find_pending_approval(gate_type, context)

      if existing do
        {:requires_approval, existing}
      else
        # Create new approval request
        approval = create_approval(gate_type, context)
        {:requires_approval, approval}
      end
    else
      :allowed
    end
  end

  @doc """
  Check if an agent has pending approvals that should block execution.
  Returns true if the agent should be blocked.
  """
  @spec agent_blocked?(binary()) :: boolean()
  def agent_blocked?(agent_id) do
    count =
      Repo.aggregate(
        from(a in Approval,
          where: a.requested_by == ^agent_id and a.status == "pending"
        ),
        :count
      )

    count > 0
  end

  @doc """
  Check if an agent is paused (budget enforcement or manual).
  """
  @spec agent_paused?(binary()) :: boolean()
  def agent_paused?(agent_id) do
    case Repo.get(Canopy.Schemas.Agent, agent_id) do
      %{status: "paused"} -> true
      _ -> false
    end
  end

  # Check governance config from Application env.
  # Governance gates can be configured via:
  #   Application.put_env(:canopy, :governance_gates, %{spawn_agent: true, delete_agent: true, ...})
  # or per-workspace via a config_revisions entry (future).
  defp governance_enabled?(_workspace_id, gate_type) do
    gates = Application.get_env(:canopy, :governance_gates, %{})
    Map.get(gates, gate_type, false) == true
  end

  defp find_pending_approval(gate_type, context) do
    gate_key = Atom.to_string(gate_type)

    query =
      from a in Approval,
        where: a.status == "pending",
        order_by: [desc: a.inserted_at],
        limit: 1

    query =
      if context[:workspace_id] do
        where(query, [a], a.workspace_id == ^context[:workspace_id])
      else
        query
      end

    # Match by gate type stored in context map
    case Repo.all(query) do
      [approval | _] ->
        if approval.context["gate_type"] == gate_key and
             approval.context["entity_id"] == context[:entity_id] do
          approval
        else
          nil
        end

      [] ->
        nil
    end
  end

  defp create_approval(gate_type, context) do
    gate_key = Atom.to_string(gate_type)

    title =
      case gate_type do
        :spawn_agent -> "Approval required: spawn agent"
        :delete_agent -> "Approval required: delete agent #{context[:entity_name] || context[:entity_id]}"
        :budget_override -> "Approval required: budget override"
        :strategy -> "Approval required: strategy change"
      end

    attrs = %{
      title: title,
      description: "Action requires governance approval before proceeding.",
      status: "pending",
      context: %{
        "gate_type" => gate_key,
        "entity_id" => context[:entity_id],
        "entity_name" => context[:entity_name],
        "action" => context[:action],
        "params" => context[:params]
      },
      requested_by: context[:agent_id],
      workspace_id: context[:workspace_id]
    }

    case %Approval{} |> Approval.changeset(attrs) |> Repo.insert() do
      {:ok, approval} ->
        # Notify via EventBus
        if context[:workspace_id] do
          Canopy.EventBus.broadcast(
            Canopy.EventBus.notifications_topic(context[:workspace_id]),
            %{event: "approval.required", data: %{approval_id: approval.id, gate_type: gate_key}}
          )
        end

        approval

      {:error, _changeset} ->
        # Fallback: return a minimal map so caller can still respond 202
        %{id: nil, title: title, status: "pending"}
    end
  end
end
