defmodule Canopy.Tools do
  @moduledoc """
  Public API for the Canopy tool registry.

  Tools are functions that agents can invoke during execution. The registry
  maps tool names to implementations and exposes them via MCP (for capable
  runtimes) or system-prompt curl instructions (for non-MCP runtimes).

  ## Usage

      # List all registered tools
      Canopy.Tools.list()

      # List only MCP-exposed tools
      Canopy.Tools.list(mcp_exposed: true)

      # Dispatch a tool by name
      {:ok, result} = Canopy.Tools.dispatch("read_file", %{"path" => "/tmp/file.txt"})

  ## Boot

  Call `Canopy.Tools.register_all_builtins/0` after the Registry is started
  (the Application module does this in a supervised Task). This registers all
  tools declared in `Canopy.Tools.BuiltIn`.
  """

  alias Canopy.Tools.{BuiltIn, Registry}

  @doc """
  Lists registered tools.

  Accepts filter keywords forwarded to `Registry.list/1`:
    * `:requires` — filter by required capabilities
    * `:mcp_exposed` — filter by MCP exposure flag
    * `:prompt_exposed` — filter by prompt-injection flag
  """
  @spec list(keyword()) :: [Canopy.Tools.Tool.t()]
  def list(opts \\ []) do
    Registry.list(opts)
  end

  @doc """
  Dispatches a named tool call with the given args map.

  Returns `{:ok, result}` on success or `{:error, reason}` on failure.
  `:not_found` is returned when no tool with `name` is registered.
  """
  @spec dispatch(String.t(), map()) :: {:ok, term()} | {:error, term()}
  def dispatch(name, args) when is_binary(name) and is_map(args) do
    Registry.dispatch(name, args)
  end

  @doc """
  Same as `dispatch/2` but accepts opts. Pass `run_id:` to record a
  `tool_call` breadcrumb against the active run.
  """
  @spec dispatch(String.t(), map(), keyword()) :: {:ok, term()} | {:error, term()}
  def dispatch(name, args, opts) when is_binary(name) and is_map(args) and is_list(opts) do
    Registry.dispatch(name, args, opts)
  end

  @doc """
  Registers all tools declared in `Canopy.Tools.BuiltIn`.

  Called from the Application supervisor Task after the Registry GenServer
  is started. Idempotent — re-registering overwrites existing entries.
  """
  @spec register_all_builtins() :: :ok
  def register_all_builtins do
    Registry.register_module(BuiltIn)
  end
end
