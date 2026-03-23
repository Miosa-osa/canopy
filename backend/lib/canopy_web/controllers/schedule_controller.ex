defmodule CanopyWeb.ScheduleController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{Schedule, Agent, Session}
  import Ecto.Query

  def index(conn, params) do
    workspace_id = params["workspace_id"]

    query =
      from s in Schedule,
        join: a in Agent,
        on: s.agent_id == a.id,
        order_by: [asc: s.name],
        select: %{
          id: s.id,
          name: s.name,
          cron_expression: s.cron_expression,
          cron: s.cron_expression,
          human_readable: s.cron_expression,
          context: s.context,
          enabled: s.enabled,
          timezone: s.timezone,
          agent_id: s.agent_id,
          agent_name: a.name,
          last_run_at: s.last_run_at,
          next_run_at: s.next_run_at,
          last_run_status: s.last_run_status,
          created_at: s.inserted_at,
          inserted_at: s.inserted_at,
          updated_at: s.updated_at
        }

    query =
      if workspace_id,
        do: where(query, [s], s.workspace_id == ^workspace_id),
        else: query

    schedules = Repo.all(query)

    # Fetch session counts for all returned schedules in a single aggregate query.
    schedule_ids = Enum.map(schedules, & &1.id)

    run_counts =
      Repo.all(
        from sess in Session,
          where: sess.schedule_id in ^schedule_ids,
          group_by: sess.schedule_id,
          select: {sess.schedule_id, count(sess.id)}
      )
      |> Map.new()

    schedules =
      Enum.map(schedules, fn s ->
        next_run = s.next_run_at || compute_next_run_at(s.cron_expression)

        s
        |> Map.put(:run_count, Map.get(run_counts, s.id, 0))
        |> Map.put(:next_run_at, next_run)
      end)

    json(conn, %{schedules: schedules})
  end

  def create(conn, params) do
    changeset = Schedule.changeset(%Schedule{}, params)

    case Repo.insert(changeset) do
      {:ok, schedule} ->
        schedule = schedule |> persist_next_run_at() |> Repo.preload(:agent)
        if schedule.enabled, do: Canopy.Scheduler.add_schedule(schedule)
        conn |> put_status(201) |> json(%{schedule: serialize(schedule, 0)})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_failed", details: format_errors(changeset)})
    end
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(Schedule, id) |> maybe_preload_agent() do
      nil -> conn |> put_status(404) |> json(%{error: "not_found"})
      schedule -> json(conn, %{schedule: serialize(schedule, run_count_for(schedule.id))})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Repo.get(Schedule, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      schedule ->
        changeset = Schedule.changeset(schedule, params)

        case Repo.update(changeset) do
          {:ok, updated} ->
            updated = updated |> persist_next_run_at() |> Repo.preload(:agent)
            Canopy.Scheduler.remove_schedule(updated.id)
            if updated.enabled, do: Canopy.Scheduler.add_schedule(updated)
            json(conn, %{schedule: serialize(updated, run_count_for(updated.id))})

          {:error, changeset} ->
            conn
            |> put_status(422)
            |> json(%{error: "validation_failed", details: format_errors(changeset)})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repo.get(Schedule, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      schedule ->
        Canopy.Scheduler.remove_schedule(schedule.id)
        Repo.delete!(schedule)
        json(conn, %{ok: true})
    end
  end

  def trigger(conn, %{"schedule_id" => id}) do
    case Repo.get(Schedule, id) |> Repo.preload(:agent) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      schedule ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        next_run = compute_next_run_at(schedule.cron_expression)

        case schedule
             |> Ecto.Changeset.change(last_run_at: now, last_run_status: "triggered", next_run_at: next_run)
             |> Repo.update() do
          {:ok, updated} ->
            Canopy.EventBus.broadcast(
              Canopy.EventBus.agent_topic(schedule.agent_id),
              %{event: "agent.heartbeat_started", schedule_id: id, agent_id: schedule.agent_id}
            )

            Task.Supervisor.start_child(Canopy.HeartbeatRunner, fn ->
              Canopy.Heartbeat.run(schedule.agent_id,
                schedule_id: schedule.id,
                context: schedule.context || "Scheduled heartbeat: #{schedule.name}"
              )
            end)

            json(conn, %{schedule: serialize(updated, run_count_for(updated.id)), triggered: true})

          {:error, _changeset} ->
            conn |> put_status(500) |> json(%{error: "update_failed"})
        end
    end
  end

  def queue(conn, _params) do
    pending =
      Repo.all(
        from s in Schedule,
          where: s.enabled == true,
          order_by: [asc: s.next_run_at],
          limit: 50,
          select: %{
            id: s.id,
            name: s.name,
            agent_id: s.agent_id,
            next_run_at: s.next_run_at,
            cron_expression: s.cron_expression
          }
      )

    json(conn, %{queue: pending})
  end

  def wake_all(conn, _params) do
    {count, _} =
      Repo.update_all(from(s in Schedule, where: s.enabled == false), set: [enabled: true])

    json(conn, %{ok: true, enabled_count: count})
  end

  def pause_all(conn, _params) do
    {count, _} =
      Repo.update_all(from(s in Schedule, where: s.enabled == true), set: [enabled: false])

    json(conn, %{ok: true, paused_count: count})
  end

  defp serialize(%Schedule{} = s, run_count) do
    agent_name =
      if Ecto.assoc_loaded?(s.agent) && s.agent, do: s.agent.name, else: nil

    next_run = s.next_run_at || compute_next_run_at(s.cron_expression)

    %{
      id: s.id,
      name: s.name,
      cron_expression: s.cron_expression,
      cron: s.cron_expression,
      human_readable: s.cron_expression,
      context: s.context,
      enabled: s.enabled,
      timezone: s.timezone,
      workspace_id: s.workspace_id,
      agent_id: s.agent_id,
      agent_name: agent_name,
      last_run_at: s.last_run_at,
      next_run_at: next_run,
      last_run_status: s.last_run_status,
      run_count: run_count,
      created_at: s.inserted_at,
      inserted_at: s.inserted_at,
      updated_at: s.updated_at
    }
  end

  defp maybe_preload_agent(nil), do: nil
  defp maybe_preload_agent(%Schedule{} = s), do: Repo.preload(s, :agent)

  defp run_count_for(schedule_id) do
    Repo.aggregate(
      from(sess in Session, where: sess.schedule_id == ^schedule_id),
      :count
    )
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  # Computes the next DateTime after `now` for the given cron expression.
  # Returns nil when the expression cannot be parsed (non-fatal — field stays nil).
  defp compute_next_run_at(cron_expression) when is_binary(cron_expression) do
    case Crontab.CronExpression.Parser.parse(cron_expression) do
      {:ok, cron} ->
        cron
        |> Crontab.Scheduler.get_next_run_date!(DateTime.utc_now() |> DateTime.to_naive())
        |> DateTime.from_naive!("Etc/UTC")
        |> DateTime.truncate(:second)

      {:error, _reason} ->
        nil
    end
  end

  defp compute_next_run_at(_), do: nil

  # Persists next_run_at on an already-inserted schedule.  Silently skips on
  # parse failure so a bad cron expression does not block schedule creation.
  defp persist_next_run_at(%Schedule{} = schedule) do
    case compute_next_run_at(schedule.cron_expression) do
      nil ->
        schedule

      next_run ->
        case schedule |> Ecto.Changeset.change(next_run_at: next_run) |> Repo.update() do
          {:ok, updated} -> updated
          {:error, _} -> schedule
        end
    end
  end
end
