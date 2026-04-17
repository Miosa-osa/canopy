defmodule Canopy.Runtimes.RegistryServer do
  @moduledoc """
  Thin wrapper around the Elixir Registry started in `Canopy.Application`.

  The underlying `Registry` process (name: `Canopy.Runtimes.Registry`) provides
  unique-key registration and lookup for runtime adapter modules. This module
  exposes a clean public API and will grow to support hot-swap pause/resume in
  Week 1 (Paperclip mutable dual-registry pattern).

  Registration stores the adapter module under its `type/0` string as the key.
  Lookup returns the adapter module so callers can invoke adapter callbacks directly.

  Week 1 additions (not yet implemented):
  - Builtin fallback storage for hot-swap override support
  - `pause_override/1` and `resume_override/1` for the adapter override lifecycle
  - ETS-backed secondary index for capability-based lookup
  """

  @registry Canopy.Runtimes.Registry

  @doc "Registers an adapter module under its own type string."
  @spec register(module()) :: {:ok, pid()} | {:error, {:already_registered, pid()}}
  def register(adapter_module) do
    type = adapter_module.type()
    Registry.register(@registry, type, adapter_module)
  end

  @doc "Looks up a registered adapter by its type string."
  @spec lookup(String.t()) :: {:ok, module()} | {:error, :not_found}
  def lookup(type) do
    case Registry.lookup(@registry, type) do
      [{_pid, adapter_module}] -> {:ok, adapter_module}
      [] -> {:error, :not_found}
    end
  end

  @doc "Returns a list of all registered adapter modules."
  @spec list() :: [module()]
  def list do
    Registry.select(@registry, [{{:"$1", :"$2", :"$3"}, [], [:"$3"]}])
  end
end
