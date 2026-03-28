defmodule CanopyWeb.SessionControllerTest do
  use CanopyWeb.ConnCase

  import Canopy.TestHelpers
  alias Canopy.Repo
  alias Canopy.Schemas.Session

  describe "GET /sessions" do
    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/v1/sessions")
      assert conn.status == 401
    end

    test "returns only sessions from user's workspace agents", %{conn: conn} do
      user_a = insert_user()
      user_b = insert_user()
      ws_a = insert_workspace(user_a)
      ws_b = insert_workspace(user_b)
      agent_a = insert_agent(ws_a)
      agent_b = insert_agent(ws_b)

      # Create sessions for both agents
      insert_session(agent_a)
      insert_session(agent_b)

      conn = authenticated_conn(conn, user_a) |> get("/api/v1/sessions")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      agent_ids = Enum.map(body["sessions"], & &1["agent_id"])
      assert agent_a.id in agent_ids
      refute agent_b.id in agent_ids
    end
  end

  describe "GET /sessions/:id" do
    test "returns session details for owned session", %{conn: conn} do
      user = insert_user()
      ws = insert_workspace(user)
      agent = insert_agent(ws)
      session = insert_session(agent)

      conn =
        authenticated_conn(conn, user)
        |> get("/api/v1/sessions/#{session.id}")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["session"]["id"] == session.id
    end

    test "returns 403 for session in another user's workspace", %{conn: conn} do
      user_a = insert_user()
      user_b = insert_user()
      ws_b = insert_workspace(user_b)
      _ws_a = insert_workspace(user_a)
      agent_b = insert_agent(ws_b)
      session_b = insert_session(agent_b)

      conn =
        authenticated_conn(conn, user_a)
        |> get("/api/v1/sessions/#{session_b.id}")

      assert conn.status == 403
    end
  end

  describe "GET /sessions/:id/transcript" do
    test "returns 403 for another user's session", %{conn: conn} do
      user_a = insert_user()
      user_b = insert_user()
      _ws_a = insert_workspace(user_a)
      ws_b = insert_workspace(user_b)
      agent_b = insert_agent(ws_b)
      session_b = insert_session(agent_b)

      conn =
        authenticated_conn(conn, user_a)
        |> get("/api/v1/sessions/#{session_b.id}/transcript")

      assert conn.status == 403
    end
  end

  describe "POST /sessions/:id/message" do
    test "returns 403 for another user's session", %{conn: conn} do
      user_a = insert_user()
      user_b = insert_user()
      _ws_a = insert_workspace(user_a)
      ws_b = insert_workspace(user_b)
      agent_b = insert_agent(ws_b)
      session_b = insert_session(agent_b)

      conn =
        authenticated_conn(conn, user_a)
        |> post("/api/v1/sessions/#{session_b.id}/message", %{body: "hacked"})

      assert conn.status == 403
    end
  end

  # ── Factory helper ──────────────────────────────────────────────────────────

  defp insert_session(agent) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %Session{
      agent_id: agent.id,
      status: "active",
      model: "claude-sonnet-4-6",
      started_at: now,
      tokens_input: 0,
      tokens_output: 0,
      tokens_cache: 0,
      cost_cents: 0
    }
    |> Repo.insert!()
  end
end
