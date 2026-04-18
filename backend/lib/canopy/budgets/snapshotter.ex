defmodule Canopy.Budgets.Snapshotter do
  @moduledoc """
  Oban worker that materializes spend snapshots for all enabled budgets.

  Scheduled hourly via the Oban cron plugin. Each execution calls
  `Canopy.Budgets.snapshot_all/0`, which appends one `SpendSnapshot` row per
  enabled budget. Snapshots are append-only — historical records are never mutated.

  ## Cron registration (TODO — add to config/config.exs Oban crontab list):

      {"0 * * * *", Canopy.Budgets.Snapshotter}

  This is intentionally not written directly to avoid merge conflicts with other
  agents also touching the Oban crontab list in the same sprint.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  alias Canopy.Budgets

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("[Budgets.Snapshotter] Running spend snapshot for all enabled budgets")

    {:ok, count} = Budgets.snapshot_all()
    Logger.info("[Budgets.Snapshotter] Inserted #{count} snapshots")
    :ok
  end
end
