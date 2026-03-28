defmodule CanopyWeb.UserControllerTest do
  use CanopyWeb.ConnCase

  import Canopy.TestHelpers

  describe "GET /users" do
    test "admin can list all users", %{conn: conn} do
      admin = insert_user(%{role: "admin"})
      _ws = insert_workspace(admin)

      conn = authenticated_conn(conn, admin) |> get("/api/v1/users")
      assert conn.status == 200
    end

    test "non-admin gets 403", %{conn: conn} do
      member = insert_user(%{role: "member"})
      _ws = insert_workspace(member)

      conn = authenticated_conn(conn, member) |> get("/api/v1/users")
      assert conn.status == 403
    end
  end

  describe "PATCH /users/:id" do
    test "user can update their own profile", %{conn: conn} do
      user = insert_user(%{role: "member"})
      _ws = insert_workspace(user)

      conn =
        authenticated_conn(conn, user)
        |> patch("/api/v1/users/#{user.id}", %{name: "Updated Name"})

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["user"]["name"] == "Updated Name"
    end

    test "user cannot update another user's profile", %{conn: conn} do
      user_a = insert_user(%{role: "member"})
      user_b = insert_user(%{role: "member"})
      _ws_a = insert_workspace(user_a)
      _ws_b = insert_workspace(user_b)

      conn =
        authenticated_conn(conn, user_a)
        |> patch("/api/v1/users/#{user_b.id}", %{name: "Hacked"})

      assert conn.status == 403
    end

    test "admin can update any user", %{conn: conn} do
      admin = insert_user(%{role: "admin"})
      member = insert_user(%{role: "member"})
      _ws = insert_workspace(admin)

      conn =
        authenticated_conn(conn, admin)
        |> patch("/api/v1/users/#{member.id}", %{name: "Admin Updated"})

      assert conn.status == 200
    end
  end

  describe "DELETE /users/:id" do
    test "user cannot delete another user", %{conn: conn} do
      user_a = insert_user(%{role: "member"})
      user_b = insert_user(%{role: "member"})
      _ws_a = insert_workspace(user_a)
      _ws_b = insert_workspace(user_b)

      conn =
        authenticated_conn(conn, user_a)
        |> delete("/api/v1/users/#{user_b.id}")

      assert conn.status == 403
    end
  end
end
