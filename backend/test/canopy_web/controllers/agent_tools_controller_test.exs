defmodule CanopyWeb.AgentToolsControllerTest do
  @moduledoc """
  Controller tests for the agent orchestration tools endpoint.

    POST /api/v1/agents/tools/:tool_name
    GET  /api/v1/agents/:slug/tool-calls

  Covers: 200 ok, 202 pending_review, 403 unauthorized, 422 error, 404 missing session.
  """

  use CanopyWeb.ConnCase, async: false

  import Canopy.Factory

  alias Canopy.Agents.ToolCall
  alias Canopy.Repo

  setup do
    # Reset the governance RuleCache before each test to prevent cross-test
    # contamination from the pending_review test (which inserts a DB rule).
    Canopy.Governance.RuleCache.invalidate()
    :ok
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp capable_agent_and_session do
    agent =
      insert(:agent,
        slug: "ctrl-tool-agent-#{System.unique_integer([:positive])}",
        hired: true,
        config: %{
          "capabilities" => ["read_workspace", "write_tasks", "write_issues", "spawn_sessions"]
        }
      )

    session =
      insert(:session,
        agent_slug: agent.slug,
        workspace_slug: "default",
        status: "running"
      )

    {agent, session}
  end

  defp readonly_agent_and_session do
    agent =
      insert(:agent,
        slug: "ctrl-readonly-agent-#{System.unique_integer([:positive])}",
        hired: true,
        config: %{}
      )

    session = insert(:session, agent_slug: agent.slug, status: "running")
    {agent, session}
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/agents/tools/:tool_name — happy path
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/agents/tools/canopy.create_task" do
    test "200 with created task when agent has write_tasks", %{conn: conn} do
      {_agent, session} = capable_agent_and_session()

      conn =
        post(conn, "/api/v1/agents/tools/canopy.create_task", %{
          session_id: session.id,
          params: %{title: "Controller test task", workspace_slug: "default"}
        })

      body = json_response(conn, 200)
      assert body["ok"] == true
      assert body["result"]["task"]["title"] == "Controller test task"
    end
  end

  describe "POST /api/v1/agents/tools/canopy.list_tasks" do
    test "200 with tasks list for read-capable agent", %{conn: conn} do
      {_agent, session} = capable_agent_and_session()

      conn =
        post(conn, "/api/v1/agents/tools/canopy.list_tasks", %{
          session_id: session.id,
          params: %{workspace_slug: "default"}
        })

      body = json_response(conn, 200)
      assert body["ok"] == true
      assert is_list(body["result"]["tasks"])
    end
  end

  # ---------------------------------------------------------------------------
  # 403 — missing capability
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/agents/tools/canopy.create_task — forbidden" do
    test "403 when agent has no write_tasks capability", %{conn: conn} do
      {_agent, session} = readonly_agent_and_session()

      conn =
        post(conn, "/api/v1/agents/tools/canopy.create_task", %{
          session_id: session.id,
          params: %{title: "should fail"}
        })

      body = json_response(conn, 403)
      assert body["ok"] == false
      assert String.contains?(body["error"], "lacks capability")
    end
  end

  # ---------------------------------------------------------------------------
  # 422 — validation error
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/agents/tools/canopy.create_task — missing title" do
    test "422 when title param is missing", %{conn: conn} do
      {_agent, session} = capable_agent_and_session()

      conn =
        post(conn, "/api/v1/agents/tools/canopy.create_task", %{
          session_id: session.id,
          params: %{}
        })

      body = json_response(conn, 422)
      assert body["ok"] == false
      assert is_binary(body["error"])
    end
  end

  # ---------------------------------------------------------------------------
  # 422 — missing session_id
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/agents/tools/canopy.list_tasks — no session_id" do
    test "422 when session_id is absent", %{conn: conn} do
      conn =
        post(conn, "/api/v1/agents/tools/canopy.list_tasks", %{
          params: %{}
        })

      body = json_response(conn, 422)
      assert body["ok"] == false
      assert body["error"] == "missing session_id"
    end
  end

  # ---------------------------------------------------------------------------
  # 202 — governance pending_review (requires a matching governance rule)
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/agents/tools — pending_review" do
    test "202 with review_id when governance rule blocks the tool", %{conn: conn} do
      # Insert a requires_review rule matching canopy.create_task for all agents
      alias Canopy.Governance.Rule

      {:ok, _rule} =
        %Rule{}
        |> Rule.changeset(%{
          name: "Block create_task in test #{System.unique_integer()}",
          action: "require_review",
          priority: 99,
          enabled: true,
          conditions: %{"match" => "tool_call", "tool_names" => ["canopy.create_task"]}
        })
        |> Canopy.Repo.insert()

      # Invalidate rule cache so the new rule is picked up
      Canopy.Governance.RuleCache.invalidate()

      {_agent, session} = capable_agent_and_session()

      conn =
        post(conn, "/api/v1/agents/tools/canopy.create_task", %{
          session_id: session.id,
          params: %{title: "pending task", workspace_slug: "default"}
        })

      body = json_response(conn, 202)
      assert body["ok"] == false
      assert body["pending_review"] == true
      assert is_binary(body["review_id"])
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/agents/:slug/tool-calls
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/agents/:slug/tool-calls" do
    test "200 with empty list when no calls recorded", %{conn: conn} do
      agent = insert(:agent, slug: "no-calls-agent-#{System.unique_integer([:positive])}")

      conn = get(conn, "/api/v1/agents/#{agent.slug}/tool-calls")
      body = json_response(conn, 200)

      assert body["data"] == []
    end

    test "200 with tool_calls for the agent", %{conn: conn} do
      {agent, session} = capable_agent_and_session()

      # Create a tool_call row directly
      Repo.insert!(%ToolCall{
        session_id: session.id,
        agent_id: agent.slug,
        tool_name: "canopy.list_tasks",
        params: %{},
        status: "ok",
        result: %{tasks: [], count: 0},
        inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      conn = get(conn, "/api/v1/agents/#{agent.slug}/tool-calls")
      body = json_response(conn, 200)

      assert [call | _] = body["data"]
      assert call["tool_name"] == "canopy.list_tasks"
      assert call["agent_id"] == agent.slug
      assert call["status"] == "ok"
    end
  end
end
