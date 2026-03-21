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
        Map.put(s, :run_count, Map.get(run_counts, s.id, 0))
      end)

    json(conn, %{schedules: schedules})
  end

  def create(conn, params) do
    changeset = Schedule.changeset(%Schedule{}, params)

    case Repo.insert(changeset) do
      {:ok, schedule} ->
        conn |> put_status(201) |> json(%{schedule: serialize(schedule, 0)})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_failed", details: format_errors(changeset)})
    end
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(Schedule, id) do
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

        {:ok, updated} =
          schedule
          |> Ecto.Changeset.change(last_run_at: now, last_run_status: "triggered")
          |> Repo.update()

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
      agent_name: nil,
      last_run_at: s.last_run_at,
      next_run_at: s.next_run_at,
      last_run_status: s.last_run_status,
      run_count: run_count,
      created_at: s.inserted_at,
      inserted_at: s.inserted_at,
      updated_at: s.updated_at
    }
  end

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
end
