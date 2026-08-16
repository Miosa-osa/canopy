defmodule CanopyWeb.TransitionControllerTest do
  @moduledoc """
  Controller tests for:
    POST /api/v1/tasks/:id/transition
    POST /api/v1/issues/:id/transition
    POST /api/v1/sessions/:id/pause
    POST /api/v1/sessions/:id/resume
    POST /api/v1/sessions/:id/stop
  """

  use CanopyWeb.ConnCase, async: false

  import Canopy.Factory

  # ---------------------------------------------------------------------------
  # Tasks transition
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/tasks/:id/transition — noop" do
    test "200 with updated task status", %{conn: conn} do
      task = insert(:task, status: "todo")

      conn =
        post(conn, "/api/v1/tasks/#{task.short_id}/transition", %{
          verb: "noop",
          status: "in_progress"
        })

      body = json_response(conn, 200)
      assert %{"data" => data} = body
      assert data["task"]["status"] == "in_progress"
    end

    test "404 for unknown task", %{conn: conn} do
      conn = post(conn, "/api/v1/tasks/T-00000000/transition", %{verb: "noop"})
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/tasks/:id/transition — start" do
    test "200 returns session_id when agent is assigned", %{conn: conn} do
      agent = insert(:agent, hired: true, slug: "tc-tr-agent-1", default_runtime: "claude-local")
      task = insert(:task, assignee_type: "agent", assignee_id: agent.slug, status: "todo")

      conn = post(conn, "/api/v1/tasks/#{task.short_id}/transition", %{verb: "start"})
      body = json_response(conn, 200)
      assert %{"data" => data} = body
      assert is_binary(data["session_id"])
      assert data["task"]["status"] == "in_progress"
    end

    test "422 when no agent target", %{conn: conn} do
      task = insert(:task, assignee_type: nil, assignee_id: nil)
      conn = post(conn, "/api/v1/tasks/#{task.short_id}/transition", %{verb: "start"})
      assert json_response(conn, 422)
    end
  end

  describe "POST /api/v1/tasks/:id/transition — done" do
    test "200 marks task done", %{conn: conn} do
      task = insert(:task, status: "in_progress")
      conn = post(conn, "/api/v1/tasks/#{task.short_id}/transition", %{verb: "done"})
      body = json_response(conn, 200)
      assert body["data"]["task"]["status"] == "done"
      assert body["data"]["task"]["completed_at"] != nil
    end
  end

  # ---------------------------------------------------------------------------
  # Issues transition
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/issues/:id/transition — noop" do
    test "200 with updated issue status", %{conn: conn} do
      issue = insert(:issue, status: "open", workspace_slug: "default")

      conn =
        post(conn, "/api/v1/issues/#{issue.short_id}/transition", %{
          verb: "noop",
          status: "in_progress"
        })

      body = json_response(conn, 200)
      assert %{"data" => data} = body
      assert data["issue"]["status"] == "in_progress"
    end

    test "404 for unknown issue", %{conn: conn} do
      conn = post(conn, "/api/v1/issues/I-00000000/transition", %{verb: "noop"})
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/issues/:id/transition — done" do
    test "200 closes issue", %{conn: conn} do
      issue = insert(:issue, status: "in_progress", workspace_slug: "default")
      conn = post(conn, "/api/v1/issues/#{issue.short_id}/transition", %{verb: "done"})
      body = json_response(conn, 200)
      assert body["data"]["issue"]["status"] == "closed"
    end
  end

  # ---------------------------------------------------------------------------
  # Session pause/resume/stop endpoints
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/sessions/:id/pause" do
    test "200 transitions session to paused", %{conn: conn} do
      session = insert(:session, status: "running")
      conn = post(conn, "/api/v1/sessions/#{session.id}/pause", %{})
      body = json_response(conn, 200)
      assert body["session"]["status"] == "paused"
    end

    test "404 for unknown session", %{conn: conn} do
      conn = post(conn, "/api/v1/sessions/#{Ecto.UUID.generate()}/pause", %{})
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/sessions/:id/resume" do
    test "200 transitions session to running", %{conn: conn} do
      session = insert(:session, status: "paused")
      conn = post(conn, "/api/v1/sessions/#{session.id}/resume", %{})
      body = json_response(conn, 200)
      assert body["session"]["status"] == "running"
    end

    test "404 for unknown session", %{conn: conn} do
      conn = post(conn, "/api/v1/sessions/#{Ecto.UUID.generate()}/resume", %{})
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/sessions/:id/stop" do
    test "200 transitions session to cancelled", %{conn: conn} do
      session = insert(:session, status: "running")
      conn = post(conn, "/api/v1/sessions/#{session.id}/stop", %{})
      body = json_response(conn, 200)
      assert body["session"]["status"] == "cancelled"
    end

    test "404 for unknown session", %{conn: conn} do
      conn = post(conn, "/api/v1/sessions/#{Ecto.UUID.generate()}/stop", %{})
      assert json_response(conn, 404)
    end
  end
end
