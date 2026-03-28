defmodule CanopyWeb.WorkspaceControllerTest do
  use CanopyWeb.ConnCase

  import Canopy.TestHelpers

  describe "GET /workspaces" do
    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/v1/workspaces")
      assert conn.status == 401
    end

    test "returns only the current user's workspaces", %{conn: conn} do
      user_a = insert_user()
      user_b = insert_user()
      ws_a = insert_workspace(user_a, %{name: "A's Workspace"})
      _ws_b = insert_workspace(user_b, %{name: "B's Workspace"})

      conn = authenticated_conn(conn, user_a) |> get("/api/v1/workspaces")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      ids = Enum.map(body["workspaces"], & &1["id"])
      assert ws_a.id in ids
      refute Enum.any?(body["workspaces"], &(&1["name"] == "B's Workspace"))
    end
  end

  describe "POST /workspaces" do
    test "creates workspace with path field", %{conn: conn} do
      user = insert_user()
      conn = authenticated_conn(conn, user)

      conn =
        post(conn, "/api/v1/workspaces", %{
          name: "My Workspace",
          path: "/tmp/test-workspace"
        })

      assert conn.status == 201
      body = Jason.decode!(conn.resp_body)
      assert body["workspace"]["name"] == "My Workspace"
      assert body["workspace"]["id"]
    end

    test "creates workspace when directory is sent instead of path", %{conn: conn} do
      user = insert_user()
      conn = authenticated_conn(conn, user)

      conn =
        post(conn, "/api/v1/workspaces", %{
          name: "Dir Workspace",
          directory: "/tmp/dir-workspace"
        })

      assert conn.status == 201
      body = Jason.decode!(conn.resp_body)
      assert body["workspace"]["name"] == "Dir Workspace"
    end
  end

  describe "POST /workspaces/:id/activate" do
    test "does not archive other users' workspaces", %{conn: conn} do
      user_a = insert_user()
      user_b = insert_user()
      ws_a1 = insert_workspace(user_a, %{name: "A1"})
      ws_a2 = insert_workspace(user_a, %{name: "A2"})
      ws_b = insert_workspace(user_b, %{name: "B1", status: "active"})

      conn =
        authenticated_conn(conn, user_a)
        |> post("/api/v1/workspaces/#{ws_a1.id}/activate")

      assert conn.status == 200

      # User B's workspace should still be active
      ws_b_after = Canopy.Repo.get!(Canopy.Schemas.Workspace, ws_b.id)
      assert ws_b_after.status == "active"

      # User A's other workspace should be archived
      ws_a2_after = Canopy.Repo.get!(Canopy.Schemas.Workspace, ws_a2.id)
      assert ws_a2_after.status == "archived"
    end

    test "rejects activating another user's workspace", %{conn: conn} do
      user_a = insert_user()
      user_b = insert_user()
      ws_b = insert_workspace(user_b)

      conn =
        authenticated_conn(conn, user_a)
        |> post("/api/v1/workspaces/#{ws_b.id}/activate")

      assert conn.status == 403
    end
  end
end
