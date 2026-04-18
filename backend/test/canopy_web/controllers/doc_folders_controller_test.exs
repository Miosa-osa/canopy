defmodule CanopyWeb.DocFoldersControllerTest do
  @moduledoc """
  Controller tests for DocFoldersController endpoints:
    GET    /api/v1/doc-folders?workspace=slug   — flat list
    GET    /api/v1/doc-folders/tree             — hierarchical tree
    POST   /api/v1/doc-folders                  — create folder
    PATCH  /api/v1/doc-folders/:id              — update folder
    DELETE /api/v1/doc-folders/:id              — archive folder
  """

  use CanopyWeb.ConnCase, async: true

  alias Canopy.Docs

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp ws, do: "test-ws-#{System.unique_integer([:positive])}"

  defp create_folder!(workspace_slug, overrides \\ %{}) do
    {:ok, folder} =
      Docs.create_folder(
        Map.merge(%{"name" => "My Folder", "workspace_slug" => workspace_slug}, overrides)
      )

    folder
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/doc-folders
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/doc-folders" do
    test "returns 200 with folders for workspace", %{conn: conn} do
      workspace = ws()
      folder = create_folder!(workspace)
      conn = get(conn, "/api/v1/doc-folders", workspace: workspace)
      assert %{"data" => data} = json_response(conn, 200)
      assert Enum.any?(data, &(&1["id"] == folder.id))
    end

    test "does not return archived folders", %{conn: conn} do
      workspace = ws()
      folder = create_folder!(workspace)
      {:ok, _} = Docs.archive_folder(folder.id)
      conn = get(conn, "/api/v1/doc-folders", workspace: workspace)
      assert %{"data" => data} = json_response(conn, 200)
      refute Enum.any?(data, &(&1["id"] == folder.id))
    end

    test "returns 400 when workspace param missing", %{conn: conn} do
      conn = get(conn, "/api/v1/doc-folders")
      assert json_response(conn, 400)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/doc-folders/tree
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/doc-folders/tree" do
    test "returns hierarchical folder tree", %{conn: conn} do
      workspace = ws()
      parent = create_folder!(workspace, %{"name" => "Parent"})
      _child = create_folder!(workspace, %{"name" => "Child", "parent_id" => parent.id})

      conn = get(conn, "/api/v1/doc-folders/tree", workspace: workspace)
      assert %{"data" => tree} = json_response(conn, 200)

      parent_node = Enum.find(tree, &(&1["id"] == parent.id))
      assert parent_node != nil
      assert length(parent_node["children"]) == 1
      assert hd(parent_node["children"])["name"] == "Child"
    end

    test "returns 400 when workspace param missing", %{conn: conn} do
      conn = get(conn, "/api/v1/doc-folders/tree")
      assert json_response(conn, 400)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/doc-folders
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/doc-folders" do
    test "creates folder and returns 201", %{conn: conn} do
      workspace = ws()

      conn =
        post(conn, "/api/v1/doc-folders", %{
          "name" => "New Folder",
          "workspace_slug" => workspace
        })

      assert %{"data" => %{"id" => _, "name" => "New Folder"}} = json_response(conn, 201)
    end

    test "creates nested folder with parent_id", %{conn: conn} do
      workspace = ws()
      parent = create_folder!(workspace)

      conn =
        post(conn, "/api/v1/doc-folders", %{
          "name" => "Child",
          "workspace_slug" => workspace,
          "parent_id" => parent.id
        })

      assert %{"data" => %{"parent_id" => parent_id}} = json_response(conn, 201)
      assert parent_id == parent.id
    end

    test "returns 422 for missing name", %{conn: conn} do
      conn = post(conn, "/api/v1/doc-folders", %{"workspace_slug" => ws()})
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/doc-folders/:id
  # ---------------------------------------------------------------------------

  describe "PATCH /api/v1/doc-folders/:id" do
    test "updates folder name and returns 200", %{conn: conn} do
      workspace = ws()
      folder = create_folder!(workspace)

      conn = patch(conn, "/api/v1/doc-folders/#{folder.id}", %{"name" => "Renamed Folder"})
      assert %{"data" => %{"name" => "Renamed Folder"}} = json_response(conn, 200)
    end

    test "returns 404 for unknown folder", %{conn: conn} do
      conn = patch(conn, "/api/v1/doc-folders/#{Ecto.UUID.generate()}", %{"name" => "X"})
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/doc-folders/:id
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/doc-folders/:id" do
    test "archives folder and returns 204", %{conn: conn} do
      workspace = ws()
      folder = create_folder!(workspace)

      conn = delete(conn, "/api/v1/doc-folders/#{folder.id}")
      assert response(conn, 204)

      # Verify folder is archived in DB
      {:ok, archived} = Docs.get_folder(folder.id)
      assert archived.archived_at != nil
    end

    test "returns 404 for unknown folder", %{conn: conn} do
      conn = delete(conn, "/api/v1/doc-folders/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end
end
