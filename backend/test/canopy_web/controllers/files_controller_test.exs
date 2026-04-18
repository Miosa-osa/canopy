defmodule CanopyWeb.FilesControllerTest do
  @moduledoc """
  Integration tests for FilesController.

  Covers: multipart upload, list, metadata show, content stream, scan,
  search (name + semantic stub), tags update, archive, activity log.
  """

  use CanopyWeb.ConnCase, async: true

  alias Canopy.Repo
  alias Canopy.Workspaces.Workspace

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp make_workspace(slug \\ nil) do
    effective_slug = slug || "ws-#{System.unique_integer([:positive])}"

    dir =
      System.tmp_dir!()
      |> Path.join("files-ctrl-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    {:ok, ws} =
      Repo.insert(
        Workspace.changeset(%Workspace{}, %{
          slug: effective_slug,
          name: "Files Controller Workspace",
          root_path: dir
        })
      )

    {ws, dir}
  end

  defp write_disk!(dir, rel, content \\ "# test") do
    abs = Path.join(dir, rel)
    File.mkdir_p!(Path.dirname(abs))
    File.write!(abs, content)
  end

  defp index_file!(ws, dir, rel, content \\ "# test") do
    write_disk!(dir, rel, content)
    {:ok, file} = Canopy.Files.index_file(ws.id, rel)
    file
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/files (upload)
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/files" do
    test "uploads and indexes a file, returns 201 with file metadata", %{conn: conn} do
      {ws, _dir} = make_workspace()
      tmp = Path.join(System.tmp_dir!(), "upload-#{System.unique_integer([:positive])}.md")
      File.write!(tmp, "# uploaded content")
      on_exit(fn -> File.rm(tmp) end)

      upload = %Plug.Upload{path: tmp, filename: "intro.md", content_type: "text/markdown"}

      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/v1/files", %{
          "workspace_slug" => ws.slug,
          "path" => "docs/intro.md",
          "file" => upload
        })

      assert %{"file" => file_json} = json_response(conn, 201)
      assert file_json["path"] == "docs/intro.md"
      assert file_json["name"] == "intro.md"
      assert file_json["workspace_id"] == ws.id
    end

    test "returns 400 when workspace_slug or path missing", %{conn: conn} do
      conn = post(conn, "/api/v1/files", %{})
      assert %{"error" => "missing_params"} = json_response(conn, 400)
    end

    test "returns 404 for unknown workspace", %{conn: conn} do
      tmp = Path.join(System.tmp_dir!(), "u.md")
      File.write!(tmp, "x")
      on_exit(fn -> File.rm(tmp) end)

      upload = %Plug.Upload{path: tmp, filename: "u.md", content_type: "text/plain"}

      conn =
        post(conn, "/api/v1/files", %{
          "workspace_slug" => "no-such-workspace",
          "path" => "u.md",
          "file" => upload
        })

      assert json_response(conn, 404)
    end

    test "returns 400 when file field is missing", %{conn: conn} do
      {ws, _dir} = make_workspace()

      conn =
        post(conn, "/api/v1/files", %{
          "workspace_slug" => ws.slug,
          "path" => "x.md"
        })

      assert %{"error" => "missing_file"} = json_response(conn, 400)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/files?workspace=slug
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/files" do
    test "returns 200 with file list for workspace", %{conn: conn} do
      {ws, dir} = make_workspace()
      index_file!(ws, dir, "a.md")
      index_file!(ws, dir, "b.txt")

      conn = get(conn, "/api/v1/files?workspace=#{ws.slug}")
      assert %{"data" => files, "count" => 2} = json_response(conn, 200)
      assert is_list(files)
    end

    test "filters by extension", %{conn: conn} do
      {ws, dir} = make_workspace()
      index_file!(ws, dir, "a.md")
      index_file!(ws, dir, "b.txt")

      conn = get(conn, "/api/v1/files?workspace=#{ws.slug}&extension=md")
      assert %{"data" => files} = json_response(conn, 200)
      assert Enum.all?(files, &(&1["extension"] == "md"))
    end

    test "returns 400 when workspace param missing", %{conn: conn} do
      conn = get(conn, "/api/v1/files")
      assert %{"error" => "missing_params"} = json_response(conn, 400)
    end

    test "returns 404 for unknown workspace", %{conn: conn} do
      conn = get(conn, "/api/v1/files?workspace=nope")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/files/:id
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/files/:id" do
    test "returns 200 with file metadata", %{conn: conn} do
      {ws, dir} = make_workspace()
      file = index_file!(ws, dir, "readme.md")

      conn = get(conn, "/api/v1/files/#{file.id}")
      assert %{"file" => file_json} = json_response(conn, 200)
      assert file_json["id"] == file.id
      assert file_json["name"] == "readme.md"
    end

    test "returns 404 for unknown id", %{conn: conn} do
      conn = get(conn, "/api/v1/files/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/files/:id/content
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/files/:id/content" do
    test "streams file bytes with correct Content-Type", %{conn: conn} do
      {ws, dir} = make_workspace()
      file = index_file!(ws, dir, "doc.md", "# Doc Content")

      conn = get(conn, "/api/v1/files/#{file.id}/content")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> hd() =~ "text/markdown"
      assert conn.resp_body =~ "Doc Content"
    end

    test "returns 404 for unknown file id", %{conn: conn} do
      conn = get(conn, "/api/v1/files/#{Ecto.UUID.generate()}/content")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/files/:id
  # ---------------------------------------------------------------------------

  describe "PATCH /api/v1/files/:id" do
    test "updates tags and returns updated file", %{conn: conn} do
      {ws, dir} = make_workspace()
      file = index_file!(ws, dir, "x.md")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> patch("/api/v1/files/#{file.id}", %{"tags" => ["important", "draft"]})

      assert %{"file" => file_json} = json_response(conn, 200)
      assert file_json["tags"] == ["important", "draft"]
    end

    test "returns 400 when tags param missing", %{conn: conn} do
      {ws, dir} = make_workspace()
      file = index_file!(ws, dir, "x.md")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> patch("/api/v1/files/#{file.id}", %{})

      assert json_response(conn, 400)
    end

    test "returns 404 for unknown file", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> patch("/api/v1/files/#{Ecto.UUID.generate()}", %{"tags" => []})

      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/files/:id
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/files/:id" do
    test "soft-archives file and returns 204", %{conn: conn} do
      {ws, dir} = make_workspace()
      file = index_file!(ws, dir, "old.md")

      conn = delete(conn, "/api/v1/files/#{file.id}")
      assert conn.status == 204
    end

    test "returns 404 for unknown file", %{conn: conn} do
      conn = delete(conn, "/api/v1/files/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/files/scan
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/files/scan" do
    test "scans workspace and returns indexed count", %{conn: conn} do
      {ws, dir} = make_workspace()
      write_disk!(dir, "a.md")
      write_disk!(dir, "b.txt")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/files/scan", %{"workspace_slug" => ws.slug})

      assert %{"indexed" => count, "workspace_slug" => slug} = json_response(conn, 200)
      assert count == 2
      assert slug == ws.slug
    end

    test "returns 400 when workspace_slug missing", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/files/scan", %{})

      assert json_response(conn, 400)
    end

    test "returns 404 for unknown workspace", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/files/scan", %{"workspace_slug" => "no-such"})

      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/files/:id/activity
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/files/:id/activity" do
    test "returns activity log for file", %{conn: conn} do
      {ws, dir} = make_workspace()
      file = index_file!(ws, dir, "logged.md")

      conn = get(conn, "/api/v1/files/#{file.id}/activity")
      assert %{"data" => entries} = json_response(conn, 200)
      assert is_list(entries)
      # At minimum the "created" entry from index_file
      assert length(entries) >= 1
    end

    test "returns 404 for unknown file", %{conn: conn} do
      conn = get(conn, "/api/v1/files/#{Ecto.UUID.generate()}/activity")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/files/search
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/files/search" do
    test "name search returns matching files", %{conn: conn} do
      {ws, dir} = make_workspace()
      index_file!(ws, dir, "readme.md")
      index_file!(ws, dir, "notes.txt")

      conn = get(conn, "/api/v1/files/search?workspace=#{ws.slug}&q=readme&mode=name")

      assert %{"data" => results, "mode" => "name", "query" => "readme"} =
               json_response(conn, 200)

      assert length(results) == 1
    end

    test "semantic search stub returns list without error", %{conn: conn} do
      {ws, dir} = make_workspace()
      index_file!(ws, dir, "doc.md")

      conn = get(conn, "/api/v1/files/search?workspace=#{ws.slug}&q=some+query&mode=semantic")
      assert %{"data" => results} = json_response(conn, 200)
      assert is_list(results)
    end

    test "returns 400 when workspace or q missing", %{conn: conn} do
      conn = get(conn, "/api/v1/files/search?q=foo")
      assert json_response(conn, 400)
    end

    test "returns 404 for unknown workspace", %{conn: conn} do
      conn = get(conn, "/api/v1/files/search?workspace=nope&q=anything")
      assert json_response(conn, 404)
    end
  end
end
