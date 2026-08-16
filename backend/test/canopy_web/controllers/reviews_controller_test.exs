defmodule CanopyWeb.ReviewsControllerTest do
  @moduledoc "Controller tests for the Reviews (human-approval queue) API."

  use CanopyWeb.ConnCase, async: true

  import Canopy.Factory

  # ---------------------------------------------------------------------------
  # GET /api/v1/reviews
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/reviews" do
    test "200 returns review list", %{conn: conn} do
      ws = "ctrl-list-ws-#{System.unique_integer()}"
      insert(:review, workspace_slug: ws)
      conn = get(conn, "/api/v1/reviews", workspace_slug: ws)
      body = json_response(conn, 200)
      assert is_list(body["data"])
      assert is_integer(body["count"])
    end

    test "200 with empty list when no reviews", %{conn: conn} do
      conn = get(conn, "/api/v1/reviews", workspace_slug: "empty-ws-#{System.unique_integer()}")
      body = json_response(conn, 200)
      assert body["data"] == []
      assert body["count"] == 0
    end

    test "200 filters by status=pending", %{conn: conn} do
      ws = "filter-status-ws-#{System.unique_integer()}"
      insert(:review, workspace_slug: ws, status: "pending")
      conn = get(conn, "/api/v1/reviews", workspace_slug: ws, status: "pending")
      body = json_response(conn, 200)
      assert Enum.all?(body["data"], &(&1["status"] == "pending"))
    end

    test "200 filters by kind=tool_call", %{conn: conn} do
      ws = "filter-kind-ws-#{System.unique_integer()}"
      insert(:review, workspace_slug: ws)
      insert(:tool_call_review, workspace_slug: ws)
      conn = get(conn, "/api/v1/reviews", workspace_slug: ws, kind: "tool_call")
      body = json_response(conn, 200)
      assert Enum.all?(body["data"], &(&1["kind"] == "tool_call"))
    end
  end

  describe "GET /api/v1/reviews/summary" do
    test "200 returns real queue summary and honors filters", %{conn: conn} do
      ws = "ctrl-summary-ws-#{System.unique_integer()}"
      insert(:review, workspace_slug: ws, status: "pending", kind: "artifact", agent_id: "writer")
      insert(:tool_call_review, workspace_slug: ws, status: "pending", agent_id: "builder")

      insert(:review,
        workspace_slug: ws,
        status: "approved",
        kind: "artifact",
        agent_id: "writer",
        decided_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )

      conn = get(conn, "/api/v1/reviews/summary", workspace_slug: ws)
      body = json_response(conn, 200)

      assert body["data"]["total"] == 3
      assert body["data"]["pending_count"] == 2
      assert body["data"]["by_kind"]["artifact"] == 2
      assert body["data"]["by_kind"]["tool_call"] == 1
      assert body["data"]["by_agent"]["writer"] == 2
      assert length(body["data"]["recent"]) == 3
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/reviews/:id
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/reviews/:id" do
    test "200 returns review by uuid", %{conn: conn} do
      review = insert(:review)
      conn = get(conn, "/api/v1/reviews/#{review.id}")
      body = json_response(conn, 200)
      assert body["data"]["id"] == review.id
      assert body["data"]["kind"] == review.kind
    end

    test "404 for unknown id", %{conn: conn} do
      conn = get(conn, "/api/v1/reviews/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/reviews
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/reviews (artifact)" do
    test "201 creates artifact review", %{conn: conn} do
      conn =
        post(conn, "/api/v1/reviews", %{
          kind: "artifact",
          workspace_slug: "default",
          artifact_type: "doc",
          artifact_id: "doc-abc",
          artifact_preview: "# Draft\n\nContent.",
          agent_id: "test-agent"
        })

      body = json_response(conn, 201)
      assert body["data"]["kind"] == "artifact"
      assert body["data"]["status"] == "pending"
      assert body["data"]["artifact_type"] == "doc"
    end

    test "422 when kind is invalid", %{conn: conn} do
      conn = post(conn, "/api/v1/reviews", %{kind: "bad_kind"})
      assert json_response(conn, 422)
    end
  end

  describe "POST /api/v1/reviews (tool_call)" do
    test "201 creates tool_call review", %{conn: conn} do
      session_id = Ecto.UUID.generate()

      conn =
        post(conn, "/api/v1/reviews", %{
          kind: "tool_call",
          workspace_slug: "default",
          tool_name: "exec_shell",
          tool_args: %{command: "ls -la"},
          session_id: session_id,
          agent_id: "test-agent"
        })

      body = json_response(conn, 201)
      assert body["data"]["kind"] == "tool_call"
      assert body["data"]["tool_name"] == "exec_shell"
      assert body["data"]["workspace_slug"] == "default"
      assert body["data"]["agent_id"] == "test-agent"
      assert body["data"]["status"] == "pending"
    end

    test "422 when tool_name missing for tool_call", %{conn: conn} do
      conn =
        post(conn, "/api/v1/reviews", %{
          kind: "tool_call",
          workspace_slug: "default"
        })

      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/reviews/:id/approve
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/reviews/:id/approve" do
    test "200 approves a pending review", %{conn: conn} do
      review = insert(:review, status: "pending")
      conn = post(conn, "/api/v1/reviews/#{review.id}/approve", %{reviewer_id: "human-1"})
      body = json_response(conn, 200)
      assert body["data"]["status"] == "approved"
      assert body["data"]["reviewer_id"] == "human-1"
    end

    test "422 when review is already decided", %{conn: conn} do
      review =
        insert(:review,
          status: "approved",
          decided_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      conn = post(conn, "/api/v1/reviews/#{review.id}/approve", %{})
      body = json_response(conn, 422)
      assert body["error"] == "not_pending"
    end

    test "404 for unknown review", %{conn: conn} do
      conn = post(conn, "/api/v1/reviews/#{Ecto.UUID.generate()}/approve", %{})
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/reviews/:id/reject
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/reviews/:id/reject" do
    test "200 rejects a pending review with feedback", %{conn: conn} do
      review = insert(:review, status: "pending")

      conn =
        post(conn, "/api/v1/reviews/#{review.id}/reject", %{
          reviewer_id: "human-1",
          feedback: "Not ready yet."
        })

      body = json_response(conn, 200)
      assert body["data"]["status"] == "rejected"
      assert body["data"]["feedback"] == "Not ready yet."
    end

    test "422 when review is already decided", %{conn: conn} do
      review =
        insert(:review,
          status: "rejected",
          decided_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      conn = post(conn, "/api/v1/reviews/#{review.id}/reject", %{feedback: "x"})
      body = json_response(conn, 422)
      assert body["error"] == "not_pending"
    end

    test "404 for unknown review", %{conn: conn} do
      conn = post(conn, "/api/v1/reviews/#{Ecto.UUID.generate()}/reject", %{})
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/reviews/:id/request_changes
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/reviews/:id/request_changes" do
    test "200 requests changes on a pending review", %{conn: conn} do
      review = insert(:review, status: "pending")

      conn =
        post(conn, "/api/v1/reviews/#{review.id}/request_changes", %{
          reviewer_id: "human-1",
          feedback: "Fix the introduction."
        })

      body = json_response(conn, 200)
      assert body["data"]["status"] == "changes_requested"
      assert body["data"]["feedback"] == "Fix the introduction."
    end

    test "422 when review is already decided", %{conn: conn} do
      review =
        insert(:review,
          status: "changes_requested",
          decided_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      conn =
        post(conn, "/api/v1/reviews/#{review.id}/request_changes", %{feedback: "more"})

      body = json_response(conn, 422)
      assert body["error"] == "not_pending"
    end

    test "404 for unknown review", %{conn: conn} do
      conn =
        post(conn, "/api/v1/reviews/#{Ecto.UUID.generate()}/request_changes", %{})

      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/reviews/:id/resubmit" do
    test "200 resubmits a changes_requested review and updates preview", %{conn: conn} do
      review =
        insert(:review,
          status: "changes_requested",
          decided_at: DateTime.utc_now() |> DateTime.truncate(:second),
          artifact_preview: "old"
        )

      conn =
        post(conn, "/api/v1/reviews/#{review.id}/resubmit", %{
          artifact_preview: "new"
        })

      body = json_response(conn, 200)
      assert body["data"]["status"] == "pending"
      assert body["data"]["artifact_preview"] == "new"
      assert body["data"]["revision_count"] == review.revision_count + 1
    end
  end
end
