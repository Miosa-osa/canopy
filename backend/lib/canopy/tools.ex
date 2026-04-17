defmodule Canopy.Tools do
  @moduledoc """
  Public API for the Canopy tool registry.

  Tools are functions agents can call during execution. The registry maps tool
  names to implementations and generates schema declarations for Claude, OpenAI,
  and MCP formats from a single definition (Core-OSS `@tool` decorator pattern
  ported to Elixir macros).

  A tool definition includes: name, description, parameter schema, and the
  Elixir function that executes it. The `dispatch/2` function routes a tool
  call from a transcript entry to the correct handler.

  All functions currently return `{:error, :not_implemented}`. Full implementation
  is Week 1/2 scope.
  """

  @doc "Registers a tool definition in the registry."
  @spec register(map()) :: {:ok, map()} | {:error, :not_implemented}
  def register(_tool_definition) do
    {:error, :not_implemented}
  end

  @doc "Lists all registered tools."
  @spec list() :: {:ok, [map()]} | {:error, :not_implemented}
  def list do
    {:error, :not_implemented}
  end

  @doc "Dispatches a tool call to its registered handler."
  @spec dispatch(String.t(), map()) :: {:ok, map()} | {:error, :not_found | :not_implemented}
  def dispatch(_tool_name, _args) do
    {:error, :not_implemented}
  end
end
