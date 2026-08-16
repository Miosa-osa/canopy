defmodule CanopyWeb.GoalsControllerTest do
  @moduledoc "Controller tests for the Goals API."

  use CanopyWeb.ConnCase, async: true

  import Canopy.Factory

  # ---------------------------------------------------------------------------
  # GET /api/v1/goals
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/goals" do
    test "200 returns goal list", %{conn: conn} do
      insert(:goal, workspace_slug: "ctrl-goals-ws")
      conn = get(conn, "/api/v1/goals", workspace_slug: "ctrl-goals-ws")
      body = json_response(conn, 200)
      assert is_list(body["data"])
      assert body["count"] >= 1
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/goals
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/goals" do
    test "201 creates and returns goal", %{conn: conn} do
      conn =
        post(conn, "/api/v1/goals", %{title: "Ship v2", workspace_slug: "default"})

      body = json_response(conn, 201)
      assert body["data"]["title"] == "Ship v2"
      assert String.starts_with?(body["data"]["short_id"], "G-")
      assert body["data"]["status"] == "proposed"
    end

    test "422 when title missing", %{conn: conn} do
      conn = post(conn, "/api/v1/goals", %{workspace_slug: "ws"})
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/goals/:id
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/goals/:id" do
    test "200 returns goal by short_id", %{conn: conn} do
      goal = insert(:goal)
      conn = get(conn, "/api/v1/goals/#{goal.short_id}")
      body = json_response(conn, 200)
      assert body["data"]["short_id"] == goal.short_id
    end

    test "200 returns goal by uuid", %{conn: conn} do
      goal = insert(:goal)
      conn = get(conn, "/api/v1/goals/#{goal.id}")
      body = json_response(conn, 200)
      assert body["data"]["id"] == goal.id
    end

    test "404 for unknown id", %{conn: conn} do
      conn = get(conn, "/api/v1/goals/G-99999999")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/goals/:id
  # ---------------------------------------------------------------------------

  describe "PATCH /api/v1/goals/:id" do
    test "200 updates the goal", %{conn: conn} do
      goal = insert(:goal)
      conn = patch(conn, "/api/v1/goals/#{goal.short_id}", %{status: "active"})
      body = json_response(conn, 200)
      assert body["data"]["status"] == "active"
    end

    test "404 for unknown id", %{conn: conn} do
      conn = patch(conn, "/api/v1/goals/G-99999999", %{status: "active"})
      assert json_response(conn, 404)
    end

    test "422 for invalid status", %{conn: conn} do
      goal = insert(:goal)
      conn = patch(conn, "/api/v1/goals/#{goal.short_id}", %{status: "done"})
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/goals/:id/progress
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/goals/:id/progress" do
    test "200 sets progress_pct", %{conn: conn} do
      goal = insert(:goal, progress_pct: 0)
      conn = post(conn, "/api/v1/goals/#{goal.short_id}/progress", %{progress_pct: 60})
      body = json_response(conn, 200)
      assert body["data"]["progress_pct"] == 60
    end

    test "400 when progress_pct missing", %{conn: conn} do
      goal = insert(:goal)
      conn = post(conn, "/api/v1/goals/#{goal.short_id}/progress", %{})
      assert json_response(conn, 400)
    end

    test "404 for unknown goal", %{conn: conn} do
      conn = post(conn, "/api/v1/goals/G-99999999/progress", %{progress_pct: 50})
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/goals/:id/achieve
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/goals/:id/achieve" do
    test "200 marks goal achieved", %{conn: conn} do
      goal = insert(:goal, status: "active")
      conn = post(conn, "/api/v1/goals/#{goal.short_id}/achieve")
      body = json_response(conn, 200)
      assert body["data"]["status"] == "achieved"
      assert body["data"]["achieved_at"] != nil
      assert body["data"]["progress_pct"] == 100
    end

    test "404 for unknown goal", %{conn: conn} do
      conn = post(conn, "/api/v1/goals/G-99999999/achieve")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/goals/:id/cancel
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/goals/:id/cancel" do
    test "200 marks goal cancelled", %{conn: conn} do
      goal = insert(:goal, status: "active")
      conn = post(conn, "/api/v1/goals/#{goal.short_id}/cancel")
      body = json_response(conn, 200)
      assert body["data"]["status"] == "cancelled"
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/goals/:id
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/goals/:id" do
    test "204 deletes the goal", %{conn: conn} do
      goal = insert(:goal)
      conn = delete(conn, "/api/v1/goals/#{goal.short_id}")
      assert response(conn, 204) == ""
    end

    test "404 for unknown goal", %{conn: conn} do
      conn = delete(conn, "/api/v1/goals/G-99999999")
      assert json_response(conn, 404)
    end
  end
end
