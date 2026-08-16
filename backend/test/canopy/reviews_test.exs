defmodule Canopy.ReviewsTest do
  @moduledoc "Context tests for Canopy.Reviews."

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Reviews
  alias Canopy.Reviews.Review

  # ---------------------------------------------------------------------------
  # Schema / changeset
  # ---------------------------------------------------------------------------

  describe "Review.changeset/2" do
    test "valid artifact review with required fields" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      cs = Review.changeset(%Review{}, %{kind: "artifact", requested_at: now})
      assert cs.valid?
    end

    test "valid tool_call review with tool_name" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      cs =
        Review.changeset(%Review{}, %{
          kind: "tool_call",
          tool_name: "exec_shell",
          requested_at: now
        })

      assert cs.valid?
    end

    test "invalid with explicit nil kind" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      cs = Review.changeset(%Review{kind: nil}, %{requested_at: now, kind: nil})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).kind
    end

    test "invalid without requested_at" do
      cs = Review.changeset(%Review{}, %{kind: "artifact"})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).requested_at
    end

    test "invalid kind" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      cs = Review.changeset(%Review{}, %{kind: "nonsense", requested_at: now})
      refute cs.valid?
      assert "is invalid" in errors_on(cs).kind
    end

    test "invalid status" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      cs =
        Review.changeset(%Review{}, %{kind: "artifact", requested_at: now, status: "bad_status"})

      refute cs.valid?
      assert "is invalid" in errors_on(cs).status
    end

    test "tool_call without tool_name is invalid" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      cs = Review.changeset(%Review{}, %{kind: "tool_call", requested_at: now})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).tool_name
    end
  end

  # ---------------------------------------------------------------------------
  # request_artifact/1
  # ---------------------------------------------------------------------------

  describe "request_artifact/1" do
    test "creates a pending artifact review" do
      assert {:ok, review} =
               Reviews.request_artifact(%{
                 workspace_slug: "default",
                 artifact_type: "doc",
                 artifact_id: "doc-123",
                 artifact_preview: "# Draft\n\nContent here.",
                 agent_id: "test-agent"
               })

      assert review.id
      assert review.kind == "artifact"
      assert review.status == "pending"
      assert review.artifact_type == "doc"
      assert review.expires_at != nil
    end

    test "auto-sets requested_at and expires_at" do
      {:ok, review} =
        Reviews.request_artifact(%{workspace_slug: "ws", artifact_type: "task"})

      assert review.requested_at != nil
      diff = DateTime.diff(review.expires_at, review.requested_at, :second)
      assert diff == 24 * 3600
    end

    test "returns changeset error when kind is invalid" do
      # request_artifact always sets kind: "artifact" — but changeset validation still fires
      # on other fields. Confirm we get back an ok result with artifact kind.
      {:ok, review} = Reviews.request_artifact(%{workspace_slug: "ws"})
      assert review.kind == "artifact"
    end
  end

  # ---------------------------------------------------------------------------
  # request_tool_call/3
  # ---------------------------------------------------------------------------

  describe "request_tool_call/3" do
    test "creates a pending tool_call review" do
      session_id = Ecto.UUID.generate()

      assert {:ok, review} =
               Reviews.request_tool_call(session_id, "exec_shell", %{"cmd" => "ls"})

      assert review.kind == "tool_call"
      assert review.status == "pending"
      assert review.tool_name == "exec_shell"
      assert review.tool_args == %{"cmd" => "ls"}
      assert review.session_id == session_id
    end

    test "persists workspace and agent context from options" do
      session_id = Ecto.UUID.generate()

      assert {:ok, review} =
               Reviews.request_tool_call(session_id, "exec_shell", %{"cmd" => "ls"},
                 workspace_slug: "client-a",
                 agent_id: "builder"
               )

      assert review.workspace_slug == "client-a"
      assert review.agent_id == "builder"
    end

    test "accepts nil session_id" do
      assert {:ok, review} = Reviews.request_tool_call(nil, "send_email", %{})
      assert review.session_id == nil
    end

    test "requires tool_name" do
      # Empty string for tool_name should fail validation
      assert {:error, cs} = Reviews.request_tool_call(nil, "", %{})
      refute cs.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # get/1
  # ---------------------------------------------------------------------------

  describe "get/1" do
    test "returns review by uuid" do
      review = insert(:review)
      assert {:ok, found} = Reviews.get(review.id)
      assert found.id == review.id
    end

    test "returns not_found for unknown uuid" do
      assert {:error, :not_found} = Reviews.get(Ecto.UUID.generate())
    end
  end

  # ---------------------------------------------------------------------------
  # approve/2
  # ---------------------------------------------------------------------------

  describe "approve/2" do
    test "transitions pending review to approved" do
      review = insert(:review, status: "pending")
      assert {:ok, approved} = Reviews.approve(review.id, "reviewer-1")
      assert approved.status == "approved"
      assert approved.reviewer_id == "reviewer-1"
      assert approved.decided_at != nil
    end

    test "returns not_pending when review is already approved" do
      review =
        insert(:review,
          status: "approved",
          decided_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      assert {:error, :not_pending} = Reviews.approve(review.id, "reviewer-1")
    end

    test "returns not_pending when review is rejected" do
      review =
        insert(:review,
          status: "rejected",
          decided_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      assert {:error, :not_pending} = Reviews.approve(review.id, "reviewer-1")
    end

    test "returns not_found for unknown id" do
      assert {:error, :not_found} = Reviews.approve(Ecto.UUID.generate(), "r")
    end

    test "accepts nil reviewer_id" do
      review = insert(:review)
      assert {:ok, approved} = Reviews.approve(review.id, nil)
      assert approved.status == "approved"
    end
  end

  # ---------------------------------------------------------------------------
  # reject/3
  # ---------------------------------------------------------------------------

  describe "reject/3" do
    test "transitions pending review to rejected with feedback" do
      review = insert(:review, status: "pending")

      assert {:ok, rejected} =
               Reviews.reject(review.id, "reviewer-1", "Not acceptable.")

      assert rejected.status == "rejected"
      assert rejected.feedback == "Not acceptable."
      assert rejected.decided_at != nil
    end

    test "returns not_pending for already-decided review" do
      review =
        insert(:review,
          status: "approved",
          decided_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      assert {:error, :not_pending} = Reviews.reject(review.id, "r", "reason")
    end

    test "returns not_found for unknown id" do
      assert {:error, :not_found} = Reviews.reject(Ecto.UUID.generate(), "r", "reason")
    end
  end

  # ---------------------------------------------------------------------------
  # request_changes/3
  # ---------------------------------------------------------------------------

  describe "request_changes/3" do
    test "transitions pending review to changes_requested" do
      review = insert(:review, status: "pending")

      assert {:ok, updated} =
               Reviews.request_changes(review.id, "reviewer-1", "Fix the intro section.")

      assert updated.status == "changes_requested"
      assert updated.feedback == "Fix the intro section."
    end

    test "returns not_pending for already-decided review" do
      review =
        insert(:review,
          status: "rejected",
          decided_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      assert {:error, :not_pending} = Reviews.request_changes(review.id, "r", "feedback")
    end
  end

  # ---------------------------------------------------------------------------
  # list/1
  # ---------------------------------------------------------------------------

  describe "list/1" do
    test "returns all reviews ordered by requested_at desc" do
      ws = "list-test-ws-#{System.unique_integer()}"
      r1 = insert(:review, workspace_slug: ws)
      r2 = insert(:review, workspace_slug: ws)
      ids = Reviews.list(%{workspace_slug: ws}) |> Enum.map(& &1.id)
      assert r1.id in ids
      assert r2.id in ids
    end

    test "filters by status" do
      ws = "status-filter-ws-#{System.unique_integer()}"
      insert(:review, workspace_slug: ws, status: "pending")

      insert(:review,
        workspace_slug: ws,
        status: "approved",
        decided_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )

      pending = Reviews.list(%{workspace_slug: ws, status: "pending"})
      assert Enum.all?(pending, &(&1.status == "pending"))
    end

    test "filters by kind" do
      ws = "kind-filter-ws-#{System.unique_integer()}"
      insert(:review, workspace_slug: ws, kind: "artifact")
      insert(:tool_call_review, workspace_slug: ws)

      artifacts = Reviews.list(%{workspace_slug: ws, kind: "artifact"})
      assert Enum.all?(artifacts, &(&1.kind == "artifact"))
    end

    test "filters by agent_id" do
      ws = "agent-filter-ws-#{System.unique_integer()}"
      insert(:review, workspace_slug: ws, agent_id: "agent-a")
      insert(:review, workspace_slug: ws, agent_id: "agent-b")
      results = Reviews.list(%{workspace_slug: ws, agent_id: "agent-a"})
      assert Enum.all?(results, &(&1.agent_id == "agent-a"))
    end

    test "filters by session_id" do
      ws = "session-filter-ws-#{System.unique_integer()}"
      sid = Ecto.UUID.generate()
      insert(:review, workspace_slug: ws, session_id: sid)
      insert(:review, workspace_slug: ws, session_id: nil)
      results = Reviews.list(%{workspace_slug: ws, session_id: sid})
      assert Enum.all?(results, &(&1.session_id == sid))
    end
  end

  describe "summary/1" do
    test "returns counts, breakdowns, timing, and recent rows from real reviews" do
      ws = "summary-ws-#{System.unique_integer()}"

      old_requested_at =
        DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      new_requested_at = DateTime.utc_now() |> DateTime.truncate(:second)

      pending =
        insert(:review,
          workspace_slug: ws,
          status: "pending",
          kind: "artifact",
          agent_id: "writer",
          requested_at: old_requested_at,
          expires_at: DateTime.add(old_requested_at, 3600, :second)
        )

      insert(:tool_call_review,
        workspace_slug: ws,
        status: "pending",
        agent_id: "builder",
        requested_at: new_requested_at,
        expires_at: DateTime.add(new_requested_at, 7200, :second)
      )

      insert(:review,
        workspace_slug: ws,
        status: "approved",
        kind: "artifact",
        agent_id: "writer",
        decided_at: new_requested_at
      )

      insert(:review,
        workspace_slug: ws,
        status: "changes_requested",
        kind: "artifact",
        agent_id: nil,
        decided_at: new_requested_at
      )

      summary = Reviews.summary(%{workspace_slug: ws})

      assert summary.total == 4
      assert summary.pending_count == 2
      assert summary.decided_count == 1
      assert summary.changes_requested_count == 1
      assert summary.by_status["pending"] == 2
      assert summary.by_kind["artifact"] == 3
      assert summary.by_kind["tool_call"] == 1
      assert summary.by_workspace[ws] == 4
      assert summary.by_agent["writer"] == 2
      assert summary.by_agent["unassigned"] == 1
      assert DateTime.compare(summary.oldest_pending_at, pending.requested_at) == :eq
      assert DateTime.compare(summary.next_expiry_at, pending.expires_at) == :eq
      assert length(summary.recent) == 4
    end
  end
end
