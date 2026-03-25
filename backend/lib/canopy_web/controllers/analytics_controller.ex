defmodule CanopyWeb.AnalyticsController do
  use CanopyWeb, :controller

  @agent_names [
    "Athena",
    "Orion",
    "Nova",
    "Cipher",
    "Atlas",
    "Echo",
    "Sage",
    "Lyra",
    "Rex",
    "Iris"
  ]

  @team_names ["Engineering", "Research", "Operations", "Product", "Security"]

  # GET /analytics/summary?period=30d
  def summary(conn, params) do
    period = params["period"] || "30d"
    days = parse_period(period)
    :rand.seed(:exsss, {days, 42, 7})

    total_sessions = rand_int(120, 600)
    total_cost_cents = rand_int(5_000, 80_000)
    avg_success_rate = (85 + :rand.uniform(14)) / 100
    total_tasks = rand_int(200, 1200)
    active_agents = rand_int(3, 10)

    sessions_by_day =
      for i <- 1..days do
        date = Date.add(Date.utc_today(), -(days - i))
        %{date: Date.to_iso8601(date), count: rand_int(1, max(1, div(total_sessions, days) * 2))}
      end

    costs_by_day =
      for i <- 1..days do
        date = Date.add(Date.utc_today(), -(days - i))

        %{
          date: Date.to_iso8601(date),
          cost_cents: rand_int(0, max(1, div(total_cost_cents, days) * 2))
        }
      end

    # Build agent_metrics and team_metrics inline so summary returns the full AnalyticsData shape
    agent_metrics = build_agent_metrics(days)
    team_metrics = build_team_metrics(days)

    json(conn, %{
      period: period,
      totals: %{
        total_sessions: total_sessions,
        total_cost_cents: total_cost_cents,
        avg_success_rate: avg_success_rate,
        total_tasks: total_tasks,
        active_agents: active_agents
      },
      trends: %{
        sessions_by_day: sessions_by_day,
        costs_by_day: costs_by_day
      },
      agent_metrics: agent_metrics,
      team_metrics: team_metrics
    })
  end

  # GET /analytics/agents?period=30d
  def agents(conn, params) do
    days = parse_period(params["period"])
    json(conn, %{agents: build_agent_metrics(days)})
  end

  # GET /analytics/teams?period=30d
  def teams(conn, params) do
    days = parse_period(params["period"])
    json(conn, %{teams: build_team_metrics(days)})
  end

  # --- Private helpers ---

  defp build_agent_metrics(days) do
    :rand.seed(:exsss, {days, 99, 13})
    agent_count = rand_int(3, min(10, length(@agent_names)))

    @agent_names
    |> Enum.with_index()
    |> Enum.take(agent_count)
    |> Enum.map(fn {name, idx} ->
      total_sessions = rand_int(10, 120)
      success_rate = (75 + :rand.uniform(24)) / 100
      successful_sessions = round(total_sessions * success_rate)
      failed_sessions = total_sessions - successful_sessions
      avg_duration_s = rand_int(30, 600)
      total_cost_cents = rand_int(500, 15_000)
      tasks_completed = rand_int(20, 300)

      %{
        agent_id: "agt-#{String.downcase(name)}-#{idx}",
        agent_name: name,
        total_sessions: total_sessions,
        successful_sessions: successful_sessions,
        failed_sessions: failed_sessions,
        success_rate: success_rate,
        avg_duration_seconds: avg_duration_s,
        total_cost_cents: total_cost_cents,
        tasks_completed: tasks_completed,
        tasks_per_day: Float.round(tasks_completed / days, 2)
      }
    end)
    |> Enum.sort_by(& &1.total_sessions, :desc)
  end

  defp build_team_metrics(days) do
    :rand.seed(:exsss, {days, 17, 55})

    @team_names
    |> Enum.with_index()
    |> Enum.map(fn {name, idx} ->
      agent_count = rand_int(1, 5)
      total_sessions = rand_int(20, 200)
      total_cost_cents = rand_int(1_000, 30_000)
      success_rate = (80 + :rand.uniform(19)) / 100

      %{
        team_id: "team-#{String.downcase(name)}-#{idx}",
        team_name: name,
        agent_count: agent_count,
        total_sessions: total_sessions,
        total_cost_cents: total_cost_cents,
        success_rate: success_rate
      }
    end)
    |> Enum.sort_by(& &1.total_sessions, :desc)
  end

  defp parse_period(nil), do: 30

  defp parse_period(period) do
    case Regex.run(~r/^(\d+)d$/, period) do
      [_, n] -> String.to_integer(n)
      _ -> 30
    end
  end

  defp rand_int(min, max) when max > min, do: min + :rand.uniform(max - min)
  defp rand_int(min, _max), do: min
end
