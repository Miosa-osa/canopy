defmodule Canopy.StaleCleanup do
  use GenServer
  require Logger
  alias Canopy.Repo
  alias Canopy.Schemas.{Issue, Session}
  import Ecto.Query

  @cleanup_interval :timer.minutes(5)
  @issue_timeout_minutes 30
  @session_timeout_minutes 30

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    schedule_cleanup()
    {:ok, %{}}
  end

  def handle_info(:cleanup, state) do
    cleanup_stuck_issues()
    cleanup_stale_sessions()
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_stuck_issues do
    cutoff = DateTime.add(DateTime.utc_now(), -@issue_timeout_minutes * 60, :second)

    {count, _} = Repo.update_all(
      from(i in Issue,
        where: i.status == "in_progress" and not is_nil(i.checked_out_by) and i.updated_at < ^cutoff
      ),
      set: [status: "backlog", checked_out_by: nil, updated_at: DateTime.utc_now() |> DateTime.truncate(:second)]
    )

    if count > 0, do: Logger.warning("[StaleCleanup] Reset #{count} stuck issues to backlog")
  end

  defp cleanup_stale_sessions do
    cutoff = DateTime.add(DateTime.utc_now(), -@session_timeout_minutes * 60, :second)

    {count, _} = Repo.update_all(
      from(s in Session,
        where: s.status == "active" and s.started_at < ^cutoff
      ),
      set: [status: "failed", completed_at: DateTime.utc_now() |> DateTime.truncate(:second)]
    )

    if count > 0, do: Logger.warning("[StaleCleanup] Failed #{count} stale active sessions")
  end
end
