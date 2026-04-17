defmodule Canopy.Sessions.Supervisor do
  @moduledoc """
  DynamicSupervisor that owns one child process per running session.

  Each session is supervised independently — a crashed session process does
  not affect other running sessions. The supervisor uses `one_for_one` restart
  strategy by default (DynamicSupervisor default).

  Week 1 additions:
  - `start_session/1` — spawn a supervised session process for a given session ID
  - `stop_session/1` — gracefully terminate a session process
  - Integration with `Canopy.Sessions` public API
  """

  use DynamicSupervisor

  @doc "Starts the DynamicSupervisor."
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
