defmodule Canopy.GoalsTest do
  @moduledoc "Context tests for Canopy.Goals."

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Goals
  alias Canopy.Goals.Goal

  # ---------------------------------------------------------------------------
  # Schema / changeset
  # ---------------------------------------------------------------------------

  describe "Goal.changeset/2" do
    test "valid with required fields" do
      changeset = Goal.changeset(%Goal{}, %{title: "Launch v2", workspace_slug: "default"})
      assert changeset.valid?
    end

    test "invalid without title" do
      changeset = Goal.changeset(%Goal{}, %{workspace_slug: "ws"})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).title
    end

    test "invalid without workspace_slug" do
      changeset = Goal.changeset(%Goal{}, %{title: "Goal X"})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).workspace_slug
    end

    test "valid statuses" do
      for status <- ~w(proposed active blocked achieved cancelled) do
        cs = Goal.changeset(%Goal{}, %{title: "G", workspace_slug: "ws", status: status})
        assert cs.valid?, "expected #{status} to be valid"
      end
    end

    test "invalid status" do
      cs = Goal.changeset(%Goal{}, %{title: "G", workspace_slug: "ws", status: "done"})
      refute cs.valid?
      assert "is invalid" in errors_on(cs).status
    end

    test "progress_pct must be 0–100" do
      cs_low = Goal.changeset(%Goal{}, %{title: "G", workspace_slug: "ws", progress_pct: -1})
      refute cs_low.valid?

      cs_high = Goal.changeset(%Goal{}, %{title: "G", workspace_slug: "ws", progress_pct: 101})
      refute cs_high.valid?

      cs_ok = Goal.changeset(%Goal{}, %{title: "G", workspace_slug: "ws", progress_pct: 50})
      assert cs_ok.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # create/1
  # ---------------------------------------------------------------------------

  describe "create/1" do
    test "inserts goal and generates G-XXXXXXXX short_id" do
      assert {:ok, goal} = Goals.create(%{title: "Ship it", workspace_slug: "default"})
      assert goal.id
      assert String.starts_with?(goal.short_id, "G-")
      assert String.length(goal.short_id) == 10
      assert goal.status == "proposed"
      assert goal.progress_pct == 0
    end

    test "accepts string keys" do
      assert {:ok, goal} =
               Goals.create(%{"title" => "From HTTP", "workspace_slug" => "ws"})

      assert goal.title == "From HTTP"
    end

    test "returns changeset error when required fields missing" do
      assert {:error, changeset} = Goals.create(%{})
      refute changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # get/1
  # ---------------------------------------------------------------------------

  describe "get/1" do
    test "finds by short_id" do
      goal = insert(:goal)
      assert {:ok, found} = Goals.get(goal.short_id)
      assert found.id == goal.id
    end

    test "finds by uuid" do
      goal = insert(:goal)
      assert {:ok, found} = Goals.get(goal.id)
      assert found.id == goal.id
    end

    test "returns not_found for unknown id" do
      assert {:error, :not_found} = Goals.get("G-99999999")
      assert {:error, :not_found} = Goals.get(Ecto.UUID.generate())
    end
  end

  # ---------------------------------------------------------------------------
  # update/2
  # ---------------------------------------------------------------------------

  describe "update/2" do
    test "updates fields" do
      goal = insert(:goal)
      assert {:ok, updated} = Goals.update(goal.short_id, %{title: "Updated", status: "active"})
      assert updated.title == "Updated"
      assert updated.status == "active"
    end

    test "returns not_found for missing id" do
      assert {:error, :not_found} = Goals.update("G-99999999", %{title: "X"})
    end
  end

  # ---------------------------------------------------------------------------
  # set_progress/2
  # ---------------------------------------------------------------------------

  describe "set_progress/2" do
    test "updates progress_pct" do
      goal = insert(:goal, progress_pct: 0)
      assert {:ok, updated} = Goals.set_progress(goal.short_id, 75)
      assert updated.progress_pct == 75
    end
  end

  # ---------------------------------------------------------------------------
  # achieve/1
  # ---------------------------------------------------------------------------

  describe "achieve/1" do
    test "marks achieved, sets achieved_at, sets progress to 100" do
      goal = insert(:goal, status: "active")
      assert {:ok, achieved} = Goals.achieve(goal.short_id)
      assert achieved.status == "achieved"
      assert achieved.achieved_at != nil
      assert achieved.progress_pct == 100
    end

    test "returns not_found for missing id" do
      assert {:error, :not_found} = Goals.achieve("G-99999999")
    end
  end

  # ---------------------------------------------------------------------------
  # cancel/1
  # ---------------------------------------------------------------------------

  describe "cancel/1" do
    test "marks cancelled" do
      goal = insert(:goal, status: "active")
      assert {:ok, cancelled} = Goals.cancel(goal.short_id)
      assert cancelled.status == "cancelled"
    end
  end

  # ---------------------------------------------------------------------------
  # delete/1
  # ---------------------------------------------------------------------------

  describe "delete/1" do
    test "hard-deletes the goal" do
      goal = insert(:goal)
      assert :ok = Goals.delete(goal.short_id)
      assert {:error, :not_found} = Goals.get(goal.short_id)
    end

    test "returns not_found for missing id" do
      assert {:error, :not_found} = Goals.delete("G-99999999")
    end
  end

  # ---------------------------------------------------------------------------
  # list/1
  # ---------------------------------------------------------------------------

  describe "list/1" do
    test "filters by workspace_slug" do
      insert(:goal, workspace_slug: "goal-ws")
      insert(:goal, workspace_slug: "other-ws")
      results = Goals.list(%{workspace_slug: "goal-ws"})
      assert Enum.all?(results, &(&1.workspace_slug == "goal-ws"))
    end

    test "filters by status" do
      insert(:goal, status: "active", workspace_slug: "gs-ws")
      insert(:goal, status: "proposed", workspace_slug: "gs-ws")
      results = Goals.list(%{workspace_slug: "gs-ws", status: "active"})
      assert Enum.all?(results, &(&1.status == "active"))
    end
  end
end
