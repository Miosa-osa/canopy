defmodule CanopyMCP.ServerTest do
  @moduledoc """
  Round-trip tests for CanopyMCP.Server using the `handle_line/2` test API.

  We bypass stdio entirely: each test starts a server process in test_mode,
  sends raw JSON-RPC strings via `handle_line/2`, and asserts on the decoded
  response. This exercises the full dispatch path without process port tricks.

  Tests run async — each test gets its own GenServer pid with no shared state.
  """

  use ExUnit.Case, async: true

  alias CanopyMCP.Server

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Sends a line and decodes the JSON response. Returns :empty for blank responses.
  defp rpc(server, line) do
    response = Server.handle_line(server, line)

    if response == "" do
      :empty
    else
      Jason.decode!(response)
    end
  end

  # ---------------------------------------------------------------------------
  # Setup — one server process per test, no stdio, no name registration
  # ---------------------------------------------------------------------------

  setup do
    # test_mode: true skips the :io.setopts call and the :read_loop message,
    # so the process never tries to read from stdin during tests.
    pid = start_supervised!({Server, [test_mode: true]})
    %{server: pid}
  end

  # ---------------------------------------------------------------------------
  # initialize
  # ---------------------------------------------------------------------------

  describe "initialize" do
    test "returns server capabilities with correct shape", %{server: server} do
      req = ~s({"jsonrpc":"2.0","method":"initialize","id":1})
      resp = rpc(server, req)

      assert resp["jsonrpc"] == "2.0"
      assert resp["id"] == 1
      assert is_map(resp["result"])

      result = resp["result"]
      assert result["protocolVersion"] == "2024-11-05"
      assert result["serverInfo"]["name"] == "canopy-mcp"
      assert result["serverInfo"]["version"] == "0.1.0"
      assert is_map(result["capabilities"])
    end

    test "capabilities includes tools, resources, prompts", %{server: server} do
      req = ~s({"jsonrpc":"2.0","method":"initialize","id":2})
      resp = rpc(server, req)
      caps = resp["result"]["capabilities"]

      assert Map.has_key?(caps, "tools")
      assert Map.has_key?(caps, "resources")
      assert Map.has_key?(caps, "prompts")
    end
  end

  # ---------------------------------------------------------------------------
  # tools/list
  # ---------------------------------------------------------------------------

  describe "tools/list" do
    test "returns a non-empty list of tools", %{server: server} do
      req = ~s({"jsonrpc":"2.0","method":"tools/list","id":3})
      resp = rpc(server, req)

      assert resp["id"] == 3
      tools = resp["result"]["tools"]
      assert is_list(tools)
      assert tools != []
    end

    test "each tool has name, description, inputSchema", %{server: server} do
      req = ~s({"jsonrpc":"2.0","method":"tools/list","id":4})
      resp = rpc(server, req)

      for tool <- resp["result"]["tools"] do
        assert Map.has_key?(tool, "name")
        assert Map.has_key?(tool, "description")
        assert Map.has_key?(tool, "inputSchema")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # tools/call
  # ---------------------------------------------------------------------------

  describe "tools/call" do
    test "returns an error response for unknown tool", %{server: server} do
      req =
        Jason.encode!(%{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "id" => 5,
          "params" => %{"name" => "does_not_exist", "arguments" => %{}}
        })

      resp = rpc(server, req)

      # Canopy.Tools.dispatch returns {:error, :not_found} or {:error, :not_implemented}
      # Both map to an error response.
      assert Map.has_key?(resp, "error")
      assert is_integer(resp["error"]["code"])
    end

    test "returns invalid_params when name is missing", %{server: server} do
      req =
        Jason.encode!(%{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "id" => 6,
          "params" => %{"arguments" => %{}}
        })

      resp = rpc(server, req)

      assert resp["error"]["code"] == CanopyMCP.Protocol.invalid_params_code()
    end

    test "returns invalid_params when name is not a string", %{server: server} do
      req =
        Jason.encode!(%{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "id" => 7,
          "params" => %{"name" => 42, "arguments" => %{}}
        })

      resp = rpc(server, req)

      assert resp["error"]["code"] == CanopyMCP.Protocol.invalid_params_code()
    end
  end

  # ---------------------------------------------------------------------------
  # resources/list and prompts/list
  # ---------------------------------------------------------------------------

  describe "resources/list" do
    test "returns empty resources list", %{server: server} do
      req = ~s({"jsonrpc":"2.0","method":"resources/list","id":10})
      resp = rpc(server, req)

      assert resp["result"]["resources"] == []
    end
  end

  describe "prompts/list" do
    test "returns empty prompts list", %{server: server} do
      req = ~s({"jsonrpc":"2.0","method":"prompts/list","id":11})
      resp = rpc(server, req)

      assert resp["result"]["prompts"] == []
    end
  end

  # ---------------------------------------------------------------------------
  # Error handling
  # ---------------------------------------------------------------------------

  describe "error handling" do
    test "returns parse error for non-JSON input", %{server: server} do
      resp = rpc(server, "this is not json")

      assert resp["error"]["code"] == CanopyMCP.Protocol.parse_error_code()
    end

    test "returns method_not_found for unknown method", %{server: server} do
      req = ~s({"jsonrpc":"2.0","method":"nonexistent/method","id":20})
      resp = rpc(server, req)

      assert resp["error"]["code"] == CanopyMCP.Protocol.method_not_found_code()
    end

    test "returns invalid_request when jsonrpc version is missing", %{server: server} do
      req = ~s({"method":"tools/list","id":21})
      resp = rpc(server, req)

      assert resp["error"]["code"] == CanopyMCP.Protocol.invalid_request_code()
    end

    test "notification with no id returns empty response", %{server: server} do
      req = ~s({"jsonrpc":"2.0","method":"initialized"})
      result = rpc(server, req)

      assert result == :empty
    end

    test "blank line returns empty response", %{server: server} do
      result = rpc(server, "   ")
      assert result == :empty
    end
  end

  # ---------------------------------------------------------------------------
  # Response shape invariants
  # ---------------------------------------------------------------------------

  describe "response shape" do
    test "every non-notification response has jsonrpc 2.0", %{server: server} do
      for {method, id} <- [
            {"initialize", 100},
            {"tools/list", 101},
            {"resources/list", 102},
            {"prompts/list", 103}
          ] do
        req = Jason.encode!(%{"jsonrpc" => "2.0", "method" => method, "id" => id})
        resp = rpc(server, req)
        assert resp["jsonrpc"] == "2.0", "expected jsonrpc 2.0 for method #{method}"
      end
    end

    test "every response id matches the request id", %{server: server} do
      req = ~s({"jsonrpc":"2.0","method":"tools/list","id":999})
      resp = rpc(server, req)
      assert resp["id"] == 999
    end

    test "success responses have no error key", %{server: server} do
      req = ~s({"jsonrpc":"2.0","method":"tools/list","id":200})
      resp = rpc(server, req)
      refute Map.has_key?(resp, "error")
    end

    test "error responses have no result key", %{server: server} do
      req = ~s({"method":"bad","id":201})
      resp = rpc(server, req)
      refute Map.has_key?(resp, "result")
    end
  end
end
