defmodule CanopyWeb.AgentControllerTest do
  use CanopyWeb.ConnCase

  import Canopy.TestHelpers

  describe "GET /agents" do
    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/v1/agents")
      assert conn.status == 401
    end

    test "returns only agents from user's workspaces", %{conn: conn} do
      user_a = insert_user()
      user_b = insert_user()
      ws_a = insert_workspace(user_a)
      ws_b = insert_workspace(user_b)
      agent_a = insert_agent(ws_a, %{name: "Agent A"})
      _agent_b = insert_agent(ws_b, %{name: "Agent B"})

      conn = authenticated_conn(conn, user_a) |> get("/api/v1/agents")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      names = Enum.map(body["agents"], & &1["name"])
      assert "Agent A" in names
      refute "Agent B" in names
    end

    test "returns empty list for user with no workspaces", %{conn: conn} do
      user = insert_user(%{role: "member"})

      conn = authenticated_conn(conn, user) |> get("/api/v1/agents")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["agents"] == []
    end
  end

  describe "pagination" do
    test "handles non-numeric limit gracefully", %{conn: conn} do
      user = insert_user()
      _ws = insert_workspace(user)

      conn =
        authenticated_conn(conn, user)
        |> get("/api/v1/agents?limit=abc&offset=xyz")

      # Should not crash with 500 — returns 200 with default pagination
      assert conn.status == 200
    end
  end
end
