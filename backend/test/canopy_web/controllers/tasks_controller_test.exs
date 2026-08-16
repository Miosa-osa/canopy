defmodule CanopyWeb.TasksControllerTest do
  @moduledoc """
  Controller tests for POST /api/v1/tasks/:id/dispatch and the existing CRUD actions.
  """

  use CanopyWeb.ConnCase, async: false

  import Canopy.Factory

  # ---------------------------------------------------------------------------
  # POST /api/v1/tasks/:id/dispatch — happy path
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/tasks/:id/dispatch" do
    test "200 with session_id and updated task when agent is assigned", %{conn: conn} do
      agent =
        insert(:agent,
          hired: true,
          slug: "ctrl-dispatch-agent-1",
          default_runtime: "claude-local"
        )

      task = insert(:task, assignee_type: "agent", assignee_id: agent.slug, status: "todo")

      conn = post(conn, "/api/v1/tasks/#{task.short_id}/dispatch", %{})
      body = json_response(conn, 200)

      assert %{"data" => data} = body
      assert is_binary(data["session_id"])
      assert data["task"]["status"] == "in_progress"
      assert data["task"]["short_id"] == task.short_id
      assert is_binary(data["task"]["session_id"])
      assert is_binary(data["task"]["dispatched_at"])
    end

    test "200 with override agent_slug in body", %{conn: conn} do
      _default =
        insert(:agent,
          hired: true,
          slug: "ctrl-dispatch-agent-2",
          default_runtime: "claude-local"
        )

      override =
        insert(:agent,
          hired: true,
          slug: "ctrl-override-agent-1",
          default_runtime: "claude-local"
        )

      task = insert(:task, assignee_type: "agent", assignee_id: "ctrl-dispatch-agent-2")

      conn = post(conn, "/api/v1/tasks/#{task.short_id}/dispatch", %{agent_slug: override.slug})
      body = json_response(conn, 200)

      assert %{"data" => data} = body
      assert is_binary(data["session_id"])
    end

    test "404 when task does not exist", %{conn: conn} do
      conn = post(conn, "/api/v1/tasks/T-99999999/dispatch", %{})
      assert json_response(conn, 404)
    end

    test "422 with no_target error when no agent is assigned", %{conn: conn} do
      task = insert(:task, assignee_type: nil, assignee_id: nil)

      conn = post(conn, "/api/v1/tasks/#{task.short_id}/dispatch", %{})
      body = json_response(conn, 422)

      assert body["error"] == "no_target"
      assert is_binary(body["message"])
    end

    test "422 with no_target when assignee_type is 'user'", %{conn: conn} do
      task = insert(:task, assignee_type: "user", assignee_id: Ecto.UUID.generate())

      conn = post(conn, "/api/v1/tasks/#{task.short_id}/dispatch", %{})
      body = json_response(conn, 422)

      assert body["error"] == "no_target"
    end

    test "422 with no_target when agent slug in override does not exist", %{conn: conn} do
      task = insert(:task, assignee_type: nil)

      conn = post(conn, "/api/v1/tasks/#{task.short_id}/dispatch", %{agent_slug: "ghost-agent"})
      body = json_response(conn, 422)

      assert body["error"] == "no_target"
    end
  end

  # ---------------------------------------------------------------------------
  # Existing CRUD — ensure nothing is broken
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/tasks" do
    test "returns task list", %{conn: conn} do
      insert(:task, title: "First task")
      insert(:task, title: "Second task")

      conn = get(conn, "/api/v1/tasks")
      body = json_response(conn, 200)

      assert %{"data" => data, "count" => count} = body
      assert count >= 2
      assert is_list(data)
    end
  end

  describe "POST /api/v1/tasks" do
    test "creates a task and returns 201", %{conn: conn} do
      conn = post(conn, "/api/v1/tasks", %{"title" => "New task", "description" => "Details"})
      body = json_response(conn, 201)

      assert %{"data" => data} = body
      assert data["title"] == "New task"
      assert data["status"] == "todo"
      assert is_binary(data["short_id"])
    end
  end

  describe "GET /api/v1/tasks/:id" do
    test "returns task by short_id", %{conn: conn} do
      task = insert(:task, title: "Specific task")

      conn = get(conn, "/api/v1/tasks/#{task.short_id}")
      body = json_response(conn, 200)

      assert body["data"]["title"] == "Specific task"
    end

    test "returns 404 for unknown short_id", %{conn: conn} do
      conn = get(conn, "/api/v1/tasks/T-00000000")
      assert json_response(conn, 404)
    end
  end

  describe "PATCH /api/v1/tasks/:id" do
    test "updates task fields", %{conn: conn} do
      task = insert(:task, title: "Old title")

      conn = patch(conn, "/api/v1/tasks/#{task.short_id}", %{title: "New title"})
      body = json_response(conn, 200)

      assert body["data"]["title"] == "New title"
    end
  end

  describe "POST /api/v1/tasks/:id/complete" do
    test "marks task as done", %{conn: conn} do
      task = insert(:task, status: "todo")

      conn = post(conn, "/api/v1/tasks/#{task.short_id}/complete", %{})
      body = json_response(conn, 200)

      assert body["data"]["status"] == "done"
    end
  end

  describe "DELETE /api/v1/tasks/:id" do
    test "deletes task and returns 204", %{conn: conn} do
      task = insert(:task)

      conn = delete(conn, "/api/v1/tasks/#{task.short_id}")
      assert response(conn, 204)
    end
  end
end
