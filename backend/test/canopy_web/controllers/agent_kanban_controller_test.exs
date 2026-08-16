defmodule CanopyWeb.AgentKanbanControllerTest do
  @moduledoc """
  Endpoint validation for the Agent Kanban controller. The router wiring
  for these routes lives in `wiring/agent-kanban-wiring.md` — once applied,
  these tests exercise the full HTTP path.
  """

  use CanopyWeb.ConnCase, async: false

  import Canopy.Factory

  # ---------------------------------------------------------------------------
  # GET /agent-kanban/board
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/agent-kanban/board" do
    test "returns the four columns", %{conn: conn} do
      _backlog = insert(:task, status: "todo", claimed_by_agent_id: nil)
      _done = insert(:task, status: "done")

      conn = get(conn, "/api/v1/agent-kanban/board")
      body = json_response(conn, 200)

      assert %{"data" => %{"backlog" => _, "claimed" => _, "in_progress" => _, "done" => _}} =
               body
    end

    test "filters by workspace_slug", %{conn: conn} do
      mine = insert(:task, status: "todo", workspace_slug: "mine", claimed_by_agent_id: nil)

      _other =
        insert(:task, status: "todo", workspace_slug: "other", claimed_by_agent_id: nil)

      conn = get(conn, "/api/v1/agent-kanban/board?workspace_slug=mine")
      body = json_response(conn, 200)

      ids = Enum.map(body["data"]["backlog"], & &1["short_id"])
      assert mine.short_id in ids
    end
  end

  # ---------------------------------------------------------------------------
  # POST /agent-kanban/claim
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/agent-kanban/claim" do
    test "200 on first claim, 409 on duplicate", %{conn: conn} do
      task = insert(:task, claimed_by_agent_id: nil)

      conn1 =
        post(conn, "/api/v1/agent-kanban/claim", %{
          agent_slug: "alice",
          task_id: task.short_id
        })

      assert %{"data" => %{"claimed_by_agent_id" => "alice"}} = json_response(conn1, 200)

      conn2 =
        post(build_conn(), "/api/v1/agent-kanban/claim", %{
          agent_slug: "bob",
          task_id: task.short_id
        })

      assert %{"error" => "already_claimed"} = json_response(conn2, 409)
    end

    test "404 when task does not exist", %{conn: conn} do
      conn =
        post(conn, "/api/v1/agent-kanban/claim", %{
          agent_slug: "alice",
          task_id: "T-99999999"
        })

      assert json_response(conn, 404)
    end

    test "400 when agent_slug or task_id is missing", %{conn: conn} do
      conn = post(conn, "/api/v1/agent-kanban/claim", %{})
      assert %{"error" => "missing_params"} = json_response(conn, 400)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /agent-kanban/release/:task_id
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/agent-kanban/release/:task_id" do
    test "clears the claim", %{conn: conn} do
      task =
        insert(:task,
          claimed_by_agent_id: "alice",
          claimed_at: DateTime.utc_now()
        )

      conn = post(conn, "/api/v1/agent-kanban/release/#{task.short_id}")
      body = json_response(conn, 200)

      assert is_nil(body["data"]["claimed_by_agent_id"])
      assert is_nil(body["data"]["claimed_at"])
    end
  end

  # ---------------------------------------------------------------------------
  # POST /agent-kanban/complete/:task_id
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/agent-kanban/complete/:task_id" do
    test "marks task done and records session_id", %{conn: conn} do
      sid = Ecto.UUID.generate()
      task = insert(:task, status: "in_progress")

      conn = post(conn, "/api/v1/agent-kanban/complete/#{task.short_id}", %{session_id: sid})
      body = json_response(conn, 200)

      assert body["data"]["status"] == "done"
      assert body["data"]["session_id"] == sid
    end
  end

  # ---------------------------------------------------------------------------
  # GET /agent-kanban/idle-agents
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/agent-kanban/idle-agents" do
    test "returns hired agents with auto_pickup enabled", %{conn: conn} do
      _hired_idle =
        insert(:agent,
          hired: true,
          slug: "idle-1",
          config: %{"auto_pickup" => true, "capabilities" => ["elixir"]}
        )

      _hired_busy =
        insert(:agent,
          hired: true,
          slug: "busy-1",
          config: %{"auto_pickup" => false}
        )

      conn = get(conn, "/api/v1/agent-kanban/idle-agents")
      body = json_response(conn, 200)

      slugs = Enum.map(body["data"], & &1["slug"])
      assert "idle-1" in slugs
      refute "busy-1" in slugs
    end
  end
end
