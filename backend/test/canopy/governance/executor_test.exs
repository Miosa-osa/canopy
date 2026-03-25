defmodule Canopy.Governance.ExecutorTest do
  use Canopy.DataCase

  import Canopy.TestHelpers

  alias Canopy.Governance.Executor
  alias Canopy.Schemas.Approval

  describe "execute/1" do
    test "rejects non-approved approvals" do
      user = insert_user()
      workspace = insert_workspace(user)

      approval = insert_approval(workspace, %{status: "pending"})
      assert {:error, {:not_approved, "pending"}} = Executor.execute(approval)
    end

    test "executes delete_agent action for approved approval" do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace, %{status: "idle"})

      approval =
        insert_approval(workspace, %{
          status: "approved",
          context: %{"gate_type" => "delete_agent", "entity_id" => agent.id}
        })

      assert {:ok, _} = Executor.execute(approval)

      # Agent should be terminated
      updated = Repo.get!(Canopy.Schemas.Agent, agent.id)
      assert updated.status == "terminated"
    end

    test "executes budget_override action for approved approval" do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)

      policy = insert_budget_policy("agent", agent.id)

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, incident} =
        %Canopy.Schemas.BudgetIncident{}
        |> Canopy.Schemas.BudgetIncident.changeset(%{
          policy_id: policy.id,
          incident_type: "hard_stop",
          threshold_pct: 100,
          actual_pct: 120,
          scope_type: "agent",
          scope_id: agent.id,
          inserted_at: now
        })
        |> Ecto.Changeset.put_change(:inserted_at, now)
        |> Repo.insert()

      approval =
        insert_approval(workspace, %{
          status: "approved",
          context: %{"gate_type" => "budget_override", "entity_id" => incident.id}
        })

      assert {:ok, _} = Executor.execute(approval)

      # Incident should be resolved
      updated = Repo.get!(Canopy.Schemas.BudgetIncident, incident.id)
      assert updated.resolved == true
      assert updated.resolved_at != nil
    end

    test "returns error for unknown gate type" do
      user = insert_user()
      workspace = insert_workspace(user)

      approval =
        insert_approval(workspace, %{
          status: "approved",
          context: %{"gate_type" => "unknown_gate"}
        })

      assert {:error, :unknown_gate_type} = Executor.execute(approval)
    end

    test "strategy gate returns no_auto_execution" do
      user = insert_user()
      workspace = insert_workspace(user)

      approval =
        insert_approval(workspace, %{
          status: "approved",
          context: %{"gate_type" => "strategy"}
        })

      assert {:ok, :no_auto_execution} = Executor.execute(approval)
    end
  end
end
