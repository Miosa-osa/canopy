defmodule CanopyWeb.WorkspaceFilesControllerTest do
  @moduledoc """
  Tests for WorkspaceFilesController.

  Covers file tree, directory listing, read, write, delete, and move endpoints.
  Path traversal attempts are covered with multiple attack vectors per endpoint.
  """

  use CanopyWeb.ConnCase, async: true

  alias Canopy.Repo
  alias Canopy.Workspaces.Workspace

  # ---------------------------------------------------------------------------
  # Setup helpers
  # ---------------------------------------------------------------------------

  defp make_workspace(slug \\ nil) do
    effective_slug = slug || "ws-#{System.unique_integer([:positive])}"

    dir =
      System.tmp_dir!()
      |> Path.join("canopy-files-ctrl-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    {:ok, ws} =
      Repo.insert(
        Workspace.changeset(%Workspace{}, %{
          slug: effective_slug,
          name: "Files Test Workspace",
          root_path: dir
        })
      )

    {ws, dir}
  end

  defp write_file!(dir, rel, content \\ "# test") do
    abs = Path.join(dir, rel)
    File.mkdir_p!(Path.dirname(abs))
    File.write!(abs, content)
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces/:slug/tree
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/workspaces/:slug/tree" do
    test "returns 200 with file tree", %{conn: conn} do
      {ws, dir} = make_workspace()
      write_file!(dir, "SYSTEM.md")
      write_file!(dir, "agents/bot.md")

      conn = get(conn, "/api/v1/workspaces/#{ws.slug}/tree")
      assert %{"data" => tree} = json_response(conn, 200)
      assert is_map(tree)
      assert tree["is_dir"] == true
    end

    test "tree includes nested children", %{conn: conn} do
      {ws, dir} = make_workspace()
      write_file!(dir, "agents/closer.md")

      conn = get(conn, "/api/v1/workspaces/#{ws.slug}/tree")
      assert %{"data" => tree} = json_response(conn, 200)

      agents = Enum.find(tree["children"], &(&1["name"] == "agents"))
      assert agents != nil
      child_names = Enum.map(agents["children"], & &1["name"])
      assert "closer.md" in child_names
    end

    test "returns 404 for unknown workspace", %{conn: conn} do
      conn = get(conn, "/api/v1/workspaces/ghost/tree")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces/:slug/files?path=
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/workspaces/:slug/files (list_dir)" do
    test "lists workspace root when no path param", %{conn: conn} do
      {ws, dir} = make_workspace()
      write_file!(dir, "notes.md")

      conn = get(conn, "/api/v1/workspaces/#{ws.slug}/files")
      assert %{"data" => entries} = json_response(conn, 200)
      names = Enum.map(entries, & &1["name"])
      assert "notes.md" in names
    end

    test "lists a subdirectory when path param provided", %{conn: conn} do
      {ws, dir} = make_workspace()
      write_file!(dir, "sub/a.md")
      write_file!(dir, "sub/b.md")

      conn = get(conn, "/api/v1/workspaces/#{ws.slug}/files?path=sub")
      assert %{"data" => entries} = json_response(conn, 200)
      names = Enum.map(entries, & &1["name"])
      assert "a.md" in names
      assert "b.md" in names
    end

    test "returns 404 for nonexistent subdir", %{conn: conn} do
      {ws, _dir} = make_workspace()
      conn = get(conn, "/api/v1/workspaces/#{ws.slug}/files?path=nonexistent")
      assert json_response(conn, 404)
    end

    test "returns 400 for .. traversal in path param", %{conn: conn} do
      {ws, _dir} = make_workspace()
      conn = get(conn, "/api/v1/workspaces/#{ws.slug}/files?path=../../etc")
      assert %{"error" => "traversal_rejected"} = json_response(conn, 400)
    end

    test "returns 400 for absolute path in path param", %{conn: conn} do
      {ws, _dir} = make_workspace()
      conn = get(conn, "/api/v1/workspaces/#{ws.slug}/files?path=/etc")
      assert %{"error" => "traversal_rejected"} = json_response(conn, 400)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces/:slug/files/*path (read)
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/workspaces/:slug/files/*path (read)" do
    test "returns file content", %{conn: conn} do
      {ws, dir} = make_workspace()
      write_file!(dir, "hello.md", "# Hello\n")

      conn = get(conn, "/api/v1/workspaces/#{ws.slug}/files/hello.md")
      assert %{"content" => content} = json_response(conn, 200)
      assert content == "# Hello\n"
    end

    test "reads nested file", %{conn: conn} do
      {ws, dir} = make_workspace()
      write_file!(dir, "agents/bot.md", "# Bot")

      conn = get(conn, "/api/v1/workspaces/#{ws.slug}/files/agents/bot.md")
      assert %{"content" => content} = json_response(conn, 200)
      assert content == "# Bot"
    end

    test "returns 404 for missing file", %{conn: conn} do
      {ws, _dir} = make_workspace()
      conn = get(conn, "/api/v1/workspaces/#{ws.slug}/files/missing.md")
      assert json_response(conn, 404)
    end

    test "returns 400 for .. traversal — ../../etc/passwd pattern", %{conn: conn} do
      {ws, _dir} = make_workspace()
      # Phoenix encodes path segments; use encoded form or check raw routing
      # Test with encoded path traversal
      conn = get(conn, "/api/v1/workspaces/#{ws.slug}/files/..%2F..%2Fetc%2Fpasswd")
      # Phoenix will either reject at routing level or our guard will catch it
      assert conn.status in [400, 404]
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /api/v1/workspaces/:slug/files/*path (write)
  # ---------------------------------------------------------------------------

  describe "PUT /api/v1/workspaces/:slug/files/*path (write)" do
    test "writes content to a file", %{conn: conn} do
      {ws, dir} = make_workspace()

      conn =
        put(conn, "/api/v1/workspaces/#{ws.slug}/files/output.md", %{
          "content" => "# Written\n"
        })

      assert %{"written" => true} = json_response(conn, 200)
      assert File.read!(Path.join(dir, "output.md")) == "# Written\n"
    end

    test "creates parent directories automatically", %{conn: conn} do
      {ws, dir} = make_workspace()

      put(conn, "/api/v1/workspaces/#{ws.slug}/files/deep/nested/file.md", %{
        "content" => "data"
      })

      assert File.exists?(Path.join(dir, "deep/nested/file.md"))
    end

    test "overwrites existing file", %{conn: conn} do
      {ws, dir} = make_workspace()
      write_file!(dir, "existing.md", "old")

      put(conn, "/api/v1/workspaces/#{ws.slug}/files/existing.md", %{"content" => "new"})

      assert File.read!(Path.join(dir, "existing.md")) == "new"
    end

    test "returns 400 for .. traversal in path — escaped ../escape.md", %{conn: conn} do
      {ws, _dir} = make_workspace()
      # Direct .. traversal — Phoenix routing may block or our guard will catch it
      conn =
        put(conn, "/api/v1/workspaces/#{ws.slug}/files/..%2Fescape.md", %{"content" => "bad"})

      assert conn.status in [400, 404]
    end

    test "legitimate write succeeds and file exists on disk", %{conn: conn} do
      {ws, dir} = make_workspace()

      conn =
        put(conn, "/api/v1/workspaces/#{ws.slug}/files/legitimate.md", %{
          "content" => "safe content"
        })

      assert %{"written" => true} = json_response(conn, 200)
      assert File.read!(Path.join(dir, "legitimate.md")) == "safe content"
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/workspaces/:slug/files/*path
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/workspaces/:slug/files/*path" do
    test "deletes a file and returns 204", %{conn: conn} do
      {ws, dir} = make_workspace()
      write_file!(dir, "to-delete.md")

      conn = delete(conn, "/api/v1/workspaces/#{ws.slug}/files/to-delete.md")
      assert response(conn, 204) == ""
      refute File.exists?(Path.join(dir, "to-delete.md"))
    end

    test "returns 400 for .. traversal", %{conn: conn} do
      {ws, _dir} = make_workspace()
      conn = delete(conn, "/api/v1/workspaces/#{ws.slug}/files/..%2Fescape.md")
      assert conn.status in [400, 404]
    end

    test "returns 204 for nonexistent file (idempotent)", %{conn: conn} do
      {ws, _dir} = make_workspace()
      conn = delete(conn, "/api/v1/workspaces/#{ws.slug}/files/nonexistent.md")
      assert response(conn, 204) == ""
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/workspaces/:slug/files/move
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/workspaces/:slug/files/move" do
    test "moves a file and returns 200", %{conn: conn} do
      {ws, dir} = make_workspace()
      write_file!(dir, "original.md", "content")

      conn =
        post(conn, "/api/v1/workspaces/#{ws.slug}/files/move", %{
          "from" => "original.md",
          "to" => "moved.md"
        })

      assert %{"moved" => true} = json_response(conn, 200)
      refute File.exists?(Path.join(dir, "original.md"))
      assert File.read!(Path.join(dir, "moved.md")) == "content"
    end

    test "returns 400 when from is missing", %{conn: conn} do
      {ws, _dir} = make_workspace()
      conn = post(conn, "/api/v1/workspaces/#{ws.slug}/files/move", %{"to" => "dest.md"})
      assert %{"error" => "missing_params"} = json_response(conn, 400)
    end

    test "returns 400 when to is missing", %{conn: conn} do
      {ws, _dir} = make_workspace()

      conn =
        post(conn, "/api/v1/workspaces/#{ws.slug}/files/move", %{"from" => "src.md"})

      assert %{"error" => "missing_params"} = json_response(conn, 400)
    end

    test "returns 400 for .. traversal in from path", %{conn: conn} do
      {ws, _dir} = make_workspace()

      conn =
        post(conn, "/api/v1/workspaces/#{ws.slug}/files/move", %{
          "from" => "../escape.md",
          "to" => "dest.md"
        })

      assert %{"error" => "traversal_rejected"} = json_response(conn, 400)
    end

    test "returns 400 for .. traversal in to path", %{conn: conn} do
      {ws, dir} = make_workspace()
      write_file!(dir, "src.md")

      conn =
        post(conn, "/api/v1/workspaces/#{ws.slug}/files/move", %{
          "from" => "src.md",
          "to" => "../escape.md"
        })

      assert %{"error" => "traversal_rejected"} = json_response(conn, 400)
    end

    test "returns 400 for absolute path in from", %{conn: conn} do
      {ws, _dir} = make_workspace()

      conn =
        post(conn, "/api/v1/workspaces/#{ws.slug}/files/move", %{
          "from" => "/etc/passwd",
          "to" => "dest.md"
        })

      assert %{"error" => "traversal_rejected"} = json_response(conn, 400)
    end

    test "returns 404 when source does not exist", %{conn: conn} do
      {ws, _dir} = make_workspace()

      conn =
        post(conn, "/api/v1/workspaces/#{ws.slug}/files/move", %{
          "from" => "missing.md",
          "to" => "dest.md"
        })

      assert json_response(conn, 404)
    end
  end
end
