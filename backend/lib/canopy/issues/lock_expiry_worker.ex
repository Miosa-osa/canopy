defmodule Canopy.Issues.LockExpiryWorker do
  @moduledoc """
  Oban worker that sweeps stale issue checkout locks every minute.

  Runs a single UPDATE that nullifies checked_out_by_agent / checked_out_at /
  checkout_expires_at on any row whose checkout_expires_at is in the past.

  Scheduled via Oban.Plugins.Cron in config/config.exs.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  alias Canopy.Issues

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    count = Issues.expire_stale_locks()
    {:ok, %{expired: count}}
  end
end
