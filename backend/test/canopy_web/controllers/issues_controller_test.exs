defmodule CanopyWeb.IssuesControllerTest do
  @moduledoc "Controller tests for the Issues API."

  use CanopyWeb.ConnCase, async: true

  import Canopy.Factory

  # ---------------------------------------------------------------------------
  # GET /api/v1/issues
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/issues" do
    test "200 returns issue list", %{conn: conn} do
      insert(:issue, workspace_slug: "ctrl-list-ws")
      conn = get(conn, "/api/v1/issues", workspace_slug: "ctrl-list-ws")
      body = json_response(conn, 200)
      assert is_list(body["data"])
      assert is_integer(body["count"])
    end

    test "200 with empty list when no issues", %{conn: conn} do
      conn =
        get(conn, "/api/v1/issues", workspace_slug: "empty-ctrl-ws-#{System.unique_integer()}")

      body = json_response(conn, 200)
      assert body["data"] == []
      assert body["count"] == 0
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/issues
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/issues" do
    test "201 creates and returns issue", %{conn: conn} do
      conn =
        post(conn, "/api/v1/issues", %{title: "New issue", workspace_slug: "default"})

      body = json_response(conn, 201)
      assert body["data"]["title"] == "New issue"
      assert String.starts_with?(body["data"]["short_id"], "I-")
      assert body["data"]["status"] == "open"
    end

    test "422 when title missing", %{conn: conn} do
      conn = post(conn, "/api/v1/issues", %{workspace_slug: "ws"})
      assert json_response(conn, 422)
    end

    test "422 when workspace_slug missing", %{conn: conn} do
      conn = post(conn, "/api/v1/issues", %{title: "X"})
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/issues/:id
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/issues/:id" do
    test "200 returns issue by short_id", %{conn: conn} do
      issue = insert(:issue)
      conn = get(conn, "/api/v1/issues/#{issue.short_id}")
      body = json_response(conn, 200)
      assert body["data"]["short_id"] == issue.short_id
    end

    test "200 returns issue by uuid", %{conn: conn} do
      issue = insert(:issue)
      conn = get(conn, "/api/v1/issues/#{issue.id}")
      body = json_response(conn, 200)
      assert body["data"]["id"] == issue.id
    end

    test "404 for unknown id", %{conn: conn} do
      conn = get(conn, "/api/v1/issues/I-99999999")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/issues/:id
  # ---------------------------------------------------------------------------

  describe "PATCH /api/v1/issues/:id" do
    test "200 updates the issue", %{conn: conn} do
      issue = insert(:issue)
      conn = patch(conn, "/api/v1/issues/#{issue.short_id}", %{status: "in_review"})
      body = json_response(conn, 200)
      assert body["data"]["status"] == "in_review"
    end

    test "404 for unknown id", %{conn: conn} do
      conn = patch(conn, "/api/v1/issues/I-99999999", %{status: "open"})
      assert json_response(conn, 404)
    end

    test "422 for invalid status", %{conn: conn} do
      issue = insert(:issue)
      conn = patch(conn, "/api/v1/issues/#{issue.short_id}", %{status: "bad"})
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/issues/:id/assign
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/issues/:id/assign" do
    test "200 assigns issue to agent", %{conn: conn} do
      issue = insert(:issue)

      conn =
        post(conn, "/api/v1/issues/#{issue.short_id}/assign", %{
          assignee_type: "agent",
          assignee_id: "backend-agent"
        })

      body = json_response(conn, 200)
      assert body["data"]["assignee_type"] == "agent"
      assert body["data"]["assignee_id"] == "backend-agent"
    end

    test "400 when params missing", %{conn: conn} do
      issue = insert(:issue)
      conn = post(conn, "/api/v1/issues/#{issue.short_id}/assign", %{})
      assert json_response(conn, 400)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/issues/:id/complete
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/issues/:id/complete" do
    test "200 closes the issue", %{conn: conn} do
      issue = insert(:issue, status: "open")
      conn = post(conn, "/api/v1/issues/#{issue.short_id}/complete")
      body = json_response(conn, 200)
      assert body["data"]["status"] == "closed"
      assert body["data"]["completed_at"] != nil
    end

    test "404 for unknown issue", %{conn: conn} do
      conn = post(conn, "/api/v1/issues/I-99999999/complete")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/issues/:id/reopen
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/issues/:id/reopen" do
    test "200 reopens the issue", %{conn: conn} do
      issue = insert(:issue, status: "closed")
      conn = post(conn, "/api/v1/issues/#{issue.short_id}/reopen")
      body = json_response(conn, 200)
      assert body["data"]["status"] == "open"
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/issues/:id
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/issues/:id" do
    test "204 deletes the issue", %{conn: conn} do
      issue = insert(:issue)
      conn = delete(conn, "/api/v1/issues/#{issue.short_id}")
      assert response(conn, 204) == ""
    end

    test "404 for unknown issue", %{conn: conn} do
      conn = delete(conn, "/api/v1/issues/I-99999999")
      assert json_response(conn, 404)
    end
  end
end
