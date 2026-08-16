defmodule Canopy.Tools.ReviewsTest do
  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Tools.Reviews, as: ReviewTools

  describe "__canopy_tools__/0" do
    test "declares review queue tools" do
      names = ReviewTools.__canopy_tools__() |> Enum.map(& &1.name)

      assert "review.list" in names
      assert "review.get" in names
      assert "review.summary" in names
      assert "review.request_artifact" in names
      assert "review.request_tool_call" in names
      assert "review.approve" in names
      assert "review.reject" in names
      assert "review.request_changes" in names
      assert "review.resubmit" in names
    end
  end

  describe "request_artifact/1" do
    test "creates a pending artifact review with workspace and agent context" do
      assert {:ok, review} =
               ReviewTools.request_artifact(%{
                 "workspace_slug" => "client-a",
                 "artifact_type" => "doc",
                 "artifact_id" => "brief",
                 "artifact_preview" => "# Brief",
                 "agent_id" => "writer"
               })

      assert review.kind == "artifact"
      assert review.status == "pending"
      assert review.workspace_slug == "client-a"
      assert review.agent_id == "writer"
    end
  end

  describe "request_tool_call/1" do
    test "creates a pending tool call review" do
      session_id = Ecto.UUID.generate()

      assert {:ok, review} =
               ReviewTools.request_tool_call(%{
                 "workspace_slug" => "client-a",
                 "session_id" => session_id,
                 "agent_id" => "operator",
                 "tool_name" => "exec_shell",
                 "tool_args" => %{"command" => "mix test"}
               })

      assert review.kind == "tool_call"
      assert review.tool_name == "exec_shell"
      assert review.tool_args == %{"command" => "mix test"}
      assert review.session_id == session_id
      assert review.workspace_slug == "client-a"
      assert review.agent_id == "operator"
    end
  end

  describe "list/1 and get/1" do
    test "filters saved review records" do
      review = insert(:review, workspace_slug: "client-a", status: "pending")
      insert(:review, workspace_slug: "client-b", status: "pending")

      assert {:ok, %{reviews: [found], count: 1}} =
               ReviewTools.list(%{"workspace_slug" => "client-a"})

      assert found.id == review.id
      assert {:ok, got} = ReviewTools.get(%{"id" => review.id})
      assert got.id == review.id
    end
  end

  describe "summary/1" do
    test "returns filtered queue summary for agents" do
      insert(:review, workspace_slug: "client-a", status: "pending", agent_id: "writer")

      insert(:tool_call_review,
        workspace_slug: "client-a",
        status: "pending",
        agent_id: "builder"
      )

      insert(:review, workspace_slug: "client-b", status: "pending", agent_id: "writer")

      assert {:ok, summary} = ReviewTools.summary(%{"workspace_slug" => "client-a"})
      assert summary.total == 2
      assert summary.pending_count == 2
      assert summary.by_agent["writer"] == 1
      assert summary.by_agent["builder"] == 1
    end
  end

  describe "decisions" do
    test "approve, request changes, resubmit, and reject use review lifecycle" do
      approved = insert(:review, status: "pending")
      assert {:ok, result} = ReviewTools.approve(%{"id" => approved.id, "reviewer_id" => "human"})
      assert result.status == "approved"
      assert result.reviewer_id == "human"

      changes = insert(:review, status: "pending")

      assert {:ok, requested} =
               ReviewTools.request_changes(%{"id" => changes.id, "feedback" => "revise"})

      assert requested.status == "changes_requested"
      assert requested.feedback == "revise"

      assert {:ok, resubmitted} =
               ReviewTools.resubmit(%{"id" => changes.id, "artifact_preview" => "updated"})

      assert resubmitted.status == "pending"
      assert resubmitted.artifact_preview == "updated"

      assert {:ok, rejected} = ReviewTools.reject(%{"id" => changes.id, "feedback" => "no"})
      assert rejected.status == "rejected"
      assert rejected.feedback == "no"
    end
  end
end
