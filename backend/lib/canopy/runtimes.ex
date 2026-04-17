defmodule Canopy.Runtimes do
  @moduledoc """
  Public API for the Canopy runtime adapter system.

  Two concerns live here:
  1. The in-process adapter registry (`RegistryServer`) — which adapter modules
     are compiled and registered for this session.
  2. The persisted runtime records (`Runtime`) — what the detection layer has
     discovered on the user's machine.

  Callers should use this module exclusively. Do not call `RegistryServer` or
  `Repo` directly from outside the `Canopy.Runtimes` namespace.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Repo
  alias Canopy.Runtimes.{RegistryServer, Runtime}

  # ---------------------------------------------------------------------------
  # Adapter registry (in-memory, process-based)
  # ---------------------------------------------------------------------------

  @doc "Returns all registered adapter modules."
  @spec list_adapters() :: [module()]
  def list_adapters, do: RegistryServer.list()

  @doc "Looks up a registered adapter by its type string."
  @spec lookup_adapter(String.t()) :: {:ok, module()} | {:error, :not_found}
  def lookup_adapter(type), do: RegistryServer.lookup(type)

  @doc "Registers an adapter module. The module must implement `Canopy.Runtimes.Adapter`."
  @spec register_adapter(module()) :: {:ok, pid()} | {:error, {:already_registered, pid()}}
  def register_adapter(adapter_module), do: RegistryServer.register(adapter_module)

  # ---------------------------------------------------------------------------
  # Persisted runtime records
  # ---------------------------------------------------------------------------

  @doc "Returns all persisted runtime records, ordered by name."
  @spec list() :: {:ok, [Runtime.t()]}
  def list do
    runtimes = Repo.all(from(r in Runtime, order_by: [asc: r.name]))
    {:ok, runtimes}
  end

  @doc "Returns the runtime by id, raising if not found."
  @spec get!(binary()) :: Runtime.t()
  def get!(id), do: Repo.get!(Runtime, id)

  @doc "Returns a runtime by its unique type string."
  @spec get_by_type(String.t()) :: {:ok, Runtime.t()} | {:error, :not_found}
  def get_by_type(type) do
    case Repo.get_by(Runtime, type: type) do
      nil -> {:error, :not_found}
      runtime -> {:ok, runtime}
    end
  end

  @doc """
  Inserts or updates a runtime based on detection results from the Rust sidecar.

  Uses the `type` field as the conflict key. On conflict, updates all
  detection-derived fields while preserving user-configured `enabled` and `config`.
  """
  @spec upsert_from_detection(map()) :: {:ok, Runtime.t()} | {:error, Ecto.Changeset.t()}
  def upsert_from_detection(attrs) do
    changeset = Runtime.changeset(%Runtime{}, attrs)

    Repo.insert(changeset,
      on_conflict: {
        :replace,
        [:installed, :version, :binary_path, :capabilities, :last_detected_at, :updated_at]
      },
      conflict_target: :type,
      returning: true
    )
  end
end
