defmodule CanopyMCP.Server do
  @moduledoc """
  MCP stdio server for Canopy.

  Reads JSON-RPC 2.0 requests from stdin, writes responses to stdout, and
  logs errors to stderr. Handles: `initialize`, `tools/list`, `tools/call`,
  `resources/list`, `prompts/list`. Never crashes on bad input — parse and
  method errors are returned as JSON-RPC error responses. Exits cleanly on EOF.

  Pass `test_mode: true` to `start_link/1` to suppress the stdio read loop
  and use `handle_line/2` for synchronous testing instead.
  """

  use GenServer

  alias CanopyMCP.{Capabilities, Protocol, ToolAdapter}

  require Logger

  @type state :: %{initialized: boolean(), test_mode: boolean()}

  # Client API

  @doc "Starts the MCP server. Pass `name:` and/or `test_mode: true` in opts."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, Keyword.take(opts, [:name]))
  end

  @doc "Sends a raw JSON-RPC line for processing. Returns the encoded response. Test use only."
  @spec handle_line(GenServer.server(), binary()) :: binary()
  def handle_line(server, line), do: GenServer.call(server, {:line, line})

  # GenServer callbacks

  @impl true
  @spec init(keyword()) :: {:ok, state()}
  def init(opts) do
    state = %{initialized: false, test_mode: Keyword.get(opts, :test_mode, false)}

    unless state.test_mode do
      :ok = :io.setopts(:standard_io, binary: true, encoding: :latin1)
      send(self(), :read_loop)
    end

    {:ok, state}
  end

  @impl true
  def handle_info(:read_loop, state) do
    case IO.read(:stdio, :line) do
      :eof ->
        Logger.info("[canopy-mcp] EOF — shutting down cleanly")
        {:stop, :normal, state}

      {:error, reason} ->
        Logger.error("[canopy-mcp] stdin error: #{inspect(reason)}")
        {:stop, reason, state}

      line when is_binary(line) ->
        trimmed = String.trim(line)

        new_state =
          if trimmed == "" do
            state
          else
            response = dispatch_line(trimmed, state)
            IO.puts(:stdio, response)
            update_state_after(trimmed, state)
          end

        send(self(), :read_loop)
        {:noreply, new_state}
    end
  end

  def handle_info(msg, state) do
    Logger.debug("[canopy-mcp] unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def handle_call({:line, line}, _from, state) do
    trimmed = String.trim(line)

    if trimmed == "" do
      {:reply, "", state}
    else
      response = dispatch_line(trimmed, state)
      {:reply, response, update_state_after(trimmed, state)}
    end
  end

  # Private dispatch

  @spec dispatch_line(binary(), state()) :: binary()
  defp dispatch_line(line, state) do
    case Protocol.parse_request(line) do
      {:ok, req} -> handle_request(req, state)
      {:error, {code, message}} -> Protocol.encode_error(nil, code, message)
    end
  end

  @spec handle_request(map(), state()) :: binary()
  defp handle_request(%{"method" => "initialize", "id" => id}, _state),
    do: Protocol.encode_response(id, Capabilities.initialize_result())

  defp handle_request(%{"method" => "initialized"}, _state), do: ""

  defp handle_request(%{"method" => "tools/list", "id" => id}, _state),
    do: Protocol.encode_response(id, %{"tools" => ToolAdapter.list_mcp_tools()})

  defp handle_request(%{"method" => "tools/call", "id" => id} = req, _state) do
    params = Map.get(req, "params", %{})
    tool_name = Map.get(params, "name")
    arguments = Map.get(params, "arguments", %{})

    cond do
      is_nil(tool_name) ->
        Protocol.encode_error(id, Protocol.invalid_params_code(), "Missing required param: name")

      not is_binary(tool_name) ->
        Protocol.encode_error(id, Protocol.invalid_params_code(), "Param 'name' must be a string")

      true ->
        call_tool(id, tool_name, arguments)
    end
  end

  defp handle_request(%{"method" => "resources/list", "id" => id}, _state),
    do: Protocol.encode_response(id, %{"resources" => []})

  defp handle_request(%{"method" => "prompts/list", "id" => id}, _state),
    do: Protocol.encode_response(id, %{"prompts" => []})

  defp handle_request(%{"method" => method, "id" => id}, _state) do
    Logger.warning("[canopy-mcp] unknown method: #{method}")
    Protocol.encode_error(id, Protocol.method_not_found_code(), "Method not found: #{method}")
  end

  # Notifications without id — silently ignored.
  defp handle_request(%{"method" => _method}, _state), do: ""

  @spec call_tool(Protocol.rpc_id(), String.t(), map()) :: binary()
  defp call_tool(id, tool_name, arguments) do
    # apply/3 is intentional: prevents the Elixir type-checker from proving the
    # return type of Canopy.Tools.dispatch/2 statically during the stub period
    # (Track F). Remove once the real registry is in place.
    # credo:disable-for-next-line Credo.Check.Refactor.Apply
    case apply(Canopy.Tools, :dispatch, [tool_name, arguments]) do
      {:ok, result} ->
        Protocol.encode_response(id, %{"content" => to_content(result), "isError" => false})

      {:error, :not_found} ->
        Protocol.encode_error(
          id,
          Protocol.method_not_found_code(),
          "Tool not found: #{tool_name}"
        )

      {:error, :not_implemented} ->
        Protocol.encode_error(
          id,
          Protocol.internal_error_code(),
          "Tool not yet implemented: #{tool_name}"
        )

      {:error, reason} ->
        Logger.error("[canopy-mcp] dispatch error: #{inspect(reason)}")
        Protocol.encode_error(id, Protocol.internal_error_code(), "Internal error")
    end
  rescue
    err ->
      Logger.error("[canopy-mcp] dispatch raised: #{inspect(err)}")
      Protocol.encode_error(id, Protocol.internal_error_code(), "Internal error")
  end

  @spec to_content(map() | binary() | term()) :: [map()]
  defp to_content(r) when is_binary(r), do: [%{"type" => "text", "text" => r}]
  defp to_content(r) when is_map(r), do: [%{"type" => "text", "text" => Jason.encode!(r)}]
  defp to_content(r), do: [%{"type" => "text", "text" => inspect(r)}]

  @spec update_state_after(binary(), state()) :: state()
  defp update_state_after(line, state) do
    case Jason.decode(line) do
      {:ok, %{"method" => "initialize"}} -> %{state | initialized: true}
      _other -> state
    end
  rescue
    _err -> state
  end
end
