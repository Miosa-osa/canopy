defmodule CanopyWeb.Plugs.GovernanceTest do
  use CanopyWeb.ConnCase

  import Canopy.TestHelpers

  setup do
    # Ensure governance gates are disabled by default
    Application.put_env(:canopy, :governance_gates, %{})
    on_exit(fn -> Application.delete_env(:canopy, :governance_gates) end)
  end

  describe "when governance gates are disabled" do
    test "POST /spawn passes through", %{conn: conn} do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)
      conn = authenticated_conn(conn, user)

      conn = post(conn, "/api/v1/spawn", %{agent_id: agent.id})

      # Should not get 202 (pending_approval) — either succeeds or fails for other reasons
      refute conn.status == 202
    end
  end

  describe "when spawn_agent gate is enabled" do
    setup do
      Application.put_env(:canopy, :governance_gates, %{spawn_agent: true})
      :ok
    end

    test "POST /spawn returns 202 pending_approval", %{conn: conn} do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)
      conn = authenticated_conn(conn, user)

      conn = post(conn, "/api/v1/spawn", %{agent_id: agent.id})

      assert conn.status == 202
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "pending_approval"
      assert body["approval"]["status"] == "pending"
    end
  end

  describe "when delete_agent gate is enabled" do
    setup do
      Application.put_env(:canopy, :governance_gates, %{delete_agent: true})
      :ok
    end

    test "DELETE /agents/:id returns 202 pending_approval", %{conn: conn} do
      user = insert_user()
      workspace = insert_workspace(user)
      agent = insert_agent(workspace)
      conn = authenticated_conn(conn, user)

      conn = delete(conn, "/api/v1/agents/#{agent.id}")

      assert conn.status == 202
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "pending_approval"
    end
  end

  describe "when budget_override gate is enabled" do
    setup do
      Application.put_env(:canopy, :governance_gates, %{budget_override: true})
      :ok
    end

    test "POST /budgets/incidents/:id/resolve returns 202 pending_approval", %{conn: conn} do
      user = insert_user()
      _workspace = insert_workspace(user)
      conn = authenticated_conn(conn, user)

      fake_id = Ecto.UUID.generate()
      conn = post(conn, "/api/v1/budgets/incidents/#{fake_id}/resolve")

      assert conn.status == 202
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "pending_approval"
    end
  end

  describe "non-gated endpoints pass through" do
    setup do
      Application.put_env(:canopy, :governance_gates, %{spawn_agent: true, delete_agent: true})
      :ok
    end

    test "GET /health is not gated", %{conn: conn} do
      conn = get(conn, "/api/v1/health")
      assert conn.status == 200
    end

    test "GET /agents is not gated", %{conn: conn} do
      user = insert_user()
      _workspace = insert_workspace(user)
      conn = authenticated_conn(conn, user)

      conn = get(conn, "/api/v1/agents")
      # Should not be 202
      refute conn.status == 202
    end
  end
end
