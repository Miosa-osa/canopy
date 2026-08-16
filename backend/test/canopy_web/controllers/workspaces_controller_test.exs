defmodule CanopyWeb.WorkspacesControllerTest do
  @moduledoc """
  Tests for WorkspacesController.
  """

  use CanopyWeb.ConnCase, async: true

  alias Canopy.Repo
  alias Canopy.Workspaces.Workspace

  defp tmp_dir do
    dir =
      System.tmp_dir!()
      |> Path.join("canopy-ctrl-test-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    dir
  end

  defp insert_workspace(overrides) do
    attrs =
      Map.merge(
        %{
          slug: "ws-#{System.unique_integer([:positive])}",
          name: "Test Workspace",
          root_path: tmp_dir()
        },
        overrides
      )

    {:ok, ws} = Repo.insert(Workspace.changeset(%Workspace{}, attrs))
    ws
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/workspaces" do
    test "returns 200 with empty list", %{conn: conn} do
      conn = get(conn, "/api/v1/workspaces")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns list of workspaces", %{conn: conn} do
      insert_workspace(%{slug: "list-ws"})
      conn = get(conn, "/api/v1/workspaces")
      assert %{"data" => data} = json_response(conn, 200)
      assert data != []
    end

    test "does not return soft-deleted workspaces", %{conn: conn} do
      ws = insert_workspace(%{slug: "deleted-list-ws"})
      Canopy.Workspaces.delete(ws.slug)
      conn = get(conn, "/api/v1/workspaces")
      assert %{"data" => data} = json_response(conn, 200)
      slugs = Enum.map(data, & &1["slug"])
      refute "deleted-list-ws" in slugs
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces/templates
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/workspaces/templates" do
    test "returns 200 with 4 templates", %{conn: conn} do
      conn = get(conn, "/api/v1/workspaces/templates")
      assert %{"data" => templates} = json_response(conn, 200)
      assert length(templates) == 4
    end

    test "templates include expected slugs", %{conn: conn} do
      conn = get(conn, "/api/v1/workspaces/templates")
      assert %{"data" => templates} = json_response(conn, 200)
      slugs = Enum.map(templates, & &1["slug"])
      assert "sales-engine" in slugs
      assert "dev-shop" in slugs
      assert "content-factory" in slugs
      assert "blank" in slugs
    end

    test "each template has slug, name, description, files", %{conn: conn} do
      conn = get(conn, "/api/v1/workspaces/templates")
      assert %{"data" => templates} = json_response(conn, 200)

      for tpl <- templates do
        assert is_binary(tpl["slug"])
        assert is_binary(tpl["name"])
        assert is_binary(tpl["description"])
        assert is_list(tpl["files"])
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces/:slug
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/workspaces/:slug" do
    test "returns 200 with workspace data", %{conn: conn} do
      ws = insert_workspace(%{slug: "show-ws"})
      conn = get(conn, "/api/v1/workspaces/show-ws")
      assert %{"data" => data} = json_response(conn, 200)
      assert data["slug"] == ws.slug
      assert data["name"] == ws.name
    end

    test "returns 404 when not found", %{conn: conn} do
      conn = get(conn, "/api/v1/workspaces/no-such-slug")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/workspaces
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/workspaces" do
    test "creates a workspace and returns 201", %{conn: conn} do
      dir = tmp_dir()

      conn =
        post(conn, "/api/v1/workspaces", %{
          "slug" => "post-ws",
          "name" => "Posted Workspace",
          "root_path" => dir
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert data["slug"] == "post-ws"
    end

    test "creates SYSTEM.md on disk", %{conn: conn} do
      dir = tmp_dir()

      post(conn, "/api/v1/workspaces", %{
        "slug" => "disk-ws",
        "name" => "Disk Workspace",
        "root_path" => dir
      })

      assert File.exists?(Path.join(dir, "SYSTEM.md"))
    end

    test "creates from template when template_slug provided", %{conn: conn} do
      dir = tmp_dir()

      conn =
        post(conn, "/api/v1/workspaces", %{
          "slug" => "tpl-ctrl-ws",
          "root_path" => dir,
          "template_slug" => "blank"
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert data["template"] == "blank"
      assert File.exists?(Path.join(dir, "SYSTEM.md"))
      assert File.exists?(Path.join(dir, "company.yaml"))
    end

    test "returns 422 for invalid attrs", %{conn: conn} do
      conn = post(conn, "/api/v1/workspaces", %{})
      assert json_response(conn, 422)
    end

    test "returns 422 for unknown template_slug", %{conn: conn} do
      dir = tmp_dir()

      conn =
        post(conn, "/api/v1/workspaces", %{
          "slug" => "bad-tpl-ws",
          "root_path" => dir,
          "template_slug" => "nonexistent-template"
        })

      assert %{"error" => "unknown_template"} = json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/workspaces/:slug
  # ---------------------------------------------------------------------------

  describe "PATCH /api/v1/workspaces/:slug" do
    test "updates root_path with a valid existing directory and returns 200", %{conn: conn} do
      ws = insert_workspace(%{slug: "patch-ws"})
      new_dir = tmp_dir()

      conn =
        patch(conn, "/api/v1/workspaces/#{ws.slug}", %{"root_path" => new_dir})

      assert %{"data" => data} = json_response(conn, 200)
      assert data["root_path"] == new_dir
      assert data["slug"] == ws.slug
    end

    test "persists the updated root_path in the database", %{conn: conn} do
      ws = insert_workspace(%{slug: "patch-persist-ws"})
      new_dir = tmp_dir()

      patch(conn, "/api/v1/workspaces/#{ws.slug}", %{"root_path" => new_dir})

      {:ok, reloaded} = Canopy.Workspaces.get_by_slug(ws.slug)
      assert reloaded.root_path == new_dir
    end

    test "returns 422 when root_path does not exist on disk", %{conn: conn} do
      ws = insert_workspace(%{slug: "patch-bad-path-ws"})

      conn =
        patch(conn, "/api/v1/workspaces/#{ws.slug}", %{
          "root_path" => "/this/path/absolutely/does/not/exist/ever"
        })

      assert %{"error" => "root_path_not_found"} = json_response(conn, 422)
    end

    test "returns 404 when workspace slug is unknown", %{conn: conn} do
      conn = patch(conn, "/api/v1/workspaces/no-such-slug", %{"root_path" => tmp_dir()})
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/workspaces/:slug
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/workspaces/:slug" do
    test "soft-deletes workspace and returns 204", %{conn: conn} do
      ws = insert_workspace(%{slug: "deletable-ws"})
      conn = delete(conn, "/api/v1/workspaces/#{ws.slug}")
      assert response(conn, 204) == ""

      # Verify soft-deleted
      assert {:error, :not_found} = Canopy.Workspaces.get_by_slug(ws.slug)
    end

    test "returns 404 for nonexistent slug", %{conn: conn} do
      conn = delete(conn, "/api/v1/workspaces/no-such-slug")
      assert json_response(conn, 404)
    end

    test "does not delete filesystem", %{conn: conn} do
      dir = tmp_dir()
      ws = insert_workspace(%{slug: "fs-safe-ws", root_path: dir})
      File.write!(Path.join(dir, "important.md"), "keep me")

      delete(conn, "/api/v1/workspaces/#{ws.slug}")

      assert File.exists?(Path.join(dir, "important.md"))
    end
  end
end
