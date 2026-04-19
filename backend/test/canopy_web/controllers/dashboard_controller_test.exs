defmodule CanopyWeb.DashboardControllerTest do
  @moduledoc """
  Controller tests for DashboardController:
    GET /api/v1/dashboard/summary
  """

  use CanopyWeb.ConnCase, async: false

  import Canopy.Factory

  # ---------------------------------------------------------------------------
  # GET /api/v1/dashboard/summary
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/dashboard/summary" do
    test "returns 200 with required keys", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard/summary")
      body = json_response(conn, 200)

      assert is_map(body)
      assert Map.has_key?(body, "active_agents")
      assert Map.has_key?(body, "spend_this_month")
      assert Map.has_key?(body, "recent_sessions")
    end

    test "returns 200 on empty database", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard/summary")
      assert json_response(conn, 200)
    end

    test "active_agents is a list", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard/summary")
      body = json_response(conn, 200)
      assert is_list(body["active_agents"])
    end

    test "spend_this_month has total_usd and by_agent", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard/summary")
      body = json_response(conn, 200)

      assert Map.has_key?(body["spend_this_month"], "total_usd")
      assert Map.has_key?(body["spend_this_month"], "by_agent")
    end

    test "recent_sessions is a list", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard/summary")
      body = json_response(conn, 200)
      assert is_list(body["recent_sessions"])
    end

    test "reflects a running session in active_agents", %{conn: conn} do
      insert(:session, status: "running", started_at: DateTime.utc_now(), agent_slug: "builder")

      conn = get(conn, "/api/v1/dashboard/summary")
      body = json_response(conn, 200)

      assert length(body["active_agents"]) == 1
      assert hd(body["active_agents"])["agent_slug"] == "builder"
    end

    test "reflects completed session cost in spend_this_month", %{conn: conn} do
      insert(
        :session,
        status: "completed",
        started_at: DateTime.add(DateTime.utc_now(), -60),
        completed_at: DateTime.utc_now(),
        cost_usd: Decimal.new("5.00"),
        agent_slug: "builder"
      )

      conn = get(conn, "/api/v1/dashboard/summary")
      body = json_response(conn, 200)

      assert Decimal.equal?(
               Decimal.new(body["spend_this_month"]["total_usd"]),
               Decimal.new("5.00")
             )
    end

    test "returns total_messages key with count", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard/summary")
      body = json_response(conn, 200)

      assert Map.has_key?(body, "total_messages")
      assert Map.has_key?(body["total_messages"], "count")
      assert is_integer(body["total_messages"]["count"])
    end

    test "returns total_sessions key with count", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard/summary")
      body = json_response(conn, 200)

      assert Map.has_key?(body, "total_sessions")
      assert is_integer(body["total_sessions"]["count"])
    end

    test "returns total_tokens key with total field", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard/summary")
      body = json_response(conn, 200)

      assert Map.has_key?(body, "total_tokens")
      assert Map.has_key?(body["total_tokens"], "total")
      assert Map.has_key?(body["total_tokens"], "input")
      assert Map.has_key?(body["total_tokens"], "output")
    end

    test "returns success_rate key with rate field", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard/summary")
      body = json_response(conn, 200)

      assert Map.has_key?(body, "success_rate")
      assert Map.has_key?(body["success_rate"], "rate")
      assert Map.has_key?(body["success_rate"], "completed")
      assert Map.has_key?(body["success_rate"], "failed")
    end

    test "returns sandbox_usage_today with all sub-fields", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard/summary")
      body = json_response(conn, 200)

      widget = body["sandbox_usage_today"]
      assert Map.has_key?(widget, "started")
      assert Map.has_key?(widget, "stopped")
      assert Map.has_key?(widget, "running_now")
      assert Map.has_key?(widget, "avg_lifetime_min")
    end

    test "returns top_tools_30d as a list", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard/summary")
      body = json_response(conn, 200)

      assert is_list(body["top_tools_30d"])
    end

    test "returns peak_hours_30d as 24-element list", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard/summary")
      body = json_response(conn, 200)

      assert is_list(body["peak_hours_30d"])
      assert length(body["peak_hours_30d"]) == 24
    end

    test "returns storage_overview with all required fields", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard/summary")
      body = json_response(conn, 200)

      widget = body["storage_overview"]
      assert Map.has_key?(widget, "workspaces")
      assert Map.has_key?(widget, "files")
      assert Map.has_key?(widget, "file_bytes")
      assert Map.has_key?(widget, "knowledge_bases")
      assert Map.has_key?(widget, "kb_chunks")
      assert Map.has_key?(widget, "buckets")
    end

    test "returns top_agents_by_usage as a list", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard/summary")
      body = json_response(conn, 200)

      assert is_list(body["top_agents_by_usage"])
    end

    test "returns token_usage_by_period with token breakdown", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard/summary")
      body = json_response(conn, 200)

      widget = body["token_usage_by_period"]
      assert Map.has_key?(widget, "total")
      assert Map.has_key?(widget, "input_tokens")
      assert Map.has_key?(widget, "output_tokens")
    end
  end
end
