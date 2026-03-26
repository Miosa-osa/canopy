defmodule Canopy.BudgetEnforcerTest do
  use Canopy.DataCase

  import Canopy.TestHelpers

  alias Canopy.BudgetEnforcer

  setup do
    # Clean ETS tables between tests
    :ets.delete_all_objects(:canopy_budget_accumulator)
    :ets.delete_all_objects(:canopy_hierarchy_cache)
    :ok
  end

  describe "get_accumulated/2" do
    test "returns 0 for unknown scope" do
      assert BudgetEnforcer.get_accumulated("agent", Ecto.UUID.generate()) == 0
    end
  end

  describe "record_cost/1" do
    test "increments agent-level accumulator" do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)

      BudgetEnforcer.record_cost(%{
        agent_id: agent.id,
        model: "claude-sonnet-4-6",
        tokens_input: 1000,
        tokens_output: 500,
        tokens_cache: 0,
        cost_cents: 200
      })

      # GenServer.cast is async — give it time to process
      Process.sleep(100)

      assert BudgetEnforcer.get_accumulated("agent", agent.id) == 200
    end

    test "increments workspace-level accumulator" do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)

      BudgetEnforcer.record_cost(%{
        agent_id: agent.id,
        model: "claude-sonnet-4-6",
        tokens_input: 1000,
        tokens_output: 500,
        cost_cents: 300
      })

      Process.sleep(100)

      assert BudgetEnforcer.get_accumulated("workspace", workspace.id) == 300
    end

    test "cascades costs through hierarchy" do
      user = insert_user()
      workspace = insert_workspace(user)
      org = insert_organization()
      division = insert_division(org)
      department = insert_department(division)
      team = insert_team(department)
      agent = insert_agent(workspace)
      insert_team_membership(team, agent)

      BudgetEnforcer.record_cost(%{
        agent_id: agent.id,
        model: "claude-sonnet-4-6",
        tokens_input: 5000,
        tokens_output: 2000,
        cost_cents: 500
      })

      Process.sleep(200)

      # Cost should cascade to all levels
      assert BudgetEnforcer.get_accumulated("agent", agent.id) == 500
      assert BudgetEnforcer.get_accumulated("workspace", workspace.id) == 500
      assert BudgetEnforcer.get_accumulated("team", team.id) == 500
      assert BudgetEnforcer.get_accumulated("department", department.id) == 500
      assert BudgetEnforcer.get_accumulated("division", division.id) == 500
      assert BudgetEnforcer.get_accumulated("organization", org.id) == 500
    end

    test "accumulates multiple cost events" do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)

      for _ <- 1..5 do
        BudgetEnforcer.record_cost(%{
          agent_id: agent.id,
          model: "claude-sonnet-4-6",
          tokens_input: 100,
          tokens_output: 50,
          cost_cents: 100
        })
      end

      Process.sleep(300)

      assert BudgetEnforcer.get_accumulated("agent", agent.id) == 500
    end

    test "persists CostEvent to database" do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)

      BudgetEnforcer.record_cost(%{
        agent_id: agent.id,
        model: "claude-sonnet-4-6",
        tokens_input: 1000,
        tokens_output: 500,
        cost_cents: 150
      })

      Process.sleep(100)

      events = Repo.all(from ce in Canopy.Schemas.CostEvent, where: ce.agent_id == ^agent.id)
      assert length(events) == 1
      assert hd(events).cost_cents == 150
    end
  end

  describe "budget policy enforcement" do
    test "triggers warning incident at warning threshold" do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)

      # Set policy: $100 limit, warn at 80%
      insert_budget_policy("agent", agent.id, %{
        monthly_limit_cents: 10_000,
        warning_threshold_pct: 80,
        hard_stop: false
      })

      # Record cost that exceeds 80% ($80 of $100)
      BudgetEnforcer.record_cost(%{
        agent_id: agent.id,
        model: "claude-sonnet-4-6",
        cost_cents: 8500
      })

      Process.sleep(200)

      incidents =
        Repo.all(
          from bi in Canopy.Schemas.BudgetIncident,
            where: bi.scope_type == "agent" and bi.scope_id == ^agent.id
        )

      assert length(incidents) >= 1
      assert hd(incidents).incident_type == "warning"
    end

    test "triggers hard_stop and pauses agent at 100%" do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace, %{status: "idle"})

      # Set policy: $100 limit, hard stop at 100%
      insert_budget_policy("agent", agent.id, %{
        monthly_limit_cents: 10_000,
        warning_threshold_pct: 80,
        hard_stop: true
      })

      # Record cost that exceeds 100%
      BudgetEnforcer.record_cost(%{
        agent_id: agent.id,
        model: "claude-sonnet-4-6",
        cost_cents: 11_000
      })

      Process.sleep(300)

      # Agent should be paused
      updated_agent = Repo.get!(Canopy.Schemas.Agent, agent.id)
      assert updated_agent.status == "paused"

      # Hard stop incident should exist
      incidents =
        Repo.all(
          from bi in Canopy.Schemas.BudgetIncident,
            where: bi.scope_type == "agent" and bi.scope_id == ^agent.id and bi.incident_type == "hard_stop"
        )

      assert length(incidents) == 1
    end

    test "deduplicates incidents for same policy/scope" do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)

      insert_budget_policy("agent", agent.id, %{
        monthly_limit_cents: 10_000,
        warning_threshold_pct: 80,
        hard_stop: true
      })

      # Record two costs that both exceed threshold
      for _ <- 1..2 do
        BudgetEnforcer.record_cost(%{
          agent_id: agent.id,
          model: "claude-sonnet-4-6",
          cost_cents: 6000
        })
      end

      Process.sleep(300)

      incidents =
        Repo.all(
          from bi in Canopy.Schemas.BudgetIncident,
            where: bi.scope_type == "agent" and bi.scope_id == ^agent.id and bi.incident_type == "hard_stop"
        )

      # Should have exactly 1 hard_stop (deduplication)
      assert length(incidents) == 1
    end

    test "team-level hard stop pauses all team agents" do
      user = insert_user()
      workspace = insert_workspace(user)
      org = insert_organization()
      division = insert_division(org)
      department = insert_department(division)
      team = insert_team(department)

      agent1 = insert_agent(workspace, %{status: "idle"})
      agent2 = insert_agent(workspace, %{status: "idle"})
      insert_team_membership(team, agent1)
      insert_team_membership(team, agent2)

      # Set team budget policy
      insert_budget_policy("team", team.id, %{
        monthly_limit_cents: 5000,
        hard_stop: true
      })

      # Record cost via agent1 that exceeds team budget
      BudgetEnforcer.record_cost(%{
        agent_id: agent1.id,
        model: "claude-sonnet-4-6",
        cost_cents: 6000
      })

      Process.sleep(300)

      # Both agents should be paused
      assert Repo.get!(Canopy.Schemas.Agent, agent1.id).status == "paused"
      assert Repo.get!(Canopy.Schemas.Agent, agent2.id).status == "paused"
    end
  end

  describe "reset/2" do
    test "resets accumulator to zero" do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)

      BudgetEnforcer.record_cost(%{
        agent_id: agent.id,
        model: "claude-sonnet-4-6",
        cost_cents: 500
      })

      Process.sleep(100)
      assert BudgetEnforcer.get_accumulated("agent", agent.id) == 500

      BudgetEnforcer.reset("agent", agent.id)
      Process.sleep(100)

      assert BudgetEnforcer.get_accumulated("agent", agent.id) == 0
    end
  end

  describe "invalidate_hierarchy/1" do
    test "clears cached hierarchy for agent" do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)

      # Record a cost to populate the hierarchy cache
      BudgetEnforcer.record_cost(%{
        agent_id: agent.id,
        model: "claude-sonnet-4-6",
        cost_cents: 100
      })

      Process.sleep(100)

      # Cache should have an entry
      assert :ets.lookup(:canopy_hierarchy_cache, agent.id) != []

      # Invalidate
      BudgetEnforcer.invalidate_hierarchy(agent.id)

      # Cache should be empty for this agent
      assert :ets.lookup(:canopy_hierarchy_cache, agent.id) == []
    end
  end
end
