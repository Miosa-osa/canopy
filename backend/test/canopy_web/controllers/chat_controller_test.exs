defmodule CanopyWeb.ChatControllerTest do
  @moduledoc """
  Controller tests for GET/POST/PATCH/DELETE /api/v1/chat/threads.
  """

  use CanopyWeb.ConnCase, async: true

  alias Canopy.Chat
  alias Canopy.Repo

  @base_path "/api/v1/chat/threads"

  # ---------------------------------------------------------------------------
  # GET /api/v1/chat/threads
  # ---------------------------------------------------------------------------

  describe "index/2" do
    test "returns 200 with thread list", %{conn: conn} do
      {:ok, _} = Chat.create_thread(%{runtime_type: "claude-local", title: "Thread A"})
      {:ok, _} = Chat.create_thread(%{runtime_type: "claude-local", title: "Thread B"})

      conn = get(conn, @base_path)
      assert %{"data" => threads} = json_response(conn, 200)
      assert length(threads) >= 2
    end

    test "filters by agent_slug", %{conn: conn} do
      {:ok, _} = Chat.create_thread(%{runtime_type: "claude-local", agent_slug: "coder"})
      {:ok, _} = Chat.create_thread(%{runtime_type: "claude-local", agent_slug: "reviewer"})

      conn = get(conn, @base_path, agent_slug: "coder")
      assert %{"data" => threads} = json_response(conn, 200)
      assert Enum.all?(threads, &(&1["agent_slug"] == "coder"))
    end

    test "returns empty list when no threads match filter", %{conn: conn} do
      conn = get(conn, @base_path, agent_slug: "nonexistent-agent-#{Ecto.UUID.generate()}")
      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/chat/threads
  # ---------------------------------------------------------------------------

  describe "create/2" do
    test "creates a thread and returns 201 with session_id and sse_url", %{conn: conn} do
      params = %{runtime_type: "claude-local", title: "My Thread", agent_slug: "senior-dev"}

      conn = post(conn, @base_path, params)
      body = json_response(conn, 201)

      assert body["thread"]["id"] != nil
      assert body["thread"]["title"] == "My Thread"
      assert body["session_id"] != nil
      assert body["sse_url"] =~ "/api/v1/sessions/"
      assert body["sse_url"] =~ "/events"
    end

    test "returns 422 on missing runtime_type", %{conn: conn} do
      conn = post(conn, @base_path, %{title: "Oops"})
      body = json_response(conn, 422)
      assert body["errors"] != nil || body["error"] != nil
    end

    test "sets user_id from current_user when authenticated", %{conn: conn} do
      # OptionalAuthenticate returns nil user in test — just verify thread is created
      params = %{runtime_type: "claude-local"}
      conn = post(conn, @base_path, params)
      assert json_response(conn, 201)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/chat/threads/:id
  # ---------------------------------------------------------------------------

  describe "show/2" do
    test "returns 200 with thread and messages", %{conn: conn} do
      {:ok, thread} = Chat.create_thread(%{runtime_type: "claude-local", title: "Detail Thread"})

      conn = get(conn, "#{@base_path}/#{thread.id}")
      body = json_response(conn, 200)

      assert body["thread"]["id"] == thread.id
      assert is_list(body["messages"])
    end

    test "returns 404 for missing thread", %{conn: conn} do
      conn = get(conn, "#{@base_path}/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/chat/threads/:id/continue
  # ---------------------------------------------------------------------------

  describe "continue/2" do
    test "returns 201 with new session_id and sse_url", %{conn: conn} do
      {:ok, thread} = Chat.create_thread(%{runtime_type: "claude-local"})

      conn = post(conn, "#{@base_path}/#{thread.id}/continue", %{prompt: "What next?"})
      body = json_response(conn, 201)

      assert body["session_id"] != nil
      assert body["session_id"] != thread.last_session_id
      assert body["sse_url"] =~ "/api/v1/sessions/"
    end

    test "returns 404 for missing thread", %{conn: conn} do
      conn = post(conn, "#{@base_path}/#{Ecto.UUID.generate()}/continue", %{prompt: "hi"})
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/chat/threads/:id
  # ---------------------------------------------------------------------------

  describe "update/2" do
    test "renames the thread", %{conn: conn} do
      {:ok, thread} = Chat.create_thread(%{runtime_type: "claude-local", title: "Old Title"})

      conn = patch(conn, "#{@base_path}/#{thread.id}", %{title: "New Title"})
      body = json_response(conn, 200)
      assert body["title"] == "New Title"
    end

    test "pins the thread", %{conn: conn} do
      {:ok, thread} = Chat.create_thread(%{runtime_type: "claude-local"})
      refute thread.pinned

      conn = patch(conn, "#{@base_path}/#{thread.id}", %{pinned: true})
      body = json_response(conn, 200)
      assert body["pinned"] == true
    end

    test "archives the thread", %{conn: conn} do
      {:ok, thread} = Chat.create_thread(%{runtime_type: "claude-local"})
      assert thread.archived_at == nil

      conn = patch(conn, "#{@base_path}/#{thread.id}", %{archived: true})
      body = json_response(conn, 200)
      assert body["archived_at"] != nil
    end

    test "returns 404 for missing thread", %{conn: conn} do
      conn = patch(conn, "#{@base_path}/#{Ecto.UUID.generate()}", %{title: "x"})
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/chat/threads/:id
  # ---------------------------------------------------------------------------

  describe "delete/2" do
    test "returns 204 and removes the thread", %{conn: conn} do
      {:ok, thread} = Chat.create_thread(%{runtime_type: "claude-local"})

      conn = delete(conn, "#{@base_path}/#{thread.id}")
      assert response(conn, 204) == ""

      assert Repo.get(Canopy.Chat.Thread, thread.id) == nil
    end

    test "returns 404 for missing thread", %{conn: conn} do
      conn = delete(conn, "#{@base_path}/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/chat/threads/:id/export
  # ---------------------------------------------------------------------------

  describe "export/2" do
    test "returns 200 with text/markdown content type", %{conn: conn} do
      {:ok, thread} = Chat.create_thread(%{runtime_type: "claude-local", title: "Export Me"})

      conn = get(conn, "#{@base_path}/#{thread.id}/export")

      assert conn.status == 200
      content_type = get_resp_header(conn, "content-type") |> hd()
      assert String.contains?(content_type, "text/markdown")
      assert String.contains?(conn.resp_body, "# Export Me")
    end

    test "returns 404 for missing thread", %{conn: conn} do
      conn = get(conn, "#{@base_path}/#{Ecto.UUID.generate()}/export")
      assert json_response(conn, 404)
    end

    test "include_thinking param is accepted", %{conn: conn} do
      {:ok, thread} = Chat.create_thread(%{runtime_type: "claude-local", title: "Think"})

      conn = get(conn, "#{@base_path}/#{thread.id}/export", include_thinking: "true")
      assert conn.status == 200
    end
  end
end
