defmodule Canopy.Sessions.ScrollbackSupervisor do
  @moduledoc """
  DynamicSupervisor that owns one `ScrollbackStore` per active session.

  Started in the Application supervision tree. `Sessions.create/1` calls
  `start_child/1` after inserting the session row; `Sessions.delete/1` calls
  `stop_child/1` to terminate the store (the log file is kept).
  """

  use DynamicSupervisor

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc "Starts a ScrollbackStore for the given session_id."
  @spec start_child(binary()) :: DynamicSupervisor.on_start_child()
  def start_child(session_id) do
    DynamicSupervisor.start_child(
      __MODULE__,
      Canopy.Sessions.ScrollbackStore.child_spec(session_id)
    )
  end

  @doc "Stops the ScrollbackStore for the given session_id. Log file is kept."
  @spec stop_child(binary()) :: :ok
  def stop_child(session_id) do
    case Registry.lookup(Canopy.Sessions.ScrollbackRegistry, session_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> :ok
    end
  end
end
