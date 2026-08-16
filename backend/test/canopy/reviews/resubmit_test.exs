defmodule Canopy.Reviews.ResubmitTest do
  @moduledoc "Tests for the resubmit cycle: changes_requested → pending."

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Reviews

  describe "resubmit/2" do
    test "transitions changes_requested review back to pending" do
      review =
        insert(:review,
          status: "changes_requested",
          decided_at: DateTime.utc_now() |> DateTime.truncate(:second),
          feedback: "Fix the intro."
        )

      assert {:ok, resubmitted} = Reviews.resubmit(review.id)
      assert resubmitted.status == "pending"
      assert resubmitted.revision_count == 1
      assert resubmitted.decided_at == nil
    end

    test "increments revision_count on each resubmit" do
      review =
        insert(:review,
          status: "changes_requested",
          revision_count: 2,
          decided_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      assert {:ok, resubmitted} = Reviews.resubmit(review.id)
      assert resubmitted.revision_count == 3
    end

    test "optionally updates artifact_preview" do
      review =
        insert(:review,
          status: "changes_requested",
          decided_at: DateTime.utc_now() |> DateTime.truncate(:second),
          artifact_preview: "old preview"
        )

      assert {:ok, updated} = Reviews.resubmit(review.id, %{artifact_preview: "new preview"})
      assert updated.artifact_preview == "new preview"
    end

    test "returns not_changes_requested for pending review" do
      review = insert(:review, status: "pending")
      assert {:error, :not_changes_requested} = Reviews.resubmit(review.id)
    end

    test "returns not_changes_requested for approved review" do
      review =
        insert(:review,
          status: "approved",
          decided_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      assert {:error, :not_changes_requested} = Reviews.resubmit(review.id)
    end

    test "returns not_found for unknown id" do
      assert {:error, :not_found} = Reviews.resubmit(Ecto.UUID.generate())
    end

    test "resubmitted review can be approved" do
      review =
        insert(:review,
          status: "changes_requested",
          decided_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      {:ok, resubmitted} = Reviews.resubmit(review.id)
      assert {:ok, approved} = Reviews.approve(resubmitted.id, "reviewer-1")
      assert approved.status == "approved"
      assert approved.revision_count == 1
    end
  end

  describe "request_hire_agent/5" do
    test "creates a hire_agent review" do
      parent_sid = Ecto.UUID.generate()

      assert {:ok, review} =
               Reviews.request_hire_agent(
                 parent_sid,
                 "child-agent",
                 "Build a feature",
                 %{},
                 workspace_slug: "default"
               )

      assert review.kind == "hire_agent"
      assert review.status == "pending"
      assert review.tool_name == "canopy.spawn_session"
      assert review.tool_args["child_agent_slug"] == "child-agent"
      assert review.session_id == parent_sid
    end
  end
end
