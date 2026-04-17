defmodule CanopyWeb.RuntimesControllerTest do
  @moduledoc """
  Tests for GET /api/v1/runtimes, GET /api/v1/runtimes/:type,
  POST /api/v1/runtimes/:type/test, GET /api/v1/runtimes/:type/models.

  Uses real DB rows for runtimes and the real ClaudeLocal adapter that is
  already registered on boot. Does not spawn actual subprocesses.
  """

  use CanopyWeb.ConnCase, async: false

  import Canopy.Factory

  alias Canopy.Runtimes
  alias Canopy.Runtimes.{ClaudeLocal, RegistryServer}

  @claude_type "claude-local"

  # Register the ClaudeLocal adapter for tests that need it.
  # RegistryServer is an ETS-backed GenServer; registration persists until
  # explicitly unregistered (or the app stops), so these helpers are simple.
  # Most tests won't need these — ClaudeLocal is auto-registered on app boot.
  defp register_claude_adapter do
    RegistryServer.register(ClaudeLocal)
  end

  defp unregister_claude_adapter do
    RegistryServer.unregister(@claude_type)
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/runtimes
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/runtimes" do
    test "returns 200 with empty list when no runtime rows exist", %{conn: conn} do
      conn = get(conn, "/api/v1/runtimes")
      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data)
    end

    test "returns persisted runtime rows", %{conn: conn} do
      insert(:runtime, type: "test-runtime-index", name: "Test Runtime Index")
      conn = get(conn, "/api/v1/runtimes")
      assert %{"data" => data} = json_response(conn, 200)
      types = Enum.map(data, & &1["type"])
      assert "test-runtime-index" in types
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/runtimes/:type
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/runtimes/:type" do
    test "returns 404 when runtime type not in DB and not registered", %{conn: conn} do
      conn = get(conn, "/api/v1/runtimes/no-such-runtime")
      assert json_response(conn, 404)
    end

    test "returns detail for claude-local when adapter is registered and row exists", %{
      conn: conn
    } do
      register_claude_adapter()
      on_exit(&unregister_claude_adapter/0)

      # Ensure the runtime row exists
      Runtimes.upsert_from_detection(%{
        type: @claude_type,
        kind: "cli",
        name: "Claude Code",
        installed: true,
        version: "1.0.0"
      })

      conn = get(conn, "/api/v1/runtimes/#{@claude_type}")
      assert body = json_response(conn, 200)
      assert body["type"] == @claude_type
      assert is_list(body["capabilities"])
      assert is_list(body["config_schema"])
      assert is_list(body["models"])
    end

    test "returns 404 when row exists but adapter not registered", %{conn: conn} do
      # Insert a runtime row for a type that has no registered adapter
      insert(:runtime, type: "unregistered-adapter-xyz", name: "Ghost Runtime")
      conn = get(conn, "/api/v1/runtimes/unregistered-adapter-xyz")
      # get_by_type succeeds but lookup_adapter returns :not_found
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/runtimes/:type/test
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/runtimes/:type/test" do
    test "returns 404 when adapter not registered", %{conn: conn} do
      conn = post(conn, "/api/v1/runtimes/ghost-runtime/test")
      assert json_response(conn, 404)
    end

    test "returns check results for registered adapter", %{conn: conn} do
      register_claude_adapter()
      on_exit(&unregister_claude_adapter/0)

      conn = post(conn, "/api/v1/runtimes/#{@claude_type}/test")
      # The adapter runs test_environment — it may succeed or fail depending on
      # whether claude binary is installed. Either way we get a structured response.
      body = json_response(conn, 200)
      assert is_list(body["checks"])
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/runtimes/:type/models
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/runtimes/:type/models" do
    test "returns 404 when adapter not registered", %{conn: conn} do
      conn = get(conn, "/api/v1/runtimes/no-such-runtime/models")
      assert json_response(conn, 404)
    end

    test "returns model list for claude-local", %{conn: conn} do
      register_claude_adapter()
      on_exit(&unregister_claude_adapter/0)

      conn = get(conn, "/api/v1/runtimes/#{@claude_type}/models")
      assert %{"data" => models} = json_response(conn, 200)
      assert is_list(models)
      assert models != []
    end
  end
end
