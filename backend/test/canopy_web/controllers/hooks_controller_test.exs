defmodule CanopyWeb.HooksControllerTest do
  @moduledoc """
  Controller tests for HooksController.

  Covers:
    POST /api/v1/hooks/notify   — accepts valid payload, inserts row, returns 200
    POST /api/v1/hooks/notify   — unknown event falls through gracefully
    POST /api/v1/hooks/install  — triggers manager, returns results map
    POST /api/v1/hooks/uninstall — triggers manager, returns results map
    GET  /api/v1/hooks/status   — returns runtimes + recent events
  """

  use CanopyWeb.ConnCase, async: true

  alias Canopy.Hooks.HookEvent
  alias Canopy.Repo

  # ---------------------------------------------------------------------------
  # POST /api/v1/hooks/notify
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/hooks/notify" do
    test "accepts a claude PostToolUse payload, inserts a row, returns 200", %{conn: conn} do
      payload = %{
        "agent" => "claude",
        "event" => "PostToolUse",
        "session_id" => "sess-abc-123",
        "hook_event_name" => "PostToolUse",
        "tool_name" => "Bash",
        "tool_input" => %{"command" => "mix test"},
        "cwd" => "/home/user/project"
      }

      conn = post(conn, "/api/v1/hooks/notify", payload)
      body = json_response(conn, 200)

      assert body["ok"] == true
      assert is_binary(body["hook_event_id"])

      row = Repo.get!(HookEvent, body["hook_event_id"])
      assert row.agent == "claude"
      assert row.event == "PostToolUse"
      assert row.session_id == "sess-abc-123"
    end

    test "defaults agent to claude when field absent", %{conn: conn} do
      payload = %{
        "hook_event_name" => "Stop",
        "session_id" => "sess-no-agent"
      }

      conn = post(conn, "/api/v1/hooks/notify", payload)
      body = json_response(conn, 200)

      assert body["ok"] == true
      row = Repo.get!(HookEvent, body["hook_event_id"])
      assert row.agent == "claude"
      assert row.event == "Stop"
    end

    test "accepts UserPromptSubmit event", %{conn: conn} do
      payload = %{
        "agent" => "claude",
        "hook_event_name" => "UserPromptSubmit",
        "session_id" => "sess-prompt"
      }

      conn = post(conn, "/api/v1/hooks/notify", payload)
      body = json_response(conn, 200)

      assert body["ok"] == true
      row = Repo.get!(HookEvent, body["hook_event_id"])
      assert row.event == "UserPromptSubmit"
    end

    test "accepts PermissionRequest event", %{conn: conn} do
      payload = %{
        "agent" => "claude",
        "hook_event_name" => "PermissionRequest",
        "tool_name" => "Bash"
      }

      conn = post(conn, "/api/v1/hooks/notify", payload)
      assert json_response(conn, 200)["ok"] == true
    end

    test "session_id is nullable — payload without session_id inserts row", %{conn: conn} do
      payload = %{
        "agent" => "claude",
        "hook_event_name" => "Stop"
      }

      conn = post(conn, "/api/v1/hooks/notify", payload)
      body = json_response(conn, 200)
      assert body["ok"] == true

      row = Repo.get!(HookEvent, body["hook_event_id"])
      assert is_nil(row.session_id)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/hooks/install
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/hooks/install" do
    test "returns 200 with results map", %{conn: conn} do
      conn = post(conn, "/api/v1/hooks/install", %{})
      body = json_response(conn, 200)

      assert body["ok"] == true
      assert is_map(body["results"])
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/hooks/uninstall
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/hooks/uninstall" do
    test "returns 200 with results map", %{conn: conn} do
      conn = post(conn, "/api/v1/hooks/uninstall", %{})
      body = json_response(conn, 200)

      assert body["ok"] == true
      assert is_map(body["results"])
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/hooks/status
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/hooks/status" do
    test "returns runtimes map and recent_events list", %{conn: conn} do
      conn = get(conn, "/api/v1/hooks/status")
      body = json_response(conn, 200)

      assert body["ok"] == true
      assert is_map(body["runtimes"])
      assert is_list(body["recent_events"])
    end

    test "recent_events includes newly inserted hook event", %{conn: conn} do
      # Insert an event first
      post(conn, "/api/v1/hooks/notify", %{
        "agent" => "claude",
        "hook_event_name" => "PostToolUse"
      })

      conn2 = build_conn()
      conn2 = get(conn2, "/api/v1/hooks/status")
      body = json_response(conn2, 200)

      assert length(body["recent_events"]) >= 1
    end

    test "recent_events capped at 20", %{conn: conn} do
      for _i <- 1..25 do
        post(conn, "/api/v1/hooks/notify", %{
          "agent" => "claude",
          "hook_event_name" => "Stop"
        })
      end

      conn2 = build_conn()
      conn2 = get(conn2, "/api/v1/hooks/status")
      body = json_response(conn2, 200)

      assert length(body["recent_events"]) <= 20
    end
  end
end
