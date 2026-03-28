defmodule CanopyWeb.OrganizationControllerTest do
  use CanopyWeb.ConnCase

  import Canopy.TestHelpers
  import Ecto.Query
  alias Canopy.Repo
  alias Canopy.Schemas.OrganizationMembership

  describe "POST /organizations" do
    test "creates org with auto-generated slug and membership", %{conn: conn} do
      user = insert_user()
      _ws = insert_workspace(user)
      conn = authenticated_conn(conn, user)

      conn = post(conn, "/api/v1/organizations", %{name: "Acme Corp"})

      assert conn.status == 201
      body = Jason.decode!(conn.resp_body)
      assert body["organization"]["name"] == "Acme Corp"
      assert body["organization"]["slug"]

      # Membership should be created atomically
      org_id = body["organization"]["id"]

      membership =
        Repo.one(
          from m in OrganizationMembership,
            where: m.organization_id == ^org_id and m.user_id == ^user.id
        )

      assert membership
      assert membership.role == "admin"
    end
  end

  describe "GET /organizations" do
    test "returns only orgs the user is a member of", %{conn: conn} do
      user_a = insert_user()
      user_b = insert_user()
      _ws_a = insert_workspace(user_a)
      _ws_b = insert_workspace(user_b)

      # User A creates an org (gets auto-membership)
      conn_a = authenticated_conn(build_conn(), user_a)
      post(conn_a, "/api/v1/organizations", %{name: "A's Org"})

      # User B creates an org
      conn_b = authenticated_conn(build_conn(), user_b)
      post(conn_b, "/api/v1/organizations", %{name: "B's Org"})

      # User A should only see their org
      conn = authenticated_conn(conn, user_a) |> get("/api/v1/organizations")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      names = Enum.map(body["organizations"], & &1["name"])
      assert "A's Org" in names
      refute "B's Org" in names
    end
  end

  describe "authorization" do
    test "non-member cannot view org details", %{conn: conn} do
      user_a = insert_user()
      user_b = insert_user()
      _ws_a = insert_workspace(user_a)
      _ws_b = insert_workspace(user_b)
      org = insert_organization()

      # Add user_a as member but not user_b
      %OrganizationMembership{}
      |> OrganizationMembership.changeset(%{
        organization_id: org.id,
        user_id: user_a.id,
        role: "admin"
      })
      |> Repo.insert!()

      conn = authenticated_conn(conn, user_b) |> get("/api/v1/organizations/#{org.id}")
      assert conn.status == 403
    end

    test "non-admin cannot update org", %{conn: conn} do
      user = insert_user()
      _ws = insert_workspace(user)
      org = insert_organization()

      # Add as member (not admin)
      %OrganizationMembership{}
      |> OrganizationMembership.changeset(%{
        organization_id: org.id,
        user_id: user.id,
        role: "member"
      })
      |> Repo.insert!()

      conn =
        authenticated_conn(conn, user)
        |> patch("/api/v1/organizations/#{org.id}", %{name: "Hacked"})

      assert conn.status == 403
    end

    test "non-admin cannot delete org", %{conn: conn} do
      user = insert_user()
      _ws = insert_workspace(user)
      org = insert_organization()

      %OrganizationMembership{}
      |> OrganizationMembership.changeset(%{
        organization_id: org.id,
        user_id: user.id,
        role: "member"
      })
      |> Repo.insert!()

      conn =
        authenticated_conn(conn, user)
        |> delete("/api/v1/organizations/#{org.id}")

      assert conn.status == 403
    end
  end
end
