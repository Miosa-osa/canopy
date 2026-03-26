defmodule CanopyWeb.SSEStreamingTest do
  @moduledoc """
  Tests for SSE streaming endpoint configuration.

  Auth enforcement tests verify 401 responses (fast, no streaming).
  Full SSE streaming verification requires a running server — streaming tests
  are tagged :sse_streaming and excluded by default (use --include sse_streaming
  to run them with the understanding that each blocks for ~30s).
  """
  use CanopyWeb.ConnCase

  import Canopy.TestHelpers

  describe "SSE auth enforcement" do
    test "GET /activity/stream requires authentication", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "text/event-stream")
        |> get("/api/v1/activity/stream")

      assert conn.status == 401
      body = Jason.decode!(conn.resp_body)
      assert body["code"] == "INVALID_TOKEN"
    end

    test "GET /logs/stream requires authentication", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "text/event-stream")
        |> get("/api/v1/logs/stream")

      assert conn.status == 401
    end

    test "GET /sessions/:id/stream requires authentication", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "text/event-stream")
        |> get("/api/v1/sessions/#{Ecto.UUID.generate()}/stream")

      assert conn.status == 401
    end
  end

  describe "SSE pipeline configuration" do
    test "streaming pipeline is defined in router" do
      # Verify the streaming routes exist and are accessible
      # (will get 401 without auth, proving the route exists)
      routes = CanopyWeb.Router.__routes__()
      stream_paths = Enum.filter(routes, fn r -> String.ends_with?(r.path, "/stream") end)
      assert length(stream_paths) >= 3, "Expected at least 3 streaming routes"
    end

    test "auth plug supports Bearer token on authenticated endpoints" do
      user = insert_user()
      _workspace = insert_workspace(user)
      token = generate_token(user)

      # Verify that a valid Bearer token grants access to authenticated endpoints
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("content-type", "application/json")
        |> get("/api/v1/agents")

      # Should get 200 (authenticated, agents list)
      assert conn.status == 200
    end
  end

  describe "SSE EventBus topics" do
    test "workspace_topic builds correct topic string" do
      id = Ecto.UUID.generate()
      assert Canopy.EventBus.workspace_topic(id) == "workspace:#{id}"
    end

    test "session_topic builds correct topic string" do
      id = Ecto.UUID.generate()
      assert Canopy.EventBus.session_topic(id) == "session:#{id}"
    end

    test "activity_topic returns global topic" do
      assert Canopy.EventBus.activity_topic() == "activity:global"
    end

    test "logs_topic returns global topic" do
      assert Canopy.EventBus.logs_topic() == "logs:global"
    end
  end
end
