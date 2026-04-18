defmodule Mix.Tasks.Canopy.Mcp do
  @shortdoc "Starts the Canopy MCP stdio server for external agent integration"

  @moduledoc """
  Starts the Canopy MCP (Model Context Protocol) server in stdio mode.

  The server speaks JSON-RPC 2.0 over stdin/stdout, allowing external AI
  agents and tools to call Canopy's tool registry via the MCP protocol.

  ## Usage

      mix canopy.mcp

  ## Connecting Claude CLI

  Register Canopy as an MCP server in your Claude CLI config
  (`~/.claude/mcp.json`) or pass it inline:

      claude --mcp-server "canopy:mix canopy.mcp"

  Or using the standalone binary wrapper:

      claude --mcp-server "canopy:/path/to/canopy/backend/priv/bin/canopy-mcp"

  ## Notes

  - The server reads from stdin and writes to stdout. Do not send anything
    else to stdout while the server is running.
  - Errors and warnings are written to stderr so they do not corrupt the
    JSON-RPC channel.
  - The server exits with status 0 on clean EOF (client disconnect) and
    non-zero on unexpected errors.
  - `Canopy.Tools.Registry` is not required to be running. When unavailable,
    `tools/list` returns a hardcoded stub list (see `CanopyMCP.ToolAdapter`).
  """

  use Mix.Task

  require Logger

  @impl Mix.Task
  def run(_args) do
    # Start only the minimal OTP tree needed for the MCP server.
    # We do not start the full Phoenix endpoint — this process is headless.
    Application.ensure_all_started(:canopy)

    Logger.info("[canopy-mcp] starting stdio server (protocol: 2024-11-05)")

    {:ok, pid} = CanopyMCP.Server.start_link(name: CanopyMCP.Server)

    # Block until the server process terminates. The GenServer's read loop
    # exits normally on EOF (client disconnect) or on error.
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, :normal} ->
        :ok

      {:DOWN, ^ref, :process, ^pid, reason} ->
        Logger.error("[canopy-mcp] server exited abnormally: #{inspect(reason)}")
        System.halt(1)
    end
  end
end
