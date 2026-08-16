defmodule Canopy.MissionsTest do
  @moduledoc "Unit tests for the Missions context."

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Missions
  alias Canopy.Missions.Milestone
  alias Canopy.Repo

  # ---------------------------------------------------------------------------
  # create_mission/1
  # ---------------------------------------------------------------------------

  describe "create_mission/1" do
    test "inserts a mission with required fields" do
      assert {:ok, mission} =
               Missions.create_mission(%{
                 title: "Launch v2",
                 workspace_slug: "my-workspace"
               })

      assert mission.title == "Launch v2"
      assert mission.workspace_slug == "my-workspace"
      assert mission.status == "planning"
      assert mission.priority == 3
      assert mission.id != nil
    end

    test "sets optional fields" do
      assert {:ok, mission} =
               Missions.create_mission(%{
                 title: "Ship feature",
                 workspace_slug: "ws",
                 description: "The big one",
                 status: "active",
                 priority: 1,
                 created_by_agent_slug: "backend-engineer"
               })

      assert mission.description == "The big one"
      assert mission.status == "active"
      assert mission.priority == 1
      assert mission.created_by_agent_slug == "backend-engineer"
    end

    test "rejects missing title" do
      assert {:error, changeset} = Missions.create_mission(%{workspace_slug: "ws"})
      assert changeset.errors[:title]
    end

    test "rejects missing workspace_slug" do
      assert {:error, changeset} = Missions.create_mission(%{title: "T"})
      assert changeset.errors[:workspace_slug]
    end

    test "rejects invalid status" do
      assert {:error, changeset} =
               Missions.create_mission(%{
                 title: "T",
                 workspace_slug: "ws",
                 status: "not-a-status"
               })

      assert changeset.errors[:status]
    end

    test "rejects priority out of range" do
      assert {:error, changeset} =
               Missions.create_mission(%{
                 title: "T",
                 workspace_slug: "ws",
                 priority: 99
               })

      assert changeset.errors[:priority]
    end
  end

  # ---------------------------------------------------------------------------
  # list_missions/1
  # ---------------------------------------------------------------------------

  describe "list_missions/1" do
    test "returns all missions in descending updated_at order" do
      ws = "list-ws-#{System.unique_integer()}"
      insert(:mission, workspace_slug: ws, title: "A")
      insert(:mission, workspace_slug: ws, title: "B")

      missions = Missions.list_missions(%{workspace_slug: ws})
      assert length(missions) == 2
    end

    test "filters by workspace_slug" do
      ws = "filter-ws-#{System.unique_integer()}"
      insert(:mission, workspace_slug: ws)
      insert(:mission, workspace_slug: "other-ws-#{System.unique_integer()}")

      missions = Missions.list_missions(%{workspace_slug: ws})
      assert Enum.all?(missions, &(&1.workspace_slug == ws))
    end

    test "filters by status" do
      ws = "status-ws-#{System.unique_integer()}"
      insert(:mission, workspace_slug: ws, status: "active")
      insert(:mission, workspace_slug: ws, status: "planning")

      missions = Missions.list_missions(%{workspace_slug: ws, status: "active"})
      assert Enum.all?(missions, &(&1.status == "active"))
    end
  end

  # ---------------------------------------------------------------------------
  # get_mission/1
  # ---------------------------------------------------------------------------

  describe "get_mission/1" do
    test "returns mission with preloaded milestones" do
      mission = insert(:mission)

      Repo.insert!(%Milestone{
        mission_id: mission.id,
        title: "Step 1",
        order: 0
      })

      {:ok, fetched} = Missions.get_mission(mission.id)
      assert fetched.id == mission.id
      assert length(fetched.milestones) == 1
      assert hd(fetched.milestones).title == "Step 1"
    end

    test "returns not_found for unknown id" do
      assert {:error, :not_found} = Missions.get_mission(Ecto.UUID.generate())
    end
  end

  # ---------------------------------------------------------------------------
  # add_milestone/2
  # ---------------------------------------------------------------------------

  describe "add_milestone/2" do
    test "inserts a milestone under a mission" do
      mission = insert(:mission)

      assert {:ok, ms} =
               Missions.add_milestone(mission.id, %{
                 title: "Implement auth"
               })

      assert ms.mission_id == mission.id
      assert ms.title == "Implement auth"
      assert ms.status == "pending"
      assert ms.order == 0
    end

    test "auto-increments order for each new milestone" do
      mission = insert(:mission)
      {:ok, ms1} = Missions.add_milestone(mission.id, %{title: "First"})
      {:ok, ms2} = Missions.add_milestone(mission.id, %{title: "Second"})

      assert ms2.order == ms1.order + 1
    end

    test "returns not_found for unknown mission_id" do
      assert {:error, :not_found} =
               Missions.add_milestone(Ecto.UUID.generate(), %{title: "Orphan"})
    end

    test "returns changeset error for missing title" do
      mission = insert(:mission)
      assert {:error, changeset} = Missions.add_milestone(mission.id, %{})
      assert changeset.errors[:title]
    end
  end

  # ---------------------------------------------------------------------------
  # advance_milestone/2 — dependency resolution
  # ---------------------------------------------------------------------------

  describe "advance_milestone/2 — dependencies" do
    test "completes a milestone with no dependencies" do
      mission = insert(:mission)

      {:ok, ms} =
        Missions.add_milestone(mission.id, %{
          title: "No deps",
          depends_on_ids: []
        })

      assert {:ok, completed} = Missions.advance_milestone(ms.id)
      assert completed.status == "completed"
      assert completed.completed_at != nil
    end

    test "advances when all deps are completed" do
      mission = insert(:mission)

      # Insert dep directly so we can set it to completed
      dep =
        Repo.insert!(%Milestone{
          mission_id: mission.id,
          title: "Dep",
          status: "completed",
          order: 0,
          completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      {:ok, ms} =
        Missions.add_milestone(mission.id, %{
          title: "Depends on dep",
          depends_on_ids: [dep.id]
        })

      assert {:ok, completed} = Missions.advance_milestone(ms.id)
      assert completed.status == "completed"
    end

    test "returns deps_not_met when a dependency is still pending" do
      mission = insert(:mission)

      pending_dep =
        Repo.insert!(%Milestone{
          mission_id: mission.id,
          title: "Pending dep",
          status: "pending",
          order: 0
        })

      {:ok, ms} =
        Missions.add_milestone(mission.id, %{
          title: "Blocked by pending",
          depends_on_ids: [pending_dep.id]
        })

      assert {:error, :deps_not_met} = Missions.advance_milestone(ms.id)
    end

    test "returns deps_not_met when dep is failed (not completed)" do
      mission = insert(:mission)

      failed_dep =
        Repo.insert!(%Milestone{
          mission_id: mission.id,
          title: "Failed dep",
          status: "failed",
          order: 0
        })

      {:ok, ms} =
        Missions.add_milestone(mission.id, %{
          title: "Depends on failed",
          depends_on_ids: [failed_dep.id]
        })

      assert {:error, :deps_not_met} = Missions.advance_milestone(ms.id)
    end

    test "returns not_found for unknown milestone" do
      assert {:error, :not_found} = Missions.advance_milestone(Ecto.UUID.generate())
    end
  end

  # ---------------------------------------------------------------------------
  # block_milestone/2 and fail_milestone/2
  # ---------------------------------------------------------------------------

  describe "block_milestone/2" do
    test "marks a milestone blocked" do
      mission = insert(:mission)
      {:ok, ms} = Missions.add_milestone(mission.id, %{title: "Blockable"})

      assert {:ok, blocked} = Missions.block_milestone(ms.id, "waiting on infra")
      assert blocked.status == "blocked"
    end
  end

  describe "fail_milestone/2" do
    test "marks a milestone failed" do
      mission = insert(:mission)
      {:ok, ms} = Missions.add_milestone(mission.id, %{title: "Failable"})

      assert {:ok, failed} = Missions.fail_milestone(ms.id, "tests did not pass")
      assert failed.status == "failed"
    end
  end

  # ---------------------------------------------------------------------------
  # mission_progress/1
  # ---------------------------------------------------------------------------

  describe "mission_progress/1" do
    test "returns zero progress for a mission with no milestones" do
      mission = insert(:mission)
      assert {:ok, %{total: 0, completed: 0, pct: pct}} = Missions.mission_progress(mission.id)
      assert pct == 0.0
    end

    test "returns correct progress when some milestones are completed" do
      mission = insert(:mission)

      Repo.insert!(%Milestone{
        mission_id: mission.id,
        title: "Done",
        status: "completed",
        order: 0
      })

      Repo.insert!(%Milestone{
        mission_id: mission.id,
        title: "Pending",
        status: "pending",
        order: 1
      })

      assert {:ok, %{total: 2, completed: 1, pct: 50.0}} = Missions.mission_progress(mission.id)
    end

    test "returns 100% when all milestones are completed" do
      mission = insert(:mission)

      Repo.insert!(%Milestone{
        mission_id: mission.id,
        title: "MS 1",
        status: "completed",
        order: 0
      })

      assert {:ok, %{total: 1, completed: 1, pct: 100.0}} = Missions.mission_progress(mission.id)
    end

    test "returns not_found for unknown mission" do
      assert {:error, :not_found} = Missions.mission_progress(Ecto.UUID.generate())
    end
  end
end
