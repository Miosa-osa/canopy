defmodule Canopy.Tools.Registry do
  @moduledoc """
  In-memory tool registry backed by a named ETS table owned by this GenServer.

  Tools are stored with their name as the key. Lookups read directly from ETS
  (no GenServer round-trip), so they are O(1) and safe from any process.

  ## Usage

      # Register a single tool
      Canopy.Tools.Registry.register(tool)

      # Register all tools declared on a module with `use Canopy.Tool`
      Canopy.Tools.Registry.register_module(Canopy.Tools.BuiltIn)

      # Look up by name
      {:ok, tool} = Canopy.Tools.Registry.lookup("read_file")

      # List all tools (optionally filtered)
      tools = Canopy.Tools.Registry.list(mcp_exposed: true)

      # Dispatch a tool by name
      {:ok, result} = Canopy.Tools.Registry.dispatch("read_file", %{"path" => "/tmp/x"})
  """

  use GenServer

  alias Canopy.Tools.Tool

  require Logger

  @table :canopy_tools_registry

  # ---------------------------------------------------------------------------
  # Public API (client side — most read from ETS directly)
  # ---------------------------------------------------------------------------

  @doc false
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Registers a single `%Tool{}` struct. Overwrites any existing entry with the same name."
  @spec register(Tool.t()) :: :ok
  def register(%Tool{} = tool) do
    GenServer.call(__MODULE__, {:register, tool})
  end

  @doc """
  Introspects `module.__canopy_tools__/0` and registers all declared tools.

  The module must `use Canopy.Tool`.
  """
  @spec register_module(module()) :: :ok
  def register_module(module) when is_atom(module) do
    tools = module.__canopy_tools__()
    GenServer.call(__MODULE__, {:register_many, tools})
  end

  @doc "Removes a tool by name. Idempotent."
  @spec unregister(String.t()) :: :ok
  def unregister(name) when is_binary(name) do
    GenServer.call(__MODULE__, {:unregister, name})
  end

  @doc "Looks up a tool by name."
  @spec lookup(String.t()) :: {:ok, Tool.t()} | {:error, :not_found}
  def lookup(name) when is_binary(name) do
    case :ets.lookup(@table, name) do
      [{^name, tool}] -> {:ok, tool}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Returns all registered tools.

  Accepts optional filter keywords:
    * `:requires` — keep only tools whose `:requires` list contains ALL given atoms
    * `:mcp_exposed` — filter by boolean flag
    * `:prompt_exposed` — filter by boolean flag
  """
  @spec list(keyword()) :: [Tool.t()]
  def list(opts \\ []) do
    all =
      @table
      |> :ets.tab2list()
      |> Enum.map(fn {_, tool} -> tool end)

    all
    |> filter_requires(opts[:requires])
    |> filter_flag(:mcp_exposed, opts[:mcp_exposed])
    |> filter_flag(:prompt_exposed, opts[:prompt_exposed])
  end

  @doc """
  Dispatches a named tool with the given args map.

  Resolves the tool's `{module, function, extra_args}` handler and calls it
  as `apply(module, function, [args | extra_args])`.

  Returns `{:ok, result}` or `{:error, reason}`.
  """
  @spec dispatch(String.t(), map()) :: {:ok, term()} | {:error, term()}
  def dispatch(name, args) when is_binary(name) and is_map(args) do
    case lookup(name) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, %Tool{handler: {mod, fun, extra}}} ->
        try do
          apply(mod, fun, [args | extra])
        rescue
          e ->
            Logger.error("Tool #{name} raised: #{Exception.message(e)}")
            {:error, {:handler_raised, Exception.message(e)}}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :public, read_concurrency: true])
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, %Tool{} = tool}, _, state) do
    :ets.insert(@table, {tool.name, tool})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:register_many, tools}, _, state) do
    Enum.each(tools, fn tool -> :ets.insert(@table, {tool.name, tool}) end)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:unregister, name}, _, state) do
    :ets.delete(@table, name)
    {:reply, :ok, state}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp filter_requires(tools, nil), do: tools

  defp filter_requires(tools, required_caps) when is_list(required_caps) do
    Enum.filter(tools, fn tool ->
      Enum.all?(required_caps, &(&1 in tool.requires))
    end)
  end

  defp filter_flag(tools, _, nil), do: tools

  defp filter_flag(tools, field, value) do
    Enum.filter(tools, fn tool -> Map.get(tool, field) == value end)
  end
end
