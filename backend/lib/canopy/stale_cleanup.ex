defmodule Canopy.StaleCleanup do
  @moduledoc """
  Periodic GenServer that reclaims stuck issues and fails stale sessions.

  Broadcasts cleanup events via `Canopy.EventBus` so the UI and other
  subscribers can react (e.g. refresh dashboards, send notifications).

  Options (passed via `start_link/1`):
    * `:cleanup_interval` — milliseconds between sweeps (default 5 min)
    * `:issue_timeout_minutes` — minutes before a checked-out issue is reclaimed (default 30)
    * `:session_timeout_minutes` — minutes before an active session is failed (default 30)
    * `:name` — process name (default `__MODULE__`)
  """
  use GenServer
  require Logger
  alias Canopy.Repo
  alias Canopy.Schemas.{Issue, Session}
  import Ecto.Query

  @default_cleanup_interval :timer.minutes(5)
  @default_issue_timeout 30
  @default_session_timeout 30

  # -- Public API --

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Trigger an immediate cleanup sweep (useful in tests)."
  def run_now(server \\ __MODULE__) do
    GenServer.call(server, :run_now)
  end

  # -- Callbacks --

  @impl true
  def init(opts) do
    state = %{
      cleanup_interval: Keyword.get(opts, :cleanup_interval, @default_cleanup_interval),
      issue_timeout_minutes: Keyword.get(opts, :issue_timeout_minutes, @default_issue_timeout),
      session_timeout_minutes: Keyword.get(opts, :session_timeout_minutes, @default_session_timeout),
      last_run: nil,
      total_issues_reclaimed: 0,
      total_sessions_failed: 0
    }

    schedule_cleanup(state.cleanup_interval)
    {:ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    new_state = do_cleanup(state)
    schedule_cleanup(new_state.cleanup_interval)
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:run_now, _from, state) do
    new_state = do_cleanup(state)
    {:reply, {:ok, %{issues: new_state.total_issues_reclaimed, sessions: new_state.total_sessions_failed}}, new_state}
  end

  # -- Internals --

  defp do_cleanup(state) do
    issues_count = cleanup_stuck_issues(state.issue_timeout_minutes)
    sessions_count = cleanup_stale_sessions(state.session_timeout_minutes)

    if issues_count > 0 or sessions_count > 0 do
      Canopy.EventBus.broadcast(
        Canopy.EventBus.activity_topic(),
        {:stale_cleanup, %{issues_reclaimed: issues_count, sessions_failed: sessions_count}}
      )
    end

    %{state |
      last_run: DateTime.utc_now(),
      total_issues_reclaimed: state.total_issues_reclaimed + issues_count,
      total_sessions_failed: state.total_sessions_failed + sessions_count
    }
  end

  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end

  defp cleanup_stuck_issues(timeout_minutes) do
    cutoff = DateTime.add(DateTime.utc_now(), -timeout_minutes * 60, :second)

    {count, _} =
      Repo.update_all(
        from(i in Issue,
          where:
            i.status == "in_progress" and not is_nil(i.checked_out_by) and i.updated_at < ^cutoff
        ),
        set: [
          status: "backlog",
          checked_out_by: nil,
          updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        ]
      )

    if count > 0, do: Logger.warning("[StaleCleanup] Reset #{count} stuck issues to backlog")
    count
  end

  defp cleanup_stale_sessions(timeout_minutes) do
    cutoff = DateTime.add(DateTime.utc_now(), -timeout_minutes * 60, :second)

    {count, _} =
      Repo.update_all(
        from(s in Session,
          where: s.status == "active" and s.started_at < ^cutoff
        ),
        set: [status: "failed", completed_at: DateTime.utc_now() |> DateTime.truncate(:second)]
      )

    if count > 0, do: Logger.warning("[StaleCleanup] Failed #{count} stale active sessions")
    count
  end
end
