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
  end
end
