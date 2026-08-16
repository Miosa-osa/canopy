defmodule Canopy.ProjectsTest do
  @moduledoc "Context tests for Canopy.Projects."

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Projects
  alias Canopy.Projects.Project

  # ---------------------------------------------------------------------------
  # Schema / changeset
  # ---------------------------------------------------------------------------

  describe "Project.changeset/2" do
    test "valid with required fields" do
      cs = Project.changeset(%Project{}, %{name: "My Project", workspace_slug: "default"})
      assert cs.valid?
    end

    test "invalid without name" do
      cs = Project.changeset(%Project{}, %{workspace_slug: "ws"})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).name
    end

    test "invalid without workspace_slug" do
      cs = Project.changeset(%Project{}, %{name: "P"})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).workspace_slug
    end

    test "invalid status" do
      cs = Project.changeset(%Project{}, %{name: "P", workspace_slug: "ws", status: "deleted"})
      refute cs.valid?
      assert "is invalid" in errors_on(cs).status
    end

    test "valid statuses" do
      for status <- ~w(active paused archived) do
        cs = Project.changeset(%Project{}, %{name: "P", workspace_slug: "ws", status: status})
        assert cs.valid?, "expected #{status} to be valid"
      end
    end

    test "auto-slugifies from name when slug omitted" do
      cs = Project.changeset(%Project{}, %{name: "Canopy Launch", workspace_slug: "ws"})
      assert cs.valid?
      assert get_change(cs, :slug) == "canopy-launch"
    end

    test "invalid color format" do
      cs = Project.changeset(%Project{}, %{name: "P", workspace_slug: "ws", color: "red"})
      refute cs.valid?
      assert "must be a 6-digit hex color" in errors_on(cs).color
    end

    test "valid color format" do
      cs = Project.changeset(%Project{}, %{name: "P", workspace_slug: "ws", color: "#7bd88f"})
      assert cs.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # create/1
  # ---------------------------------------------------------------------------

  describe "create/1" do
    test "inserts project and auto-generates slug" do
      assert {:ok, project} =
               Projects.create(%{name: "Canopy Launch", workspace_slug: "default"})

      assert project.id
      assert project.slug == "canopy-launch"
      assert project.status == "active"
    end

    test "accepts explicit slug" do
      assert {:ok, project} =
               Projects.create(%{
                 name: "My Project",
                 slug: "my-project",
                 workspace_slug: "default"
               })

      assert project.slug == "my-project"
    end

    test "accepts string keys" do
      assert {:ok, project} =
               Projects.create(%{"name" => "From HTTP", "workspace_slug" => "ws"})

      assert project.name == "From HTTP"
    end

    test "returns changeset error for missing name" do
      assert {:error, changeset} = Projects.create(%{workspace_slug: "ws"})
      refute changeset.valid?
    end

    test "slug uniqueness is enforced" do
      {:ok, _} = Projects.create(%{name: "Alpha", slug: "alpha-proj", workspace_slug: "ws"})

      assert {:error, changeset} =
               Projects.create(%{name: "Alpha 2", slug: "alpha-proj", workspace_slug: "ws"})

      assert "has already been taken" in errors_on(changeset).slug
    end
  end

  # ---------------------------------------------------------------------------
  # get/1
  # ---------------------------------------------------------------------------

  describe "get/1" do
    test "finds by slug" do
      project = insert(:project, slug: "find-me")
      assert {:ok, found} = Projects.get("find-me")
      assert found.id == project.id
    end

    test "returns not_found for unknown slug" do
      assert {:error, :not_found} = Projects.get("no-such-project")
    end
  end

  # ---------------------------------------------------------------------------
  # get_summary/1
  # ---------------------------------------------------------------------------

  describe "get_summary/1" do
    test "returns project with zero counts when no work items linked" do
      insert(:project, slug: "summary-test-proj")
      assert {:ok, data} = Projects.get_summary("summary-test-proj")
      assert %{project: _project, issues_count: 0, tasks_count: 0, goals_count: 0} = data
    end

    test "returns not_found for unknown slug" do
      assert {:error, :not_found} = Projects.get_summary("ghost-slug")
    end
  end

  # ---------------------------------------------------------------------------
  # update/2
  # ---------------------------------------------------------------------------

  describe "update/2" do
    test "updates name and status" do
      project = insert(:project)
      assert {:ok, updated} = Projects.update(project.slug, %{name: "Updated", status: "paused"})
      assert updated.name == "Updated"
      assert updated.status == "paused"
    end

    test "returns not_found for missing slug" do
      assert {:error, :not_found} = Projects.update("no-such", %{name: "X"})
    end

    test "returns changeset error for bad status" do
      project = insert(:project)
      assert {:error, changeset} = Projects.update(project.slug, %{status: "deleted"})
      refute changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # archive/1 + unarchive/1
  # ---------------------------------------------------------------------------

  describe "archive/1" do
    test "sets status to archived and stamps archived_at" do
      project = insert(:project, status: "active")
      assert {:ok, archived} = Projects.archive(project.slug)
      assert archived.status == "archived"
      assert archived.archived_at != nil
    end

    test "returns not_found for unknown slug" do
      assert {:error, :not_found} = Projects.archive("ghost")
    end
  end

  describe "unarchive/1" do
    test "restores to active and clears archived_at" do
      now = DateTime.truncate(DateTime.utc_now(), :second)
      project = insert(:project, status: "archived", archived_at: now)
      assert {:ok, restored} = Projects.unarchive(project.slug)
      assert restored.status == "active"
      assert restored.archived_at == nil
    end
  end

  # ---------------------------------------------------------------------------
  # delete/1
  # ---------------------------------------------------------------------------

  describe "delete/1" do
    test "hard-deletes the project" do
      project = insert(:project)
      assert :ok = Projects.delete(project.slug)
      assert {:error, :not_found} = Projects.get(project.slug)
    end

    test "dissociates tasks before deletion" do
      _project = insert(:project, slug: "dissoc-tasks-proj")

      {:ok, task} =
        Canopy.Tasks.create(%{
          title: "Linked task",
          workspace_slug: "default",
          project_slug: "dissoc-tasks-proj"
        })

      assert :ok = Projects.delete("dissoc-tasks-proj")

      task_after = Canopy.Repo.get!(Canopy.Tasks.Task, task.id)
      assert task_after.project_slug == nil
    end

    test "dissociates goals before deletion" do
      _project = insert(:project, slug: "dissoc-goals-proj")

      {:ok, goal} =
        Canopy.Goals.create(%{
          title: "Linked goal",
          workspace_slug: "default",
          project_slug: "dissoc-goals-proj"
        })

      assert :ok = Projects.delete("dissoc-goals-proj")

      goal_after = Canopy.Repo.get!(Canopy.Goals.Goal, goal.id)
      assert goal_after.project_slug == nil
    end

    test "returns not_found for missing slug" do
      assert {:error, :not_found} = Projects.delete("ghost")
    end
  end

  # ---------------------------------------------------------------------------
  # list/1
  # ---------------------------------------------------------------------------

  describe "list/1" do
    test "filters by workspace_slug" do
      insert(:project, workspace_slug: "list-ws-proj")
      insert(:project, workspace_slug: "other-ws")
      results = Projects.list(%{workspace_slug: "list-ws-proj"})
      assert length(results) == 1
      assert hd(results).workspace_slug == "list-ws-proj"
    end

    test "filters by status" do
      insert(:project, status: "active", workspace_slug: "status-ws")
      insert(:project, status: "paused", workspace_slug: "status-ws")
      results = Projects.list(%{workspace_slug: "status-ws", status: "active"})
      assert Enum.all?(results, &(&1.status == "active"))
    end

    test "returns all projects when no filters" do
      insert(:project)
      results = Projects.list(%{})
      assert length(results) >= 1
    end
  end
end
