defmodule CanopyMCP.ProtocolTest do
  @moduledoc """
  Unit tests for the JSON-RPC 2.0 codec in CanopyMCP.Protocol.

  All tests are pure (no DB, no network) and run async.
  """

  use ExUnit.Case, async: true

  alias CanopyMCP.Protocol

  # ---------------------------------------------------------------------------
  # parse_request/1
  # ---------------------------------------------------------------------------

  describe "parse_request/1 — valid requests" do
    test "parses a well-formed notification (no id)" do
      raw = ~s({"jsonrpc":"2.0","method":"initialized"})
      assert {:ok, req} = Protocol.parse_request(raw)
      assert req["method"] == "initialized"
      refute Map.has_key?(req, "id")
    end

    test "parses a request with integer id" do
      raw = ~s({"jsonrpc":"2.0","method":"tools/list","id":1})
      assert {:ok, req} = Protocol.parse_request(raw)
      assert req["id"] == 1
      assert req["method"] == "tools/list"
    end

    test "parses a request with string id" do
      raw = ~s({"jsonrpc":"2.0","method":"initialize","id":"abc-123"})
      assert {:ok, req} = Protocol.parse_request(raw)
      assert req["id"] == "abc-123"
    end

    test "parses a request with params" do
      raw =
        ~s({"jsonrpc":"2.0","method":"tools/call","id":2,"params":{"name":"read_file","arguments":{"path":"/tmp/x"}}})

      assert {:ok, req} = Protocol.parse_request(raw)
      assert get_in(req, ["params", "name"]) == "read_file"
    end

    test "accepts extra unknown keys in the envelope" do
      raw = ~s({"jsonrpc":"2.0","method":"ping","id":5,"_extra":"ignored"})
      assert {:ok, _req} = Protocol.parse_request(raw)
    end
  end

  describe "parse_request/1 — invalid input" do
    test "returns parse error on non-JSON input" do
      assert {:error, {code, _msg}} = Protocol.parse_request("not json at all")
      assert code == Protocol.parse_error_code()
    end

    test "returns parse error on empty string" do
      assert {:error, {code, _msg}} = Protocol.parse_request("")
      assert code == Protocol.parse_error_code()
    end

    test "returns parse error on truncated JSON" do
      assert {:error, {code, _msg}} = Protocol.parse_request(~s({"jsonrpc":"2.0"))
      assert code == Protocol.parse_error_code()
    end

    test "returns invalid request when jsonrpc version is missing" do
      raw = ~s({"method":"tools/list","id":1})
      assert {:error, {code, _msg}} = Protocol.parse_request(raw)
      assert code == Protocol.invalid_request_code()
    end

    test "returns invalid request when jsonrpc version is wrong" do
      raw = ~s({"jsonrpc":"1.0","method":"tools/list","id":1})
      assert {:error, {code, _msg}} = Protocol.parse_request(raw)
      assert code == Protocol.invalid_request_code()
    end

    test "returns invalid request when method is missing" do
      raw = ~s({"jsonrpc":"2.0","id":1})
      assert {:error, {code, _msg}} = Protocol.parse_request(raw)
      assert code == Protocol.invalid_request_code()
    end

    test "returns invalid request when method is not a string" do
      raw = ~s({"jsonrpc":"2.0","method":42,"id":1})
      assert {:error, {code, _msg}} = Protocol.parse_request(raw)
      assert code == Protocol.invalid_request_code()
    end

    test "returns parse error on JSON array (batch — not supported)" do
      raw = ~s([{"jsonrpc":"2.0","method":"tools/list","id":1}])
      # Jason decodes this as a list, not a map → invalid request
      assert {:error, {_code, _msg}} = Protocol.parse_request(raw)
    end
  end

  # ---------------------------------------------------------------------------
  # encode_response/2
  # ---------------------------------------------------------------------------

  describe "encode_response/2" do
    test "encodes a successful response with integer id" do
      json = Protocol.encode_response(1, %{"tools" => []})
      decoded = Jason.decode!(json)
      assert decoded["jsonrpc"] == "2.0"
      assert decoded["id"] == 1
      assert decoded["result"] == %{"tools" => []}
      refute Map.has_key?(decoded, "error")
    end

    test "encodes a response with string id" do
      json = Protocol.encode_response("req-99", %{"ok" => true})
      decoded = Jason.decode!(json)
      assert decoded["id"] == "req-99"
    end

    test "encodes a response with nil id (notification reply)" do
      json = Protocol.encode_response(nil, %{})
      decoded = Jason.decode!(json)
      assert Map.has_key?(decoded, "id")
      assert decoded["id"] == nil
    end

    test "encodes a response with a list result" do
      json = Protocol.encode_response(1, [1, 2, 3])
      decoded = Jason.decode!(json)
      assert decoded["result"] == [1, 2, 3]
    end

    test "output is valid JSON" do
      json = Protocol.encode_response(42, %{"nested" => %{"deep" => true}})
      assert {:ok, _decoded} = Jason.decode(json)
    end
  end

  # ---------------------------------------------------------------------------
  # encode_error/3
  # ---------------------------------------------------------------------------

  describe "encode_error/3" do
    test "encodes an error with correct shape" do
      json = Protocol.encode_error(1, -32_601, "Method not found")
      decoded = Jason.decode!(json)
      assert decoded["jsonrpc"] == "2.0"
      assert decoded["id"] == 1
      assert decoded["error"]["code"] == -32_601
      assert decoded["error"]["message"] == "Method not found"
      refute Map.has_key?(decoded, "result")
    end

    test "encodes error with nil id for parse errors" do
      json = Protocol.encode_error(nil, -32_700, "Parse error")
      decoded = Jason.decode!(json)
      assert decoded["id"] == nil
      assert decoded["error"]["code"] == -32_700
    end

    test "output is valid JSON" do
      json = Protocol.encode_error(5, -32_603, "Internal error")
      assert {:ok, _decoded} = Jason.decode(json)
    end
  end

  # ---------------------------------------------------------------------------
  # Error code constants
  # ---------------------------------------------------------------------------

  describe "error code constants" do
    test "parse_error_code is -32700" do
      assert Protocol.parse_error_code() == -32_700
    end

    test "invalid_request_code is -32600" do
      assert Protocol.invalid_request_code() == -32_600
    end

    test "method_not_found_code is -32601" do
      assert Protocol.method_not_found_code() == -32_601
    end

    test "invalid_params_code is -32602" do
      assert Protocol.invalid_params_code() == -32_602
    end

    test "internal_error_code is -32603" do
      assert Protocol.internal_error_code() == -32_603
    end
  end
end
