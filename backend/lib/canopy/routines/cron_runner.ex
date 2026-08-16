defmodule Canopy.Routines.CronRunner do
  @moduledoc """
  Oban worker that sweeps due routines every minute and fires them.

  Registered in `config/config.exs` under `Oban.Plugins.Cron` with the
  expression `"* * * * *"` so it executes at the top of every minute.

  ## Safety guarantees

  - **SKIP LOCKED** — `Routines.claim_for_fire/1` uses `SELECT … FOR UPDATE SKIP LOCKED`
    so two backend nodes never double-fire the same routine.
  - **30-second dedup** — `Routines.list_due/1` excludes routines fired in the last 30s.
  - **Cold-start safety** — routines are only fired if `next_run_at <= now`. A backend
    that was down through 10 scheduled cycles will see `next_run_at` in the past but
    will advance it to the NEXT future slot immediately, so it fires at most once.
  - **in_flight flag** — claimed rows are marked `in_flight: true` until `release_after_fire`
    runs (success or error), preventing concurrent fires within a single node.
  - **Error logging** — failures bump `error_count` and are logged at warning level.
    The routine is NOT retried within the same minute.
  """

  use Oban.Worker, queue: :default, max_attempts: 1

  require Logger

  alias Canopy.Agents.SpawnPipeline
  alias Canopy.Goals
  alias Canopy.Issues
  alias Canopy.Routines
  alias Canopy.Routines.{Cron, Routine}
  alias Canopy.Sessions
  alias Canopy.Tasks

  @impl Oban.Worker
  def perform(_job) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    due = Routines.list_due(now)

    Logger.debug("[CronRunner] tick — #{length(due)} routine(s) due")

    Enum.each(due, fn routine ->
      Task.Supervisor.start_child(
        Canopy.TaskSupervisor,
        fn -> fire_routine(routine, now) end,
        restart: :temporary
      )
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # Fire one routine (runs inside TaskSupervisor child)
  # ---------------------------------------------------------------------------

  defp fire_routine(%Routine{} = routine, now) do
    case Routines.claim_for_fire(routine.id) do
      {:skip, :already_claimed} ->
        Logger.debug("[CronRunner] #{routine.short_id} already claimed, skipping")

      {:ok, claimed} ->
        do_fire(claimed, now)
    end
  end

  defp do_fire(%Routine{} = routine, now) do
    rendered = render_template(routine, now)
    first_line = rendered |> String.split("\n") |> List.first() |> String.slice(0, 255)

    work_attrs = %{
      title: first_line,
      description: rendered,
      workspace_slug: routine.workspace_slug,
      assignee_type: if(routine.target_agent_id, do: "agent"),
      assignee_id: routine.target_agent_id
    }

    result =
      case routine.creates do
        "issue" -> Issues.create(work_attrs)
        "goal" -> Goals.create(work_attrs)
        _task -> Tasks.create(work_attrs)
      end

    case result do
      {:ok, created} ->
        # Spawn agent session if target_agent_id is set and creates is task/issue
        maybe_spawn_agent(routine, created)
        Routines.release_after_fire(routine, now, :ok)

      {:error, reason} = err ->
        Routines.release_after_fire(routine, now, err)

        Logger.warning(
          "[CronRunner] #{routine.short_id} fire error: #{inspect(reason)}"
        )
    end
  end

  # ---------------------------------------------------------------------------
  # Agent session spawn
  # ---------------------------------------------------------------------------

  defp maybe_spawn_agent(%Routine{target_agent_id: nil}, _created), do: :noop

  defp maybe_spawn_agent(%Routine{creates: creates} = routine, created)
       when creates in ["task", "issue"] do
    case Sessions.create(%{
           agent_id: routine.target_agent_id,
           workspace_slug: routine.workspace_slug,
           wake_reason: "schedule",
           source_type: creates,
           source_id: created.id
         }) do
      {:ok, session} ->
        case SpawnPipeline.spawn(session, wake_reason: "schedule") do
          {:ok, _} -> :ok
          {:error, stage, reason} ->
            Logger.warning(
              "[CronRunner] spawn failed for #{routine.short_id} at :#{stage}: #{inspect(reason)}"
            )
        end

      {:error, reason} ->
        Logger.warning(
          "[CronRunner] session create failed for #{routine.short_id}: #{inspect(reason)}"
        )
    end
  end

  defp maybe_spawn_agent(_routine, _created), do: :noop

  # ---------------------------------------------------------------------------
  # Template rendering (duplicated from Routines context to keep worker self-contained)
  # ---------------------------------------------------------------------------

  defp render_template(%Routine{} = routine, now) do
    date = now |> DateTime.to_date() |> Date.to_string()
    now_iso = DateTime.to_iso8601(now)
    last_run = if routine.last_run_at, do: DateTime.to_iso8601(routine.last_run_at), else: "never"

    routine.prompt_template
    |> String.replace("{{date}}", date)
    |> String.replace("{{workspace}}", routine.workspace_slug || "")
    |> String.replace("{{name}}", routine.name)
    |> String.replace("{{now_iso}}", now_iso)
    |> String.replace("{{last_run}}", last_run)
  end

  # ---------------------------------------------------------------------------
  # next_n helper — exposed so the detail page can call it server-side via API
  # ---------------------------------------------------------------------------

  @doc """
  Returns the next `count` scheduled fire times for the given cron expression,
  starting after `from`.
  """
  @spec upcoming(String.t(), DateTime.t(), pos_integer()) :: [DateTime.t()]
  def upcoming(cron, from \\ DateTime.utc_now(), count \\ 5) do
    Cron.next_n(cron, from, count)
  rescue
    _ -> []
  end
end
