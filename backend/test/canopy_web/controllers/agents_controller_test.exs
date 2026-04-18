defmodule CanopyWeb.AgentsControllerTest do
  @moduledoc """
  Tests for the AgentsController endpoints:
    GET    /api/v1/agents
    GET    /api/v1/agents/:slug
    POST   /api/v1/agents/:slug/hire
    DELETE /api/v1/agents/:slug/hire
    GET    /api/v1/agents/:slug/heartbeats
  """

  use CanopyWeb.ConnCase, async: false

  import Canopy.Factory

  # ---------------------------------------------------------------------------
  # GET /api/v1/agents
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/agents" do
    test "returns 200 with empty list when no agents exist", %{conn: conn} do
      conn = get(conn, "/api/v1/agents")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns all agents", %{conn: conn} do
      insert(:agent, slug: "my-agent-a")
      insert(:agent, slug: "my-agent-b")
      conn = get(conn, "/api/v1/agents")
      assert %{"data" => data} = json_response(conn, 200)
      slugs = Enum.map(data, & &1["slug"])
      assert "my-agent-a" in slugs
      assert "my-agent-b" in slugs
    end

    test "filters to hired agents only when ?hired=true", %{conn: conn} do
      insert(:agent, slug: "hired-one", hired: true)
      insert(:agent, slug: "not-hired-one", hired: false)
      conn = get(conn, "/api/v1/agents?hired=true")
      assert %{"data" => data} = json_response(conn, 200)
      slugs = Enum.map(data, & &1["slug"])
      assert "hired-one" in slugs
      refute "not-hired-one" in slugs
    end

    test "filters to unhired agents only when ?hired=false", %{conn: conn} do
      insert(:agent, slug: "h2-hired", hired: true)
      insert(:agent, slug: "h2-not-hired", hired: false)
      conn = get(conn, "/api/v1/agents?hired=false")
      assert %{"data" => data} = json_response(conn, 200)
      slugs = Enum.map(data, & &1["slug"])
      refute "h2-hired" in slugs
      assert "h2-not-hired" in slugs
    end

    test "returns all agents when ?hired param is absent", %{conn: conn} do
      insert(:agent, slug: "all-hired", hired: true)
      insert(:agent, slug: "all-not-hired", hired: false)
      conn = get(conn, "/api/v1/agents")
      assert %{"data" => data} = json_response(conn, 200)
      slugs = Enum.map(data, & &1["slug"])
      assert "all-hired" in slugs
      assert "all-not-hired" in slugs
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/agents/:slug
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/agents/:slug" do
    test "returns 200 with agent detail when found", %{conn: conn} do
      insert(:agent, slug: "show-agent", name: "Show Agent")
      conn = get(conn, "/api/v1/agents/show-agent")
      body = json_response(conn, 200)
      assert body["slug"] == "show-agent"
      assert body["name"] == "Show Agent"
      # persona_content is nil when file doesn't exist in test env
      assert Map.has_key?(body, "persona_content")
    end

    test "returns 404 when agent not found", %{conn: conn} do
      conn = get(conn, "/api/v1/agents/no-such-agent-slug")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/agents/:slug/hire
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/agents/:slug/hire" do
    test "sets hired: true and returns updated agent", %{conn: conn} do
      insert(:agent, slug: "hire-me", hired: false)
      conn = post(conn, "/api/v1/agents/hire-me/hire")
      assert %{"data" => agent} = json_response(conn, 200)
      assert agent["slug"] == "hire-me"
      assert agent["hired"] == true
    end

    test "returns 404 for unknown slug", %{conn: conn} do
      conn = post(conn, "/api/v1/agents/ghost-agent/hire")
      assert json_response(conn, 404)
    end

    test "is idempotent — hiring an already-hired agent succeeds", %{conn: conn} do
      insert(:agent, slug: "already-hired", hired: true)
      conn = post(conn, "/api/v1/agents/already-hired/hire")
      assert %{"data" => agent} = json_response(conn, 200)
      assert agent["hired"] == true
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/agents/:slug/hire
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/agents/:slug/hire" do
    test "sets hired: false and returns updated agent", %{conn: conn} do
      insert(:agent, slug: "fire-me", hired: true)
      conn = delete(conn, "/api/v1/agents/fire-me/hire")
      assert %{"data" => agent} = json_response(conn, 200)
      assert agent["slug"] == "fire-me"
      assert agent["hired"] == false
    end

    test "returns 404 for unknown slug", %{conn: conn} do
      conn = delete(conn, "/api/v1/agents/ghost-fire/hire")
      assert json_response(conn, 404)
    end

    test "is idempotent — firing an unhired agent succeeds", %{conn: conn} do
      insert(:agent, slug: "already-fired", hired: false)
      conn = delete(conn, "/api/v1/agents/already-fired/hire")
      assert %{"data" => agent} = json_response(conn, 200)
      assert agent["hired"] == false
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/agents/:slug/heartbeats
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/agents/:slug/heartbeats" do
    test "returns 200 with empty data list when no jobs are scheduled", %{conn: conn} do
      insert(:agent, slug: "hb-no-jobs", hired: false, heartbeat_cron: nil)
      conn = get(conn, "/api/v1/agents/hb-no-jobs/heartbeats")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns 200 with scheduled jobs after hire", %{conn: conn} do
      insert(:agent, slug: "hb-with-jobs", hired: false, heartbeat_cron: "*/5 * * * *")
      # Hire via the API so the hook fires
      post(conn, "/api/v1/agents/hb-with-jobs/hire")

      conn2 = get(conn, "/api/v1/agents/hb-with-jobs/heartbeats")
      assert %{"data" => jobs} = json_response(conn2, 200)
      assert length(jobs) >= 1
      [job | _] = jobs
      assert Map.has_key?(job, "id")
      assert Map.has_key?(job, "scheduled_at")
      assert job["args"]["agent_slug"] == "hb-with-jobs"
    end

    test "returns 404 for unknown agent slug", %{conn: conn} do
      conn = get(conn, "/api/v1/agents/no-such-hb-agent/heartbeats")
      assert json_response(conn, 404)
    end

    test "returns at most 5 jobs", %{conn: conn} do
      insert(:agent, slug: "hb-many", hired: false, heartbeat_cron: "*/5 * * * *")

      # Insert 7 scheduled jobs directly
      Enum.each(1..7, fn i ->
        {:ok, _} =
          Canopy.Heartbeat.Worker.new(
            %{"agent_slug" => "hb-many", "wake_reason" => "heartbeat"},
            scheduled_at: DateTime.add(DateTime.utc_now(), i * 60, :second)
          )
          |> Oban.insert()
      end)

      conn = get(conn, "/api/v1/agents/hb-many/heartbeats")
      assert %{"data" => jobs} = json_response(conn, 200)
      assert length(jobs) <= 5
    end
  end
end
