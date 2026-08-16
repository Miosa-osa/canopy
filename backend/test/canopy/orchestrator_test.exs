defmodule Canopy.OrchestratorTest do
  @moduledoc "Unit tests for the Orchestrator."

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Missions.Milestone
  alias Canopy.Missions
  alias Canopy.Orchestrator
  alias Canopy.Repo
  alias Canopy.Tasks.Task

  # ---------------------------------------------------------------------------
  # check_stalls/0
  # ---------------------------------------------------------------------------

  describe "check_stalls/0" do
    test "detects tasks claimed > 10 minutes ago with no session and releases them" do
      # Insert a task directly so we can backdate claimed_at
      stale_claimed_at =
        DateTime.utc_now()
        |> DateTime.add(-12 * 60, :second)
        |> DateTime.truncate(:microsecond)

      task =
        Repo.insert!(%Task{
          short_id: "T-STALL001",
          title: "Stalled task",
          status: "todo",
          claimed_by_agent_id: "test-agent",
          claimed_at: stale_claimed_at,
          labels: []
        })

      count = Orchestrator.check_stalls()

      assert count >= 1

      # Verify the task was released
      {:ok, released} = Canopy.Tasks.get(task.short_id)
      assert is_nil(released.claimed_by_agent_id)
    end

    test "does not release tasks claimed recently" do
      recent_claimed_at =
        DateTime.utc_now()
        |> DateTime.add(-1 * 60, :second)
        |> DateTime.truncate(:microsecond)

      Repo.insert!(%Task{
        short_id: "T-FRESH001",
        title: "Fresh claim",
        status: "todo",
        claimed_by_agent_id: "test-agent",
        claimed_at: recent_claimed_at,
        labels: []
      })

      stall_count_before = Orchestrator.check_stalls()

      {:ok, task} = Canopy.Tasks.get("T-FRESH001")
      # Still claimed — not stalled
      assert task.claimed_by_agent_id == "test-agent"
      _ = stall_count_before
    end

    test "does not release stalled tasks that have a session_id" do
      stale_claimed_at =
        DateTime.utc_now()
        |> DateTime.add(-15 * 60, :second)
        |> DateTime.truncate(:microsecond)

      Repo.insert!(%Task{
        short_id: "T-ACTIVE01",
        title: "Active session task",
        status: "in_progress",
        claimed_by_agent_id: "active-agent",
        claimed_at: stale_claimed_at,
        session_id: Ecto.UUID.generate(),
        labels: []
      })

      Orchestrator.check_stalls()

      {:ok, task} = Canopy.Tasks.get("T-ACTIVE01")
      # Still claimed — has a session
      assert task.claimed_by_agent_id == "active-agent"
    end
  end

  # ---------------------------------------------------------------------------
  # retry/1
  # ---------------------------------------------------------------------------

  describe "retry/1" do
    test "resets a task to todo and clears claim fields" do
      task =
        Repo.insert!(%Task{
          short_id: "T-RETRY001",
          title: "Failed task",
          status: "todo",
          claimed_by_agent_id: "agent-x",
          claimed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
          labels: []
        })

      assert {:ok, retried} = Orchestrator.retry(task.short_id)
      assert retried.status == "todo"
      assert is_nil(retried.claimed_by_agent_id)
      assert is_nil(retried.claimed_at)
    end

    test "increments retry:N label on each retry" do
      task =
        Repo.insert!(%Task{
          short_id: "T-RETRY002",
          title: "Retry label task",
          status: "todo",
          labels: []
        })

      {:ok, first} = Orchestrator.retry(task.short_id)
      assert "retry:1" in first.labels

      {:ok, second} = Orchestrator.retry(task.short_id)
      assert "retry:2" in second.labels
      refute "retry:1" in second.labels
    end

    test "returns not_found for unknown task" do
      assert {:error, :not_found} = Orchestrator.retry("T-NOTEXIST")
    end
  end

  # ---------------------------------------------------------------------------
  # resolve_dependencies/1
  # ---------------------------------------------------------------------------

  describe "resolve_dependencies/1" do
    test "activates a milestone when all its deps are completed" do
      mission = insert(:mission, status: "active")

      dep =
        Repo.insert!(%Milestone{
          mission_id: mission.id,
          title: "Dep milestone",
          status: "completed",
          order: 0,
          completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      blocked =
        Repo.insert!(%Milestone{
          mission_id: mission.id,
          title: "Blocked by dep",
          status: "blocked",
          order: 1,
          depends_on_ids: [dep.id]
        })

      unblocked_ids = Orchestrator.resolve_dependencies(mission.id)

      assert blocked.id in unblocked_ids

      updated = Repo.get!(Milestone, blocked.id)
      assert updated.status == "active"
    end

    test "does NOT activate a milestone when deps are still pending" do
      mission = insert(:mission, status: "active")

      pending_dep =
        Repo.insert!(%Milestone{
          mission_id: mission.id,
          title: "Pending dep",
          status: "pending",
          order: 0
        })

      blocked =
        Repo.insert!(%Milestone{
          mission_id: mission.id,
          title: "Still blocked",
          status: "blocked",
          order: 1,
          depends_on_ids: [pending_dep.id]
        })

      unblocked_ids = Orchestrator.resolve_dependencies(mission.id)

      refute blocked.id in unblocked_ids
    end

    test "activates milestones with no dependencies" do
      mission = insert(:mission, status: "active")

      pending =
        Repo.insert!(%Milestone{
          mission_id: mission.id,
          title: "No deps",
          status: "pending",
          order: 0,
          depends_on_ids: []
        })

      unblocked_ids = Orchestrator.resolve_dependencies(mission.id)
      assert pending.id in unblocked_ids
    end

    test "returns empty list for unknown mission" do
      assert [] = Orchestrator.resolve_dependencies(Ecto.UUID.generate())
    end
  end

  # ---------------------------------------------------------------------------
  # status/0
  # ---------------------------------------------------------------------------

  describe "status/0" do
    test "returns map with expected keys" do
      status = Orchestrator.status()

      assert Map.has_key?(status, :unclaimed_tasks)
      assert Map.has_key?(status, :claimed_tasks)
      assert Map.has_key?(status, :idle_agents)
      assert Map.has_key?(status, :stall_candidates)
    end

    test "counts unclaimed auto-assignable tasks" do
      initial = Orchestrator.status()

      Repo.insert!(%Task{
        short_id: "T-ORCH-STATUS-#{System.unique_integer()}",
        title: "Auto task",
        status: "todo",
        auto_assignable: true,
        labels: []
      })

      updated = Orchestrator.status()
      assert updated.unclaimed_tasks >= initial.unclaimed_tasks + 1
    end
  end

  # ---------------------------------------------------------------------------
  # auto_dispatch/0
  # ---------------------------------------------------------------------------

  describe "auto_dispatch/0" do
    test "returns map with stalled and dispatched counts" do
      result = Orchestrator.auto_dispatch()

      assert is_integer(result.stalled)
      assert result.stalled >= 0
      assert is_integer(result.dispatched)
      assert result.dispatched >= 0
    end
  end

  # ---------------------------------------------------------------------------
  # Milestone dep resolution — A depends on B, B completes → A unblocks
  # ---------------------------------------------------------------------------

  describe "dependency chain integration" do
    test "completing B unblocks A which depends on B" do
      mission = insert(:mission, status: "active")

      b =
        Repo.insert!(%Milestone{
          mission_id: mission.id,
          title: "Step B",
          status: "pending",
          order: 0,
          depends_on_ids: []
        })

      a =
        Repo.insert!(%Milestone{
          mission_id: mission.id,
          title: "Step A (depends on B)",
          status: "blocked",
          order: 1,
          depends_on_ids: [b.id]
        })

      # A is still blocked before B completes
      assert [] == Orchestrator.resolve_dependencies(mission.id) |> Enum.filter(&(&1 == a.id))

      # Complete B
      {:ok, _} = Missions.advance_milestone(b.id)

      # Now A should unblock
      unblocked = Orchestrator.resolve_dependencies(mission.id)
      assert a.id in unblocked
    end
  end
end
