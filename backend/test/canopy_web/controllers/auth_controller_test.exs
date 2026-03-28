defmodule CanopyWeb.AuthControllerTest do
  use CanopyWeb.ConnCase

  import Canopy.TestHelpers

  describe "POST /auth/register" do
    test "creates user, organization, and workspace", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/register", %{
          name: "New User",
          email: "new-#{unique_id()}@canopy.test",
          password: "securepass123"
        })

      assert conn.status == 201
      body = Jason.decode!(conn.resp_body)
      assert body["token"]
      assert body["user"]["name"] == "New User"
      assert body["user"]["id"]
      assert body["workspace"]["id"]
      assert body["workspace"]["name"]
    end

    test "rejects short password", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/register", %{
          name: "User",
          email: "short-#{unique_id()}@canopy.test",
          password: "short"
        })

      assert conn.status == 422
    end

    test "rejects duplicate email", %{conn: conn} do
      email = "dup-#{unique_id()}@canopy.test"

      post(conn, "/api/v1/auth/register", %{
        name: "User 1",
        email: email,
        password: "securepass123"
      })

      conn =
        post(conn, "/api/v1/auth/register", %{
          name: "User 2",
          email: email,
          password: "securepass123"
        })

      assert conn.status == 422
    end

    test "rejects missing fields", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/register", %{email: "x@y.com"})
      assert conn.status == 400
    end

    test "rejects invalid email format", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/register", %{
          name: "User",
          email: "not-an-email",
          password: "securepass123"
        })

      assert conn.status == 422
    end
  end

  describe "POST /auth/login" do
    test "returns token for valid credentials", %{conn: conn} do
      email = "login-#{unique_id()}@canopy.test"
      insert_user(%{email: email, password: "testpassword123"})

      conn =
        post(conn, "/api/v1/auth/login", %{
          email: email,
          password: "testpassword123"
        })

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["token"]
      assert body["user"]["email"] == email
    end

    test "rejects invalid password", %{conn: conn} do
      email = "bad-#{unique_id()}@canopy.test"
      insert_user(%{email: email, password: "testpassword123"})

      conn =
        post(conn, "/api/v1/auth/login", %{
          email: email,
          password: "wrongpassword"
        })

      assert conn.status == 401
    end

    test "rejects nonexistent user", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/login", %{
          email: "nobody@canopy.test",
          password: "anything123"
        })

      assert conn.status == 401
    end
  end

  describe "GET /auth/status" do
    test "returns authenticated: true with valid token", %{conn: conn} do
      user = insert_user()
      conn = authenticated_conn(conn, user) |> get("/api/v1/auth/status")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["authenticated"] == true
      assert body["user"]["id"] == user.id
    end

    test "returns authenticated: false without token", %{conn: conn} do
      conn = get(conn, "/api/v1/auth/status")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["authenticated"] == false
    end
  end

  defp unique_id, do: :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
end
