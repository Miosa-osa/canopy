defmodule CanopyMCP.Protocol do
  @moduledoc """
  JSON-RPC 2.0 codec for the MCP stdio transport.

  Handles parse, encode, and error formatting per the JSON-RPC 2.0 spec and
  the MCP error code table (https://spec.modelcontextprotocol.io/specification/).

  MCP error codes:
    -32700  Parse error      — invalid JSON received
    -32600  Invalid request  — JSON-RPC envelope is malformed
    -32601  Method not found — method is not implemented
    -32602  Invalid params   — method params are invalid
    -32603  Internal error   — server-side runtime error

  All functions are pure and have no side effects.
  """

  @parse_error -32_700
  @invalid_request -32_600
  @method_not_found -32_601
  @invalid_params -32_602
  @internal_error -32_603

  @type rpc_id :: String.t() | integer() | nil
  @type rpc_request :: %{
          required(:jsonrpc) => String.t(),
          required(:method) => String.t(),
          optional(:id) => rpc_id(),
          optional(:params) => map()
        }
  @type rpc_response :: map()
  @type parse_error_reason ::
          :parse_error | :invalid_request | :method_not_found | :invalid_params | :internal_error

  @doc """
  Parses a raw JSON binary into a validated JSON-RPC 2.0 request map.

  Returns `{:ok, request}` on success, or `{:error, {code, message}}` on
  failure so the caller can send an error response back to the client.

  ## Examples

      iex> CanopyMCP.Protocol.parse_request(~s({"jsonrpc":"2.0","method":"tools/list","id":1}))
      {:ok, %{"jsonrpc" => "2.0", "method" => "tools/list", "id" => 1}}

      iex> CanopyMCP.Protocol.parse_request("not json")
      {:error, {@parse_error, "Parse error"}}
  """
  @spec parse_request(binary()) ::
          {:ok, rpc_request()} | {:error, {integer(), String.t()}}
  def parse_request(raw) when is_binary(raw) do
    case Jason.decode(raw) do
      {:ok, decoded} ->
        validate_envelope(decoded)

      {:error, _reason} ->
        {:error, {@parse_error, "Parse error"}}
    end
  end

  @doc """
  Encodes a successful JSON-RPC 2.0 response.

  The `id` must match the `id` from the originating request. Pass `nil` for
  notifications (responses without an id).
  """
  @spec encode_response(rpc_id(), map() | list()) :: binary()
  def encode_response(id, result) do
    Jason.encode!(%{
      "jsonrpc" => "2.0",
      "id" => id,
      "result" => result
    })
  end

  @doc """
  Encodes a JSON-RPC 2.0 error response.

  `code` should be one of the standard MCP error codes defined in this module.
  `message` is a human-readable description of the error.
  """
  @spec encode_error(rpc_id(), integer(), String.t()) :: binary()
  def encode_error(id, code, message) do
    Jason.encode!(%{
      "jsonrpc" => "2.0",
      "id" => id,
      "error" => %{
        "code" => code,
        "message" => message
      }
    })
  end

  @doc "Standard MCP parse error code (-32700)."
  @spec parse_error_code() :: integer()
  def parse_error_code, do: @parse_error

  @doc "Standard MCP invalid request code (-32600)."
  @spec invalid_request_code() :: integer()
  def invalid_request_code, do: @invalid_request

  @doc "Standard MCP method not found code (-32601)."
  @spec method_not_found_code() :: integer()
  def method_not_found_code, do: @method_not_found

  @doc "Standard MCP invalid params code (-32602)."
  @spec invalid_params_code() :: integer()
  def invalid_params_code, do: @invalid_params

  @doc "Standard MCP internal error code (-32603)."
  @spec internal_error_code() :: integer()
  def internal_error_code, do: @internal_error

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec validate_envelope(map()) ::
          {:ok, rpc_request()} | {:error, {integer(), String.t()}}
  defp validate_envelope(%{"jsonrpc" => "2.0", "method" => method} = req)
       when is_binary(method) do
    {:ok, req}
  end

  defp validate_envelope(_other) do
    {:error, {@invalid_request, "Invalid Request"}}
  end
end
