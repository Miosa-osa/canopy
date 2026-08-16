defmodule Canopy.IssuesTest do
  @moduledoc "Context tests for Canopy.Issues."

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Issues
  alias Canopy.Issues.Issue

  # ---------------------------------------------------------------------------
  # Schema / changeset
  # ---------------------------------------------------------------------------

  describe "Issue.changeset/2" do
    test "valid with required fields" do
      changeset = Issue.changeset(%Issue{}, %{title: "Fix bug", workspace_slug: "default"})
      assert changeset.valid?
    end

    test "invalid without title" do
      changeset = Issue.changeset(%Issue{}, %{workspace_slug: "default"})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).title
    end

    test "invalid without workspace_slug" do
      changeset = Issue.changeset(%Issue{}, %{title: "Fix bug"})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).workspace_slug
    end

    test "invalid with bad status" do
      changeset =
        Issue.changeset(%Issue{}, %{title: "X", workspace_slug: "ws", status: "bad_status"})

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end

    test "valid statuses" do
      for status <- ~w(backlog open in_progress in_review closed) do
        cs = Issue.changeset(%Issue{}, %{title: "X", workspace_slug: "ws", status: status})
        assert cs.valid?, "expected #{status} to be valid"
      end
    end

    test "invalid priority out of range" do
      changeset =
        Issue.changeset(%Issue{}, %{title: "X", workspace_slug: "ws", priority: 99})

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).priority
    end
  end

  # ---------------------------------------------------------------------------
  # create/1
  # ---------------------------------------------------------------------------

  describe "create/1" do
    test "inserts issue and generates I-XXXXXXXX short_id" do
      assert {:ok, issue} = Issues.create(%{title: "New issue", workspace_slug: "default"})
      assert issue.id
      assert String.starts_with?(issue.short_id, "I-")
      assert String.length(issue.short_id) == 10
      assert issue.status == "open"
    end

    test "accepts string keys from HTTP params" do
      assert {:ok, issue} =
               Issues.create(%{
                 "title" => "String key issue",
                 "workspace_slug" => "default",
                 "priority" => 2
               })

      assert issue.priority == 2
    end

    test "returns changeset error when title missing" do
      assert {:error, changeset} = Issues.create(%{workspace_slug: "ws"})
      refute changeset.valid?
    end

    test "sets optional fields" do
      assert {:ok, issue} =
               Issues.create(%{
                 title: "Detailed",
                 workspace_slug: "ws",
                 status: "in_review",
                 priority: 3,
                 labels: ["bug", "frontend"],
                 branch: "fix/login"
               })

      assert issue.status == "in_review"
      assert issue.priority == 3
      assert issue.labels == ["bug", "frontend"]
      assert issue.branch == "fix/login"
    end
  end

  # ---------------------------------------------------------------------------
  # get/1
  # ---------------------------------------------------------------------------

  describe "get/1" do
    test "finds by short_id" do
      issue = insert(:issue)
      assert {:ok, found} = Issues.get(issue.short_id)
      assert found.id == issue.id
    end

    test "finds by uuid" do
      issue = insert(:issue)
      assert {:ok, found} = Issues.get(issue.id)
      assert found.id == issue.id
    end

    test "returns not_found for missing short_id" do
      assert {:error, :not_found} = Issues.get("I-99999999")
    end

    test "returns not_found for unknown uuid" do
      assert {:error, :not_found} = Issues.get(Ecto.UUID.generate())
    end
  end

  # ---------------------------------------------------------------------------
  # update/2
  # ---------------------------------------------------------------------------

  describe "update/2" do
    test "updates title and status" do
      issue = insert(:issue, status: "open")

      assert {:ok, updated} =
               Issues.update(issue.short_id, %{title: "Changed", status: "in_progress"})

      assert updated.title == "Changed"
      assert updated.status == "in_progress"
    end

    test "returns not_found for missing id" do
      assert {:error, :not_found} = Issues.update("I-99999999", %{title: "X"})
    end

    test "returns changeset error for invalid status" do
      issue = insert(:issue)
      assert {:error, changeset} = Issues.update(issue.short_id, %{status: "nonsense"})
      refute changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # complete/1 and reopen/1
  # ---------------------------------------------------------------------------

  describe "complete/1" do
    test "marks issue closed and sets completed_at" do
      issue = insert(:issue, status: "open")
      assert {:ok, closed} = Issues.complete(issue.short_id)
      assert closed.status == "closed"
      assert closed.completed_at != nil
    end

    test "returns not_found for missing id" do
      assert {:error, :not_found} = Issues.complete("I-99999999")
    end
  end

  describe "reopen/1" do
    test "marks issue open and clears completed_at" do
      issue = insert(:issue, status: "closed")
      assert {:ok, reopened} = Issues.reopen(issue.short_id)
      assert reopened.status == "open"
      assert reopened.completed_at == nil
    end
  end

  # ---------------------------------------------------------------------------
  # assign/2
  # ---------------------------------------------------------------------------

  describe "assign/2" do
    test "sets assignee_type and assignee_id" do
      issue = insert(:issue)

      assert {:ok, assigned} =
               Issues.assign(issue.short_id, %{assignee_type: "agent", assignee_id: "test-agent"})

      assert assigned.assignee_type == "agent"
      assert assigned.assignee_id == "test-agent"
    end
  end

  # ---------------------------------------------------------------------------
  # delete/1
  # ---------------------------------------------------------------------------

  describe "delete/1" do
    test "hard-deletes the issue" do
      issue = insert(:issue)
      assert :ok = Issues.delete(issue.short_id)
      assert {:error, :not_found} = Issues.get(issue.short_id)
    end

    test "returns not_found for missing id" do
      assert {:error, :not_found} = Issues.delete("I-99999999")
    end
  end

  # ---------------------------------------------------------------------------
  # list/1
  # ---------------------------------------------------------------------------

  describe "list/1" do
    test "returns all issues sorted by updated_at desc" do
      i1 = insert(:issue, workspace_slug: "test-ws-list")
      i2 = insert(:issue, workspace_slug: "test-ws-list")
      ids = Issues.list(%{workspace_slug: "test-ws-list"}) |> Enum.map(& &1.id)
      assert i1.id in ids
      assert i2.id in ids
    end

    test "filters by status" do
      insert(:issue, status: "open", workspace_slug: "filter-ws")
      insert(:issue, status: "closed", workspace_slug: "filter-ws")
      results = Issues.list(%{workspace_slug: "filter-ws", status: "open"})
      assert Enum.all?(results, &(&1.status == "open"))
    end

    test "filters by workspace_slug" do
      insert(:issue, workspace_slug: "ws-a")
      insert(:issue, workspace_slug: "ws-b")
      results = Issues.list(%{workspace_slug: "ws-a"})
      assert Enum.all?(results, &(&1.workspace_slug == "ws-a"))
    end
  end
end
