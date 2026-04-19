defmodule CanopyWeb.KnowledgeControllerTest do
  @moduledoc """
  Controller tests for /api/v1/knowledge-bases endpoints.
  """

  use CanopyWeb.ConnCase, async: false

  import Canopy.Factory

  alias Canopy.Knowledge

  # ---------------------------------------------------------------------------
  # GET /api/v1/knowledge-bases
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/knowledge-bases" do
    test "returns 200 with empty list when no KBs exist", %{conn: conn} do
      conn = get(conn, "/api/v1/knowledge-bases")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns active KBs", %{conn: conn} do
      insert(:knowledge_base, slug: "get-kb-1", name: "KB One")
      insert(:knowledge_base, slug: "get-kb-2", name: "KB Two")
      conn = get(conn, "/api/v1/knowledge-bases")
      assert %{"data" => data} = json_response(conn, 200)
      slugs = Enum.map(data, & &1["slug"])
      assert "get-kb-1" in slugs
      assert "get-kb-2" in slugs
    end

    test "excludes archived KBs by default", %{conn: conn} do
      insert(:knowledge_base, slug: "ctrl-active")
      insert(:knowledge_base, slug: "ctrl-archived", archived_at: DateTime.utc_now())
      conn = get(conn, "/api/v1/knowledge-bases")
      assert %{"data" => data} = json_response(conn, 200)
      slugs = Enum.map(data, & &1["slug"])
      assert "ctrl-active" in slugs
      refute "ctrl-archived" in slugs
    end

    test "filters by workspace via query param", %{conn: conn} do
      insert(:knowledge_base, slug: "ws-filter-a", workspace_slug: "ws-alpha")
      insert(:knowledge_base, slug: "ws-filter-b", workspace_slug: "ws-beta")
      conn = get(conn, "/api/v1/knowledge-bases?workspace=ws-alpha")
      assert %{"data" => data} = json_response(conn, 200)
      slugs = Enum.map(data, & &1["slug"])
      assert "ws-filter-a" in slugs
      refute "ws-filter-b" in slugs
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/knowledge-bases
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/knowledge-bases" do
    test "returns 201 and creates a KB", %{conn: conn} do
      params = %{slug: "create-ctrl-kb", name: "Created KB", description: "Test"}
      conn = post(conn, "/api/v1/knowledge-bases", params)
      assert %{"slug" => "create-ctrl-kb", "name" => "Created KB"} = json_response(conn, 201)
    end

    test "returns 422 for missing required fields", %{conn: conn} do
      conn = post(conn, "/api/v1/knowledge-bases", %{})
      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns 422 for invalid slug", %{conn: conn} do
      conn = post(conn, "/api/v1/knowledge-bases", %{slug: "Bad Slug!", name: "KB"})
      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns 422 for duplicate slug", %{conn: conn} do
      insert(:knowledge_base, slug: "dup-ctrl-kb")
      conn = post(conn, "/api/v1/knowledge-bases", %{slug: "dup-ctrl-kb", name: "Dup"})
      assert %{"errors" => _} = json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/knowledge-bases/:slug
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/knowledge-bases/:slug" do
    test "returns 200 with chunk_count and agent_count", %{conn: conn} do
      kb = insert(:knowledge_base, slug: "show-ctrl-kb")
      insert(:kb_chunk, knowledge_base: kb, source_path: "f.txt", chunk_index: 0)
      insert(:kb_chunk, knowledge_base: kb, source_path: "f.txt", chunk_index: 1)

      conn = get(conn, "/api/v1/knowledge-bases/show-ctrl-kb")
      body = json_response(conn, 200)
      assert body["slug"] == "show-ctrl-kb"
      assert body["chunk_count"] == 2
      assert body["agent_count"] == 0
    end

    test "returns 404 for unknown slug", %{conn: conn} do
      conn = get(conn, "/api/v1/knowledge-bases/nonexistent")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/knowledge-bases/:slug
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/knowledge-bases/:slug" do
    test "archives the KB and returns 200", %{conn: conn} do
      insert(:knowledge_base, slug: "del-ctrl-kb")
      conn = delete(conn, "/api/v1/knowledge-bases/del-ctrl-kb")
      body = json_response(conn, 200)
      assert body["archived_at"] != nil
    end

    test "returns 404 for unknown slug", %{conn: conn} do
      conn = delete(conn, "/api/v1/knowledge-bases/gone")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/knowledge-bases/:slug/files
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/knowledge-bases/:slug/files — multipart upload" do
    test "returns 200 with indexed_chunks on direct upload", %{conn: conn} do
      insert(:knowledge_base, slug: "upload-ctrl-kb")

      upload = %Plug.Upload{
        path: create_temp_file("Hello world. This is test content for the chunker."),
        filename: "test.txt",
        content_type: "text/plain"
      }

      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/v1/knowledge-bases/upload-ctrl-kb/files", %{"file" => upload})

      body = json_response(conn, 200)
      assert body["indexed_chunks"] >= 1
    end

    test "returns error when neither file_id nor file upload provided", %{conn: conn} do
      insert(:knowledge_base, slug: "no-src-kb")
      conn = post(conn, "/api/v1/knowledge-bases/no-src-kb/files", %{})
      # FallbackController handles the :missing_file_source error as 500 (catch-all)
      assert conn.status in [422, 500]
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/knowledge-bases/:slug/chunks
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/knowledge-bases/:slug/chunks" do
    test "returns 200 with chunk list", %{conn: conn} do
      kb = insert(:knowledge_base, slug: "chunks-ctrl-kb")
      insert(:kb_chunk, knowledge_base: kb, source_path: "c.txt", chunk_index: 0)
      insert(:kb_chunk, knowledge_base: kb, source_path: "c.txt", chunk_index: 1)

      conn = get(conn, "/api/v1/knowledge-bases/chunks-ctrl-kb/chunks")
      body = json_response(conn, 200)
      assert length(body["data"]) == 2
      assert body["offset"] == 0
    end

    test "respects limit and offset params", %{conn: conn} do
      kb = insert(:knowledge_base, slug: "paginate-ctrl-kb")

      Enum.each(0..4, fn i ->
        insert(:kb_chunk, knowledge_base: kb, source_path: "p.txt", chunk_index: i)
      end)

      conn = get(conn, "/api/v1/knowledge-bases/paginate-ctrl-kb/chunks?limit=2&offset=0")
      body = json_response(conn, 200)
      assert length(body["data"]) == 2
    end

    test "returns 404 for unknown KB", %{conn: conn} do
      conn = get(conn, "/api/v1/knowledge-bases/no-kb/chunks")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/knowledge-bases/:slug/search
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/knowledge-bases/:slug/search" do
    test "returns 200 with results and note", %{conn: conn} do
      kb = insert(:knowledge_base, slug: "search-ctrl-kb")

      Enum.each(0..4, fn i ->
        insert(:kb_chunk, knowledge_base: kb, source_path: "s.txt", chunk_index: i)
      end)

      conn =
        post(conn, "/api/v1/knowledge-bases/search-ctrl-kb/search", %{query: "test", limit: 3})

      body = json_response(conn, 200)
      assert length(body["data"]) <= 3
      assert body["query"] == "test"
      assert is_binary(body["note"])
    end

    test "returns 422 when query is missing", %{conn: conn} do
      insert(:knowledge_base, slug: "search-no-query-kb")
      conn = post(conn, "/api/v1/knowledge-bases/search-no-query-kb/search", %{})
      assert json_response(conn, 422)
    end

    test "returns 404 for unknown KB", %{conn: conn} do
      conn = post(conn, "/api/v1/knowledge-bases/no-kb/search", %{query: "x"})
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/knowledge-bases/:slug/assignments
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/knowledge-bases/:slug/assignments" do
    test "returns 200 with empty list when KB has no assignments", %{conn: conn} do
      insert(:knowledge_base, slug: "list-assign-empty-kb")

      conn = get(conn, "/api/v1/knowledge-bases/list-assign-empty-kb/assignments")
      body = json_response(conn, 200)
      assert body["data"] == []
    end

    test "returns 200 with all assignments for a KB", %{conn: conn} do
      kb = insert(:knowledge_base, slug: "list-assign-populated-kb")
      Knowledge.assign(kb.id, "agent-alpha")
      Knowledge.assign(kb.id, "agent-beta")

      conn = get(conn, "/api/v1/knowledge-bases/list-assign-populated-kb/assignments")
      body = json_response(conn, 200)
      agent_slugs = Enum.map(body["data"], & &1["agent_slug"])
      assert "agent-alpha" in agent_slugs
      assert "agent-beta" in agent_slugs
    end

    test "returns 404 for unknown KB slug", %{conn: conn} do
      conn = get(conn, "/api/v1/knowledge-bases/no-such-kb/assignments")
      assert json_response(conn, 404)
    end

    test "returned assignment has expected shape", %{conn: conn} do
      kb = insert(:knowledge_base, slug: "list-assign-shape-kb")
      Knowledge.assign(kb.id, "shape-agent")

      conn = get(conn, "/api/v1/knowledge-bases/list-assign-shape-kb/assignments")
      body = json_response(conn, 200)
      [assignment] = body["data"]
      assert assignment["agent_slug"] == "shape-agent"
      assert Map.has_key?(assignment, "kb_id")
      assert Map.has_key?(assignment, "priority")
      assert Map.has_key?(assignment, "inserted_at")
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/knowledge-bases/:slug/assignments
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/knowledge-bases/:slug/assignments" do
    test "returns 201 and creates assignment", %{conn: conn} do
      insert(:knowledge_base, slug: "assign-ctrl-kb")

      conn =
        post(conn, "/api/v1/knowledge-bases/assign-ctrl-kb/assignments", %{
          agent_slug: "test-agent"
        })

      body = json_response(conn, 201)
      assert body["agent_slug"] == "test-agent"
    end

    test "returns 422 when agent_slug is missing", %{conn: conn} do
      insert(:knowledge_base, slug: "assign-no-agent-kb")
      conn = post(conn, "/api/v1/knowledge-bases/assign-no-agent-kb/assignments", %{})
      assert json_response(conn, 422)
    end

    test "returns 404 for unknown KB", %{conn: conn} do
      conn = post(conn, "/api/v1/knowledge-bases/no-kb/assignments", %{agent_slug: "a"})
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/knowledge-bases/:slug/assignments/:agent_slug
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/knowledge-bases/:slug/assignments/:agent_slug" do
    test "returns 200 and unassigns agent", %{conn: conn} do
      kb = insert(:knowledge_base, slug: "unassign-ctrl-kb")
      Knowledge.assign(kb.id, "remove-agent")

      conn =
        delete(conn, "/api/v1/knowledge-bases/unassign-ctrl-kb/assignments/remove-agent")

      assert %{"ok" => true} = json_response(conn, 200)
    end

    test "returns 200 even when assignment does not exist (idempotent)", %{conn: conn} do
      insert(:knowledge_base, slug: "idem-unassign-ctrl-kb")

      conn =
        delete(
          conn,
          "/api/v1/knowledge-bases/idem-unassign-ctrl-kb/assignments/ghost-agent"
        )

      assert %{"ok" => true} = json_response(conn, 200)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/knowledge-bases/:slug/rebuild
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/knowledge-bases/:slug/rebuild" do
    test "returns 200 with rebuilt_chunks count", %{conn: conn} do
      kb = insert(:knowledge_base, slug: "rebuild-ctrl-kb")
      insert(:kb_chunk, knowledge_base: kb, source_path: "rb.txt", chunk_index: 0)

      conn = post(conn, "/api/v1/knowledge-bases/rebuild-ctrl-kb/rebuild", %{})
      body = json_response(conn, 200)
      assert Map.has_key?(body, "rebuilt_chunks")
    end

    test "returns 404 for unknown KB", %{conn: conn} do
      conn = post(conn, "/api/v1/knowledge-bases/no-kb/rebuild", %{})
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_temp_file(content) do
    path = Path.join(System.tmp_dir!(), "kb_test_#{System.unique_integer()}.txt")
    File.write!(path, content)
    on_exit(fn -> File.rm(path) end)
    path
  end
end
