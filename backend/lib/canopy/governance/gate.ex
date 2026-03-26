defmodule Canopy.Governance.Gate do
  @moduledoc """
  Runtime enforcement gates for governance policies.

  Checks whether an action requires approval before proceeding.
  If approval is required, creates an approval record atomically (via
  Ecto.Multi) and returns `{:pending_approval, approval}`.

  Returns:
    - `:allowed`                        — proceed normally
    - `{:pending_approval, approval}`   — blocked; approval record created
    - `{:denied, reason}`               — explicitly denied (e.g. already rejected)

  This module is pure function calls — no GenServer, no process state.
  """

  require Logger

  alias Canopy.Repo
  alias Canopy.Schemas.Approval
  alias Canopy.Governance.Policy
  import Ecto.Query, only: [from: 2]

  @doc """
  Gate an action. `action_type` is an atom like `:spawn_agent`.

  Params:
    - `:workspace_id`   — required for policy lookup and approval scoping
    - `:requester_id`   — agent or user ID requesting the action
    - `:requester_role` — role string for auto-approve bypass
    - any other keys are stored as `action_params` for replay

  Options:
    - `:auto_execute` — boolean, default false; if true, approved action
      will be replayed automatically by Executor

  Returns `:allowed` or `{:pending_approval, %Approval{}}` or `{:denied, reason}`.
  """
  def check(action_type, params, opts \\ [])

  # Agent hiring / spawning
  def check(:spawn_agent, params, opts) do
    workspace_id = params[:workspace_id] || params["workspace_id"]
    requester_id = params[:requester_id] || params["requester_id"]
    requester_role = params[:requester_role] || params["requester_role"]

    policy = Policy.for_workspace(workspace_id)

    cond do
      not Policy.requires_approval?(policy, :spawn_agent) ->
        :allowed

      Policy.auto_approved?(policy, :spawn_agent, requester_role) ->
        :allowed

      true ->
        agent_name = params[:name] || params["name"] || "new agent"

        create_approval_gate(%{
          title: "Approve spawning agent: #{agent_name}",
          description: "An agent spawn was requested and requires approval before execution.",
          action_type: "spawn_agent",
          action_params: sanitize_params(params),
          workspace_id: workspace_id,
          requested_by: requester_id,
          auto_execute: opts[:auto_execute] || false
        })
    end
  end

  # Delete agent — destructive, always requires approval
  def check(:delete_agent, params, opts) do
    workspace_id = params[:workspace_id] || params["workspace_id"]
    requester_id = params[:requester_id] || params["requester_id"]
    requester_role = params[:requester_role] || params["requester_role"]
    agent_id = params[:agent_id] || params["agent_id"] || params[:id] || params["id"]

    policy = Policy.for_workspace(workspace_id)

    cond do
      not Policy.requires_approval?(policy, :delete_agent) ->
        :allowed

      Policy.auto_approved?(policy, :delete_agent, requester_role) ->
        :allowed

      true ->
        create_approval_gate(%{
          title: "Approve deletion of agent #{agent_id}",
          description: "A destructive operation (agent deletion) requires board approval.",
          action_type: "delete_agent",
          action_params: sanitize_params(params),
          workspace_id: workspace_id,
          requested_by: requester_id,
          auto_execute: opts[:auto_execute] || false
        })
    end
  end

  # Budget override — requires approval when over threshold
  def check(:budget_override, params, opts) do
    workspace_id = params[:workspace_id] || params["workspace_id"]
    requester_id = params[:requester_id] || params["requester_id"]
    amount_cents = params[:amount_cents] || params["amount_cents"] || 0

    create_approval_gate(%{
      title: "Budget override: #{amount_cents}¢ requested",
      description: "A budget override exceeding policy thresholds requires approval.",
      action_type: "budget_override",
      action_params: sanitize_params(params),
      workspace_id: workspace_id,
      requested_by: requester_id,
      auto_execute: opts[:auto_execute] || false
    })
  end

  # Strategy proposal — always requires board review
  def check(:strategy_proposal, params, opts) do
    workspace_id = params[:workspace_id] || params["workspace_id"]
    requester_id = params[:requester_id] || params["requester_id"]
    title = params[:title] || params["title"] || "Strategy Proposal"

    create_approval_gate(%{
      title: "Strategy review: #{title}",
      description: "Strategic proposals require board review before implementation.",
      action_type: "strategy_proposal",
      action_params: sanitize_params(params),
      workspace_id: workspace_id,
      requested_by: requester_id,
      auto_execute: opts[:auto_execute] || false
    })
  end

  # Default — all other actions are allowed
  def check(_action_type, _params, _opts), do: :allowed

  @doc "Returns true if the given approval_id is in approved status."
  def approved?(approval_id) do
    case Repo.get(Approval, approval_id) do
      %Approval{status: "approved"} -> true
      _ -> false
    end
  end

  @doc """
  Check if an agent has any pending approvals that should block heartbeat execution.
  Returns `{:blocked, [approval_ids]}` or `:clear`.
  """
  def heartbeat_blocked?(agent_id) do
    pending_ids =
      Repo.all(
        from a in Approval,
          where: a.requested_by == ^agent_id and a.status == "pending",
          select: a.id
      )

    case pending_ids do
      [] -> :clear
      ids -> {:blocked, ids}
    end
  end

  # --- Private ---

  # Insert the approval record. Returns `{:pending_approval, %Approval{}}` on
  # success. If an identical pending approval already exists for this
  # (workspace_id, action_type), reuses the existing one rather than
  # duplicating — idempotent gate creation.
  defp create_approval_gate(attrs) do
    existing = find_pending_duplicate(attrs.workspace_id, attrs.action_type)

    approval =
      if existing do
        existing
      else
        case insert_approval(attrs) do
          {:ok, approval} ->
            approval

          {:error, reason} ->
            Logger.error("[Governance.Gate] Failed to create approval: #{inspect(reason)}")
            nil
        end
      end

    if approval do
      {:pending_approval, approval}
    else
      # Fallback: if we can't create the approval record, block the action
      # to avoid silently bypassing governance when the DB is unhealthy.
      {:denied, "governance_error"}
    end
  end

  defp find_pending_duplicate(workspace_id, action_type)
       when is_binary(workspace_id) and is_binary(action_type) do
    Repo.one(
      from a in Approval,
        where:
          a.workspace_id == ^workspace_id and
            a.action_type == ^action_type and
            a.status == "pending",
        order_by: [desc: a.inserted_at],
        limit: 1
    )
  end

  defp find_pending_duplicate(_workspace_id, _action_type), do: nil

  defp insert_approval(attrs) do
    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:approval, fn _ ->
        Approval.governance_changeset(%Approval{}, attrs)
      end)

    case Repo.transaction(multi) do
      {:ok, %{approval: approval}} -> {:ok, approval}
      {:error, :approval, changeset, _} -> {:error, changeset}
    end
  end

  # Strip any keys that shouldn't be stored in the DB (e.g. large binaries,
  # internal opts). Converts atom keys to strings for JSON storage.
  defp sanitize_params(params) when is_map(params) do
    params
    |> Enum.reject(fn {_k, v} -> is_function(v) or is_pid(v) or is_reference(v) end)
    |> Enum.map(fn {k, v} -> {to_string(k), v} end)
    |> Map.new()
  end

  defp sanitize_params(_), do: %{}

  @doc """
  Check if an agent has pending approvals that should block execution.
  Returns true if the agent should be blocked.
  """
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
  def agent_paused?(agent_id) do
    case Repo.get(Canopy.Schemas.Agent, agent_id) do
      %{status: "paused"} -> true
      _ -> false
    end
  end
end
