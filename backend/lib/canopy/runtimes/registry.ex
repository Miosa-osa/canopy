defmodule Canopy.Runtimes.RegistryServer do
  @moduledoc """
  In-memory adapter registry for Canopy runtime adapters.

  Backed by a named ETS table owned by this GenServer. Entries persist for
  the lifetime of the GenServer (i.e. the app), unlike Elixir's built-in
  `Registry` which auto-unregisters when the calling process exits.

  On boot, this server auto-registers the known built-in adapters:
    - `Canopy.Runtimes.ClaudeLocal`
    - `Canopy.Runtimes.CodexLocal`
    - `Canopy.Runtimes.GeminiLocal`

  External adapter plugins (Week 2+) register themselves via `register/1` and
  stay registered until explicitly unregistered.

  Lookups read directly from ETS (no GenServer round-trip), so they are
  cheap and safe from any process.
  """

  use GenServer

  @table :canopy_runtimes_registry

  @builtin_adapters [
    Canopy.Runtimes.ClaudeLocal,
    Canopy.Runtimes.CodexLocal,
    Canopy.Runtimes.GeminiLocal
  ]

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc false
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers an adapter module under its `type/0` key.

  `adapter_module.type/0` is invoked in the CALLER's process (not the
  GenServer's) so that test doubles provided via Mox resolve correctly.
  """
  @spec register(module()) :: :ok
  def register(adapter_module) when is_atom(adapter_module) do
    type = adapter_module.type()
    GenServer.call(__MODULE__, {:register, type, adapter_module})
  end

  @doc "Removes an adapter by its type string. Idempotent."
  @spec unregister(String.t()) :: :ok
  def unregister(type) when is_binary(type) do
    GenServer.call(__MODULE__, {:unregister, type})
  end

  @doc "Looks up an adapter module by its type string."
  @spec lookup(String.t()) :: {:ok, module()} | {:error, :not_found}
  def lookup(type) when is_binary(type) do
    case :ets.lookup(@table, type) do
      [{^type, mod}] -> {:ok, mod}
      [] -> {:error, :not_found}
    end
  end

  @doc "Returns a list of all registered adapter modules."
  @spec list() :: [module()]
  def list do
    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_type, mod} -> mod end)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, read_concurrency: true])

    for adapter <- @builtin_adapters do
      if Code.ensure_loaded?(adapter) and function_exported?(adapter, :type, 0) do
        :ets.insert(@table, {adapter.type(), adapter})
      end
    end

    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, type, adapter_module}, _from, state) do
    :ets.insert(@table, {type, adapter_module})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:unregister, type}, _from, state) do
    :ets.delete(@table, type)
    {:reply, :ok, state}
  end
end
