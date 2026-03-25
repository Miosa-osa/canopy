defmodule Canopy.Governance.GateTest do
  use Canopy.DataCase

  import Canopy.TestHelpers

  alias Canopy.Governance.Gate

  setup do
    Application.put_env(:canopy, :governance_gates, %{})
    on_exit(fn -> Application.delete_env(:canopy, :governance_gates) end)
    :ok
  end

  describe "check/2" do
    test "returns :allowed when gates are disabled" do
      assert Gate.check(:spawn_agent, %{workspace_id: Ecto.UUID.generate()}) == :allowed
    end

    test "returns :allowed when specific gate is not enabled" do
      Application.put_env(:canopy, :governance_gates, %{delete_agent: true})

      assert Gate.check(:spawn_agent, %{workspace_id: Ecto.UUID.generate()}) == :allowed
    end

    test "returns {:requires_approval, _} when gate is enabled" do
      Application.put_env(:canopy, :governance_gates, %{spawn_agent: true})
      user = insert_user()
      workspace = insert_workspace(user)

      result = Gate.check(:spawn_agent, %{workspace_id: workspace.id})

      assert {:requires_approval, approval} = result
      assert approval.status == "pending"
      assert approval.title =~ "spawn agent"
    end

    test "creates approval record in database when gate triggered" do
      Application.put_env(:canopy, :governance_gates, %{delete_agent: true})
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)

      {:requires_approval, approval} =
        Gate.check(:delete_agent, %{
          workspace_id: workspace.id,
          entity_id: agent.id,
          entity_name: agent.name
        })

      # Verify it's persisted
      db_approval = Repo.get!(Canopy.Schemas.Approval, approval.id)
      assert db_approval.status == "pending"
      assert db_approval.context["gate_type"] == "delete_agent"
      assert db_approval.context["entity_id"] == agent.id
    end

    test "reuses existing pending approval for same gate/entity" do
      Application.put_env(:canopy, :governance_gates, %{spawn_agent: true})
      user = insert_user()
      workspace = insert_workspace(user)

      context = %{workspace_id: workspace.id, entity_id: "test-agent-id"}

      {:requires_approval, first} = Gate.check(:spawn_agent, context)
      {:requires_approval, second} = Gate.check(:spawn_agent, context)

      # Should return the same approval (deduplication)
      assert first.id == second.id
    end
  end

  describe "agent_blocked?/1" do
    test "returns false when agent has no pending approvals" do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)

      refute Gate.agent_blocked?(agent.id)
    end

    test "returns true when agent has pending approvals" do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)

      insert_approval(workspace, %{
        requested_by: agent.id,
        status: "pending"
      })

      assert Gate.agent_blocked?(agent.id)
    end

    test "returns false when all approvals are resolved" do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)

      insert_approval(workspace, %{
        requested_by: agent.id,
        status: "approved"
      })

      refute Gate.agent_blocked?(agent.id)
    end
  end

  describe "agent_paused?/1" do
    test "returns false for idle agent" do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace, %{status: "idle"})

      refute Gate.agent_paused?(agent.id)
    end

    test "returns true for paused agent" do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace, %{status: "paused"})

      assert Gate.agent_paused?(agent.id)
    end

    test "returns false for non-existent agent" do
      refute Gate.agent_paused?(Ecto.UUID.generate())
    end
  end
end
