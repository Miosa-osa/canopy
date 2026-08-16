defmodule Canopy.RoutinesTest do
  @moduledoc "Context tests for Canopy.Routines."

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Routines
  alias Canopy.Routines.Routine

  # ---------------------------------------------------------------------------
  # Schema / changeset
  # ---------------------------------------------------------------------------

  describe "Routine.changeset/2" do
    test "valid with required fields" do
      cs =
        Routine.changeset(%Routine{}, %{
          name: "Daily standup",
          cron: "0 9 * * *",
          prompt_template: "Run standup for {{workspace}}",
          workspace_slug: "default"
        })

      assert cs.valid?
    end

    test "invalid without name" do
      cs =
        Routine.changeset(%Routine{}, %{
          cron: "0 9 * * *",
          prompt_template: "...",
          workspace_slug: "ws"
        })

      refute cs.valid?
      assert "can't be blank" in errors_on(cs).name
    end

    test "invalid without cron" do
      cs =
        Routine.changeset(%Routine{}, %{
          name: "R",
          prompt_template: "...",
          workspace_slug: "ws"
        })

      refute cs.valid?
      assert "can't be blank" in errors_on(cs).cron
    end

    test "invalid without prompt_template" do
      cs =
        Routine.changeset(%Routine{}, %{
          name: "R",
          cron: "0 9 * * *",
          workspace_slug: "ws"
        })

      refute cs.valid?
      assert "can't be blank" in errors_on(cs).prompt_template
    end

    test "valid creates values: issue, task, goal" do
      for creates <- ~w(issue task goal) do
        cs =
          Routine.changeset(%Routine{}, %{
            name: "R",
            cron: "0 9 * * *",
            prompt_template: "...",
            workspace_slug: "ws",
            creates: creates
          })

        assert cs.valid?, "expected #{creates} to be valid"
      end
    end

    test "invalid creates value" do
      cs =
        Routine.changeset(%Routine{}, %{
          name: "R",
          cron: "0 9 * * *",
          prompt_template: "...",
          workspace_slug: "ws",
          creates: "sprint"
        })

      refute cs.valid?
      assert "is invalid" in errors_on(cs).creates
    end
  end

  # ---------------------------------------------------------------------------
  # create/1
  # ---------------------------------------------------------------------------

  describe "create/1" do
    test "inserts routine and generates R-XXXXXXXX short_id" do
      assert {:ok, routine} =
               Routines.create(%{
                 name: "Weekly review",
                 cron: "0 10 * * 5",
                 prompt_template: "Run review for {{workspace}}",
                 workspace_slug: "default"
               })

      assert routine.id
      assert String.starts_with?(routine.short_id, "R-")
      assert String.length(routine.short_id) == 10
      assert routine.enabled == true
      assert routine.run_count == 0
    end

    test "returns changeset error when required fields missing" do
      assert {:error, changeset} = Routines.create(%{name: "X"})
      refute changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # get/1
  # ---------------------------------------------------------------------------

  describe "get/1" do
    test "finds by short_id" do
      routine = insert(:routine)
      assert {:ok, found} = Routines.get(routine.short_id)
      assert found.id == routine.id
    end

    test "finds by uuid" do
      routine = insert(:routine)
      assert {:ok, found} = Routines.get(routine.id)
      assert found.id == routine.id
    end

    test "returns not_found for unknown id" do
      assert {:error, :not_found} = Routines.get("R-99999999")
      assert {:error, :not_found} = Routines.get(Ecto.UUID.generate())
    end
  end

  # ---------------------------------------------------------------------------
  # update/2
  # ---------------------------------------------------------------------------

  describe "update/2" do
    test "updates cron and name" do
      routine = insert(:routine)

      assert {:ok, updated} =
               Routines.update(routine.short_id, %{name: "Updated name", cron: "0 8 * * *"})

      assert updated.name == "Updated name"
      assert updated.cron == "0 8 * * *"
    end

    test "returns not_found for missing id" do
      assert {:error, :not_found} = Routines.update("R-99999999", %{name: "X"})
    end
  end

  # ---------------------------------------------------------------------------
  # enable/1 and disable/1
  # ---------------------------------------------------------------------------

  describe "enable/1 and disable/1" do
    test "enable sets enabled true" do
      routine = insert(:routine, enabled: false)
      assert {:ok, enabled} = Routines.enable(routine.short_id)
      assert enabled.enabled == true
    end

    test "disable sets enabled false" do
      routine = insert(:routine, enabled: true)
      assert {:ok, disabled} = Routines.disable(routine.short_id)
      assert disabled.enabled == false
    end
  end

  # ---------------------------------------------------------------------------
  # delete/1
  # ---------------------------------------------------------------------------

  describe "delete/1" do
    test "hard-deletes the routine" do
      routine = insert(:routine)
      assert :ok = Routines.delete(routine.short_id)
      assert {:error, :not_found} = Routines.get(routine.short_id)
    end

    test "returns not_found for missing id" do
      assert {:error, :not_found} = Routines.delete("R-99999999")
    end
  end

  # ---------------------------------------------------------------------------
  # fire/1
  # ---------------------------------------------------------------------------

  describe "fire/1" do
    test "creates a task and increments run_count" do
      routine =
        insert(:routine,
          creates: "task",
          workspace_slug: "default",
          prompt_template: "Run daily report for {{workspace}} on {{date}}",
          run_count: 0
        )

      assert {:ok, %{routine: updated, created: created}} = Routines.fire(routine.short_id)

      # run_count incremented
      assert updated.run_count == 1
      assert updated.last_run_at != nil

      # created work unit has rendered title
      assert String.contains?(created.title, "default")
      assert String.contains?(created.title, Date.utc_today() |> Date.to_string())
    end

    test "creates an issue when creates == 'issue'" do
      routine =
        insert(:routine,
          creates: "issue",
          workspace_slug: "default",
          prompt_template: "Weekly issue for {{workspace}}"
        )

      assert {:ok, %{routine: updated, created: created}} = Routines.fire(routine.short_id)
      assert updated.run_count == 1
      assert String.starts_with?(created.short_id, "I-")
    end

    test "creates a goal when creates == 'goal'" do
      routine =
        insert(:routine,
          creates: "goal",
          workspace_slug: "default",
          prompt_template: "Monthly goal for {{workspace}}"
        )

      assert {:ok, %{routine: updated, created: created}} = Routines.fire(routine.short_id)
      assert updated.run_count == 1
      assert String.starts_with?(created.short_id, "G-")
    end

    test "returns not_found for missing id" do
      assert {:error, :not_found} = Routines.fire("R-99999999")
    end
  end

  # ---------------------------------------------------------------------------
  # list/1
  # ---------------------------------------------------------------------------

  describe "list/1" do
    test "filters by workspace_slug" do
      insert(:routine, workspace_slug: "rws")
      insert(:routine, workspace_slug: "other")
      results = Routines.list(%{workspace_slug: "rws"})
      assert Enum.all?(results, &(&1.workspace_slug == "rws"))
    end

    test "filters by enabled flag" do
      insert(:routine, enabled: true, workspace_slug: "e-ws")
      insert(:routine, enabled: false, workspace_slug: "e-ws")
      results = Routines.list(%{workspace_slug: "e-ws", enabled: true})
      assert Enum.all?(results, &(&1.enabled == true))
    end
  end
end
