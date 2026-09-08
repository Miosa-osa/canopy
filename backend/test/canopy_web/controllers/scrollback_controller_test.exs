defmodule CanopyWeb.ScrollbackControllerTest do
  @moduledoc """
  Controller tests for GET /api/v1/sessions/:id/scrollback.
  """

  use CanopyWeb.ConnCase, async: true

  alias Canopy.Sessions.ScrollbackStore

  @moduletag :capture_log

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "GET /api/v1/sessions/:id/scrollback — store not running (no session)" do
    test "returns empty payload when no log exists", %{conn: conn} do
      fake_id = "nonexistent-#{System.unique_integer([:positive])}"
      conn = get(conn, ~p"/api/v1/sessions/#{fake_id}/scrollback")
      assert json_response(conn, 200)["data"] == ""
      assert json_response(conn, 200)["total_bytes"] == 0
      assert json_response(conn, 200)["truncated"] == false
    end
  end

  describe "GET /api/v1/sessions/:id/scrollback — store running" do
    setup do
      session_id = "ctrl-test-#{System.unique_integer([:positive])}"

      # ExUnit stops the store before on_exit removes its log file.
      pid = start_supervised!({ScrollbackStore, session_id})

      # Write some bytes into the store.
      send(pid, {:pty_output, "hello scrollback\n"})
      :sys.get_state(pid)

      on_exit(fn ->
        log_path = Path.join([System.user_home!(), ".canopy", "scrollback", "#{session_id}.log"])
        File.rm(log_path)
      end)

      {:ok, session_id: session_id}
    end

    test "the test supervisor completes store shutdown before cleanup", %{session_id: session_id} do
      [{pid, _}] = Registry.lookup(Canopy.Sessions.ScrollbackRegistry, session_id)
      monitor = Process.monitor(pid)
      assert :ok = stop_supervised({ScrollbackStore, session_id})
      assert_receive {:DOWN, ^monitor, :process, ^pid, :shutdown}
      on_exit(fn -> refute Process.alive?(pid) end)
    end

    test "returns base64-encoded pty bytes", %{conn: conn, session_id: session_id} do
      conn = get(conn, ~p"/api/v1/sessions/#{session_id}/scrollback")
      body = json_response(conn, 200)

      assert body["session_id"] == session_id
      assert body["total_bytes"] > 0
      decoded = Base.decode64!(body["data"])
      assert decoded =~ "hello scrollback"
    end

    test "respects last_n query param", %{conn: conn, session_id: session_id} do
      conn = get(conn, ~p"/api/v1/sessions/#{session_id}/scrollback?last_n=5")
      body = json_response(conn, 200)
      assert body["total_bytes"] > 0
    end

    test "respects from query param", %{conn: conn, session_id: session_id} do
      conn_full = get(conn, ~p"/api/v1/sessions/#{session_id}/scrollback")
      total = json_response(conn_full, 200)["total_bytes"]

      # Reading from total bytes should return empty data (tail of file).
      conn2 = get(build_conn(), ~p"/api/v1/sessions/#{session_id}/scrollback?from=#{total}")
      body2 = json_response(conn2, 200)
      assert Base.decode64!(body2["data"]) == ""
    end
  end
end
