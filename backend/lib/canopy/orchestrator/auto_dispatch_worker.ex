defmodule Canopy.Orchestrator.AutoDispatchWorker do
  @moduledoc """
  Oban worker that drives the orchestrator sweep every minute.

  Registered in `config/config.exs` via:

      {"* * * * *", Canopy.Orchestrator.AutoDispatchWorker}

  Each tick:
  1. Marks stalled claims (claimed > 10 min, no session) back to Backlog.
  2. Unblocks milestones in active missions whose deps are now complete.
  3. Dispatches unclaimed tasks to idle agents by skill match.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  alias Canopy.Orchestrator

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    result = Orchestrator.auto_dispatch()

    Logger.info(
      "[AutoDispatchWorker] complete stalled=#{result.stalled} dispatched=#{result.dispatched}"
    )

    {:ok, result}
  end
end
