defmodule CanopyWeb.ToolsControllerTest do
  @moduledoc """
  Tests for GET /api/v1/tools, GET /api/v1/tools/:name,
  POST /api/v1/tools/:name/dispatch.

  Uses the real ETS-backed `Canopy.Tools.Registry`. Built-in tools are
  registered at boot, so the index always has at least 6 entries.
  """

  use CanopyWeb.ConnCase, async: false

  alias Canopy.Tools.Registry
  alias Canopy.Tools.Tool

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp unique_name(base), do: "#{base}-#{System.unique_integer([:positive])}"

  def noop_handler(_args), do: {:ok, "noop_result"}
  def echo_handler(%{"value" => v}), do: {:ok, v}
  def error_handler(_args), do: {:error, :simulated_failure}

  defp register_test_tool(name, opts \\ []) do
    tool = %Tool{
      name: name,
      description: opts[:description] || "Controller test tool",
      parameters: %{"type" => "object", "properties" => %{}},
      handler: opts[:handler] || {__MODULE__, :noop_handler, []},
      requires: opts[:requires] || [],
      mcp_exposed: Keyword.get(opts, :mcp_exposed, true),
      prompt_exposed: Keyword.get(opts, :prompt_exposed, true)
    }

    Registry.register(tool)
    tool
  end

  setup do
    # Ensure built-ins are registered for every test
    Canopy.Tools.register_all_builtins()
    :ok
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/tools
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/tools" do
    test "returns 200 with a data list", %{conn: conn} do
      conn = get(conn, "/api/v1/tools")
      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data)
    end

    test "includes built-in tools in the response", %{conn: conn} do
      conn = get(conn, "/api/v1/tools")
      assert %{"data" => data} = json_response(conn, 200)
      names = Enum.map(data, & &1["name"])
      assert "read_file" in names
      assert "list_directory" in names
      assert "log_message" in names
    end

    test "each tool entry has required fields", %{conn: conn} do
      conn = get(conn, "/api/v1/tools")
      assert %{"data" => [tool | _]} = json_response(conn, 200)
      assert Map.has_key?(tool, "name")
      assert Map.has_key?(tool, "description")
      assert Map.has_key?(tool, "parameters")
      assert Map.has_key?(tool, "mcp_exposed")
      assert Map.has_key?(tool, "prompt_exposed")
    end

    test "filters by mcp_exposed=true", %{conn: conn} do
      name = unique_name("ctrl-mcp-no")
      register_test_tool(name, mcp_exposed: false)
      on_exit(fn -> Registry.unregister(name) end)

      conn = get(conn, "/api/v1/tools?mcp_exposed=true")
      assert %{"data" => data} = json_response(conn, 200)
      names = Enum.map(data, & &1["name"])
      refute name in names
    end

    test "filters by mcp_exposed=false", %{conn: conn} do
      name = unique_name("ctrl-mcp-no2")
      register_test_tool(name, mcp_exposed: false)
      on_exit(fn -> Registry.unregister(name) end)

      conn = get(conn, "/api/v1/tools?mcp_exposed=false")
      assert %{"data" => data} = json_response(conn, 200)
      names = Enum.map(data, & &1["name"])
      assert name in names
    end

    test "filters by prompt_exposed=false", %{conn: conn} do
      name = unique_name("ctrl-prompt-no")
      register_test_tool(name, prompt_exposed: false)
      on_exit(fn -> Registry.unregister(name) end)

      conn = get(conn, "/api/v1/tools?prompt_exposed=false")
      assert %{"data" => data} = json_response(conn, 200)
      names = Enum.map(data, & &1["name"])
      assert name in names
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/tools/:name
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/tools/:name" do
    test "returns 200 with tool detail for a known tool", %{conn: conn} do
      conn = get(conn, "/api/v1/tools/read_file")
      assert body = json_response(conn, 200)
      assert body["name"] == "read_file"
      assert is_binary(body["description"])
      assert is_map(body["parameters"])
      assert is_list(body["requires"])
    end

    test "returns 404 for an unknown tool name", %{conn: conn} do
      conn = get(conn, "/api/v1/tools/no-such-tool-xyz")
      assert json_response(conn, 404)
    end

    test "returns detail for a dynamically registered tool", %{conn: conn} do
      name = unique_name("ctrl-show")
      register_test_tool(name, description: "Show me test")
      on_exit(fn -> Registry.unregister(name) end)

      conn = get(conn, "/api/v1/tools/#{name}")
      assert body = json_response(conn, 200)
      assert body["name"] == name
      assert body["description"] == "Show me test"
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/tools/:name/dispatch
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/tools/:name/dispatch" do
    test "returns 200 with result on successful dispatch", %{conn: conn} do
      name = unique_name("ctrl-dispatch-ok")
      register_test_tool(name, handler: {__MODULE__, :echo_handler, []})
      on_exit(fn -> Registry.unregister(name) end)

      conn =
        post(conn, "/api/v1/tools/#{name}/dispatch", %{"args" => %{"value" => "hello"}})

      assert %{"result" => "hello"} = json_response(conn, 200)
    end

    test "returns 404 for unknown tool name", %{conn: conn} do
      conn = post(conn, "/api/v1/tools/nonexistent-xyz/dispatch", %{"args" => %{}})
      assert json_response(conn, 404)
    end

    test "returns 422 when handler returns an error", %{conn: conn} do
      name = unique_name("ctrl-dispatch-fail")
      register_test_tool(name, handler: {__MODULE__, :error_handler, []})
      on_exit(fn -> Registry.unregister(name) end)

      conn = post(conn, "/api/v1/tools/#{name}/dispatch", %{"args" => %{}})
      assert %{"error" => "dispatch_failed"} = json_response(conn, 422)
    end

    test "returns 400 when args is missing from body", %{conn: conn} do
      name = unique_name("ctrl-dispatch-bad")
      register_test_tool(name)
      on_exit(fn -> Registry.unregister(name) end)

      conn = post(conn, "/api/v1/tools/#{name}/dispatch", %{})
      assert json_response(conn, 400)
    end

    test "dispatches log_message built-in tool successfully", %{conn: conn} do
      conn =
        post(conn, "/api/v1/tools/log_message/dispatch", %{
          "args" => %{"level" => "info", "message" => "controller test log"}
        })

      assert %{"result" => result} = json_response(conn, 200)
      assert result["logged"] == true
    end
  end
end
