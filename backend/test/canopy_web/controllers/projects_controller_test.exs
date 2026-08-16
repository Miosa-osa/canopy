defmodule CanopyWeb.ProjectsControllerTest do
  @moduledoc "Controller tests for the Projects API."

  use CanopyWeb.ConnCase, async: true

  import Canopy.Factory

  # ---------------------------------------------------------------------------
  # GET /api/v1/projects
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/projects" do
    test "200 returns project list", %{conn: conn} do
      insert(:project, workspace_slug: "ctrl-proj-ws")
      conn = get(conn, "/api/v1/projects", workspace_slug: "ctrl-proj-ws")
      body = json_response(conn, 200)
      assert is_list(body["data"])
      assert body["count"] >= 1
    end

    test "200 returns empty list when none match", %{conn: conn} do
      conn = get(conn, "/api/v1/projects", workspace_slug: "no-such-ws-xyz")
      body = json_response(conn, 200)
      assert body["data"] == []
      assert body["count"] == 0
    end

    test "200 filters by status", %{conn: conn} do
      insert(:project, workspace_slug: "stat-ws", status: "paused")
      insert(:project, workspace_slug: "stat-ws", status: "active")
      conn = get(conn, "/api/v1/projects", workspace_slug: "stat-ws", status: "paused")
      body = json_response(conn, 200)
      assert Enum.all?(body["data"], &(&1["status"] == "paused"))
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/projects
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/projects" do
    test "201 creates and returns project", %{conn: conn} do
      conn =
        post(conn, "/api/v1/projects", %{
          name: "Canopy Launch",
          workspace_slug: "default"
        })

      body = json_response(conn, 201)
      assert body["data"]["name"] == "Canopy Launch"
      assert body["data"]["slug"] == "canopy-launch"
      assert body["data"]["status"] == "active"
    end

    test "201 accepts explicit slug", %{conn: conn} do
      conn =
        post(conn, "/api/v1/projects", %{
          name: "MIOSA v2",
          slug: "miosa-v2",
          workspace_slug: "default",
          color: "#7bd88f",
          icon: "FolderKanban"
        })

      body = json_response(conn, 201)
      assert body["data"]["slug"] == "miosa-v2"
      assert body["data"]["color"] == "#7bd88f"
    end

    test "422 when name missing", %{conn: conn} do
      conn = post(conn, "/api/v1/projects", %{workspace_slug: "ws"})
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/projects/:slug
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/projects/:slug" do
    test "200 returns project by slug", %{conn: conn} do
      project = insert(:project)
      conn = get(conn, "/api/v1/projects/#{project.slug}")
      body = json_response(conn, 200)
      assert body["data"]["slug"] == project.slug
      assert body["data"]["name"] == project.name
    end

    test "404 for unknown slug", %{conn: conn} do
      conn = get(conn, "/api/v1/projects/no-such-project")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/projects/:slug
  # ---------------------------------------------------------------------------

  describe "PATCH /api/v1/projects/:slug" do
    test "200 updates the project", %{conn: conn} do
      project = insert(:project, status: "active")
      conn = patch(conn, "/api/v1/projects/#{project.slug}", %{status: "paused"})
      body = json_response(conn, 200)
      assert body["data"]["status"] == "paused"
    end

    test "404 for unknown slug", %{conn: conn} do
      conn = patch(conn, "/api/v1/projects/no-such", %{status: "paused"})
      assert json_response(conn, 404)
    end

    test "422 for invalid status", %{conn: conn} do
      project = insert(:project)
      conn = patch(conn, "/api/v1/projects/#{project.slug}", %{status: "deleted"})
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/projects/:slug/archive
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/projects/:slug/archive" do
    test "200 archives the project", %{conn: conn} do
      project = insert(:project, status: "active")
      conn = post(conn, "/api/v1/projects/#{project.slug}/archive")
      body = json_response(conn, 200)
      assert body["data"]["status"] == "archived"
      assert body["data"]["archived_at"] != nil
    end

    test "404 for unknown slug", %{conn: conn} do
      conn = post(conn, "/api/v1/projects/ghost/archive")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/projects/:slug/unarchive
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/projects/:slug/unarchive" do
    test "200 restores archived project", %{conn: conn} do
      now = DateTime.truncate(DateTime.utc_now(), :second)
      project = insert(:project, status: "archived", archived_at: now)
      conn = post(conn, "/api/v1/projects/#{project.slug}/unarchive")
      body = json_response(conn, 200)
      assert body["data"]["status"] == "active"
      assert body["data"]["archived_at"] == nil
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/projects/:slug
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/projects/:slug" do
    test "204 deletes the project", %{conn: conn} do
      project = insert(:project)
      conn = delete(conn, "/api/v1/projects/#{project.slug}")
      assert response(conn, 204) == ""
    end

    test "404 for unknown slug", %{conn: conn} do
      conn = delete(conn, "/api/v1/projects/ghost-proj")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/projects/:slug/summary
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/projects/:slug/summary" do
    test "200 returns project with counts", %{conn: conn} do
      project = insert(:project)
      conn = get(conn, "/api/v1/projects/#{project.slug}/summary")
      body = json_response(conn, 200)
      data = body["data"]
      assert data["project"]["slug"] == project.slug
      assert is_integer(data["issues_count"])
      assert is_integer(data["tasks_count"])
      assert is_integer(data["goals_count"])
      assert is_integer(data["sessions_count"])
    end

    test "404 for unknown slug", %{conn: conn} do
      conn = get(conn, "/api/v1/projects/ghost/summary")
      assert json_response(conn, 404)
    end
  end
end
