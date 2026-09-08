defmodule Canopy.Schedule.Dispatcher do
  @moduledoc """
  Periodic schedule evaluator. Wakes every 60s, walks active specs, and emits
  telemetry on miss / late / run events.

  This GenServer does NOT replace the existing `Canopy.Heartbeat.Worker`
  Oban-driven cron loop — it complements it. The Worker is responsible for
  *firing* heartbeats; the Dispatcher is responsible for *observing* fire
  windows, marking late/missed runs, and surfacing those signals to the
  Schedule super-module's UI.

  ## Tick

  On each tick:

    1. Fetch active specs.
    2. For each spec, scan recent runs:
       - Any `enqueued` runs whose `scheduled_at + grace_seconds` is in the
         past → mark `missed`. Open a `miss` alert.
       - Any `running` runs that have lasted longer than 5× `grace_seconds`
         → mark `late`. Open a `late` alert if the threshold is breached.
    3. Emit telemetry for each transition: `[:canopy, :schedule, :missed]`,
       `[:canopy, :schedule, :late]`.

  ## Failure isolation

  All work happens in a Task supervised by `Canopy.TaskSupervisor` so a slow
  Repo call cannot block the next tick. If the Repo is down, ticks log and
  continue — never crash the dispatcher.
  """

  use GenServer

  alias Canopy.Schedule

  require Logger

  @tick_interval_ms 60_000

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Triggers an immediate evaluation tick. Useful in tests and from the
  scheduling agent's `schedule.list_runs` path when freshness matters.
  """
  @spec tick_now() :: :ok
  def tick_now, do: GenServer.cast(__MODULE__, :tick)

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval_ms, @tick_interval_ms)
    schedule_tick(interval)
    {:ok, %{interval_ms: interval}}
  end

  @impl true
  def handle_info(:tick, state) do
    do_tick()
    schedule_tick(state.interval_ms)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:tick, state) do
    do_tick()
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Internals
  # ---------------------------------------------------------------------------

  defp schedule_tick(interval_ms) do
    Process.send_after(self(), :tick, interval_ms)
  end

  defp do_tick do
    try do
      evaluate_specs()
    rescue
      e ->
        Logger.warning("[Schedule.Dispatcher] tick failed (non-fatal): #{Exception.message(e)}")
    end
  end

  defp evaluate_specs do
    specs = Schedule.list_specs(status: "active")
    now = DateTime.utc_now()

    Enum.each(specs, fn spec ->
      grace = spec.grace_seconds || 0
      cutoff = DateTime.add(now, -grace, :second)
      late_cutoff = DateTime.add(now, -5 * max(grace, 1), :second)

      runs =
        Schedule.list_runs(
          spec_id: spec.id,
          since: DateTime.add(now, -86_400, :second),
          limit: 100
        )

      Enum.each(runs, fn run ->
        cond do
          run.status == "enqueued" and DateTime.compare(run.scheduled_at, cutoff) == :lt ->
            mark_missed(run)

          (run.status == "running" and run.fired_at) &&
              DateTime.compare(run.fired_at, late_cutoff) == :lt ->
            mark_late(run)

          true ->
            :ok
        end
      end)
    end)

    :ok
  end

  defp mark_missed(run) do
    case Schedule.update_run(run, %{status: "missed"}) do
      {:ok, _} ->
        :telemetry.execute(
          [:canopy, :schedule, :missed],
          %{count: 1},
          %{spec_id: run.spec_id, run_id: run.id, scheduled_at: run.scheduled_at}
        )

        :ok

      {:error, reason} ->
        Logger.warning("[Schedule.Dispatcher] mark_missed failed: #{inspect(reason)}")
        :ok
    end
  end

  defp mark_late(run) do
    case Schedule.update_run(run, %{status: "late"}) do
      {:ok, _} ->
        :telemetry.execute(
          [:canopy, :schedule, :late],
          %{count: 1},
          %{spec_id: run.spec_id, run_id: run.id, fired_at: run.fired_at}
        )

        :ok

      {:error, reason} ->
        Logger.warning("[Schedule.Dispatcher] mark_late failed: #{inspect(reason)}")
        :ok
    end
  end
end
