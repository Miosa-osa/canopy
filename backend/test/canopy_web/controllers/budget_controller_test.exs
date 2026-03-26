defmodule CanopyWeb.BudgetControllerTest do
  use CanopyWeb.ConnCase

  import Canopy.TestHelpers

  describe "GET /budgets" do
    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/v1/budgets")
      assert conn.status == 401
    end

    test "returns empty list when no policies exist", %{conn: conn} do
      user = insert_user()
      _workspace = insert_workspace(user)
      conn = authenticated_conn(conn, user)

      conn = get(conn, "/api/v1/budgets")
      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["policies"] == []
    end

    test "returns existing budget policies", %{conn: conn} do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)
      insert_budget_policy("agent", agent.id, %{monthly_limit_cents: 50_000})
      conn = authenticated_conn(conn, user)

      conn = get(conn, "/api/v1/budgets")
      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["policies"]) >= 1
    end
  end

  describe "PUT /budgets/:scope_type/:scope_id" do
    test "creates a new budget policy", %{conn: conn} do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)
      conn = authenticated_conn(conn, user)

      conn =
        put(conn, "/api/v1/budgets/agent/#{agent.id}", %{
          monthly_limit_cents: 25_000,
          warning_threshold_pct: 75,
          hard_stop: true
        })

      assert conn.status in [200, 201]
      body = Jason.decode!(conn.resp_body)
      assert body["budget"]["monthly_limit_cents"] == 25_000
      assert body["budget"]["warning_threshold_pct"] == 75
    end

    test "updates existing budget policy (upsert)", %{conn: conn} do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)
      insert_budget_policy("agent", agent.id, %{monthly_limit_cents: 10_000})
      conn = authenticated_conn(conn, user)

      conn =
        put(conn, "/api/v1/budgets/agent/#{agent.id}", %{
          monthly_limit_cents: 50_000
        })

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["budget"]["monthly_limit_cents"] == 50_000
    end
  end

  describe "GET /budgets/incidents" do
    test "returns budget incidents", %{conn: conn} do
      user = insert_user()
      _workspace = insert_workspace(user)
      conn = authenticated_conn(conn, user)

      conn = get(conn, "/api/v1/budgets/incidents")
      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert is_list(body["incidents"])
    end
  end

  describe "GET /costs/summary" do
    test "returns cost summary", %{conn: conn} do
      user = insert_user()
      _workspace = insert_workspace(user)
      conn = authenticated_conn(conn, user)

      conn = get(conn, "/api/v1/costs/summary")
      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert Map.has_key?(body, "today_cents")
      assert Map.has_key?(body, "month_cents")
    end

    test "reflects recorded costs", %{conn: conn} do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)
      insert_cost_event(agent, %{cost_cents: 500})
      insert_cost_event(agent, %{cost_cents: 300})
      conn = authenticated_conn(conn, user)

      conn = get(conn, "/api/v1/costs/summary?workspace_id=#{workspace.id}")
      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["today_cents"] >= 800
    end
  end

  describe "GET /costs/by-agent" do
    test "returns per-agent cost breakdown", %{conn: conn} do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)
      insert_cost_event(agent, %{cost_cents: 200})
      conn = authenticated_conn(conn, user)

      conn = get(conn, "/api/v1/costs/by-agent?workspace_id=#{workspace.id}")
      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert is_list(body["agents"])
    end
  end
end
