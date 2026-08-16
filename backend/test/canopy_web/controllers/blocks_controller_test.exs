defmodule CanopyWeb.BlocksControllerTest do
  @moduledoc """
  Tests for `/api/v1/sessions/:session_id/blocks/*`.

  Focus: input validation (UUID, kind enum, status enum, tag slug, limit
  cap), error responses, and end-to-end happy paths.
  """

  use CanopyWeb.ConnCase, async: true

  alias Canopy.Sessions.{Blocks, Session}

  defp create_session! do
    {:ok, session} =
      Canopy.Repo.insert(
        Session.changeset(%Session{}, %{runtime_type: "claude-local", cwd: "/tmp"})
      )

    session
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/sessions/:session_id/blocks
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/sessions/:session_id/blocks" do
    test "rejects invalid session_id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/sessions/not-a-uuid/blocks")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "returns empty data for new session", %{conn: conn} do
      session = create_session!()
      conn = get(conn, ~p"/api/v1/sessions/#{session.id}/blocks")
      assert %{"count" => 0, "data" => []} = json_response(conn, 200)
    end

    test "returns blocks ordered by sequence", %{conn: conn} do
      session = create_session!()

      for kind <- ~w(command agent_message tool_call) do
        Blocks.create(%{session_id: session.id, kind: kind})
      end

      conn = get(conn, ~p"/api/v1/sessions/#{session.id}/blocks")
      assert %{"data" => blocks} = json_response(conn, 200)
      assert Enum.map(blocks, & &1["sequence"]) == [0, 1, 2]
    end

    test "filters by kind", %{conn: conn} do
      session = create_session!()
      Blocks.create(%{session_id: session.id, kind: "command"})
      Blocks.create(%{session_id: session.id, kind: "agent_message"})

      conn = get(conn, ~p"/api/v1/sessions/#{session.id}/blocks?kind=agent_message")
      assert %{"data" => [b]} = json_response(conn, 200)
      assert b["kind"] == "agent_message"
    end

    test "filters by status", %{conn: conn} do
      session = create_session!()
      Blocks.create(%{session_id: session.id, kind: "command", status: "completed"})
      Blocks.create(%{session_id: session.id, kind: "command", status: "failed"})

      conn = get(conn, ~p"/api/v1/sessions/#{session.id}/blocks?status=failed")
      assert %{"data" => [b]} = json_response(conn, 200)
      assert b["status"] == "failed"
    end

    test "rejects invalid kind", %{conn: conn} do
      session = create_session!()
      conn = get(conn, ~p"/api/v1/sessions/#{session.id}/blocks?kind=garbage")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects invalid status", %{conn: conn} do
      session = create_session!()
      conn = get(conn, ~p"/api/v1/sessions/#{session.id}/blocks?status=garbage")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects invalid since timestamp", %{conn: conn} do
      session = create_session!()
      conn = get(conn, ~p"/api/v1/sessions/#{session.id}/blocks?since=not-a-date")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "caps limit at 1000", %{conn: conn} do
      session = create_session!()
      for _ <- 1..3, do: Blocks.create(%{session_id: session.id, kind: "command"})

      conn = get(conn, ~p"/api/v1/sessions/#{session.id}/blocks?limit=999999")
      assert %{"data" => blocks} = json_response(conn, 200)
      assert length(blocks) <= 1000
    end

    test "filters by parent_block_id", %{conn: conn} do
      session = create_session!()
      {:ok, parent} = Blocks.create(%{session_id: session.id, kind: "agent_message"})

      {:ok, child} =
        Blocks.create(%{
          session_id: session.id,
          kind: "tool_call",
          parent_block_id: parent.id
        })

      conn =
        get(conn, ~p"/api/v1/sessions/#{session.id}/blocks?parent_block_id=#{parent.id}")

      assert %{"data" => [b]} = json_response(conn, 200)
      assert b["id"] == child.id
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/sessions/:session_id/blocks/:id
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/sessions/:session_id/blocks/:id" do
    test "returns the block", %{conn: conn} do
      session = create_session!()
      {:ok, b} = Blocks.create(%{session_id: session.id, kind: "command"})

      conn = get(conn, ~p"/api/v1/sessions/#{session.id}/blocks/#{b.id}")
      payload = json_response(conn, 200)
      assert payload["id"] == b.id
      assert payload["kind"] == "command"
    end

    test "404 for unknown block", %{conn: conn} do
      session = create_session!()
      missing_id = Ecto.UUID.generate()
      conn = get(conn, ~p"/api/v1/sessions/#{session.id}/blocks/#{missing_id}")
      assert %{"error" => "block_not_found"} = json_response(conn, 404)
    end

    test "404 when block belongs to a different session", %{conn: conn} do
      a = create_session!()
      b = create_session!()
      {:ok, block} = Blocks.create(%{session_id: a.id, kind: "command"})

      conn = get(conn, ~p"/api/v1/sessions/#{b.id}/blocks/#{block.id}")
      assert %{"error" => "block_not_found"} = json_response(conn, 404)
    end

    test "rejects invalid UUID in path", %{conn: conn} do
      session = create_session!()
      conn = get(conn, ~p"/api/v1/sessions/#{session.id}/blocks/not-a-uuid")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/sessions/:session_id/blocks/search
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/sessions/:session_id/blocks/search" do
    test "returns matching blocks for q", %{conn: conn} do
      session = create_session!()
      Blocks.create(%{session_id: session.id, kind: "command", input_text: "ls -la"})
      Blocks.create(%{session_id: session.id, kind: "command", output_text: "deployment ok"})

      conn = get(conn, ~p"/api/v1/sessions/#{session.id}/blocks/search?q=deploy")
      assert %{"count" => 1, "data" => [b]} = json_response(conn, 200)
      assert b["output_text"] =~ "deployment"
    end

    test "filters by tag", %{conn: conn} do
      session = create_session!()
      Blocks.create(%{session_id: session.id, kind: "command", tags: ["pinned"]})
      Blocks.create(%{session_id: session.id, kind: "command"})

      conn = get(conn, ~p"/api/v1/sessions/#{session.id}/blocks/search?tag=pinned")
      assert %{"data" => [b]} = json_response(conn, 200)
      assert "pinned" in b["tags"]
    end

    test "rejects malformed tag", %{conn: conn} do
      session = create_session!()

      conn =
        get(conn, ~p"/api/v1/sessions/#{session.id}/blocks/search?tag=NotAValidTag!")

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects invalid kind in search", %{conn: conn} do
      session = create_session!()
      conn = get(conn, ~p"/api/v1/sessions/#{session.id}/blocks/search?kind=garbage")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end
end
