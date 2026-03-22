defmodule CanopyWeb.DashboardController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{Agent, Session, ActivityEvent, Issue, BudgetPolicy}
  import Ecto.Query

  def show(conn, params) do
    workspace_id = params["workspace_id"]
    user_workspace_ids = conn.assigns[:user_workspace_ids] || []

    agents_query = from a in Agent, select: %{status: a.status, id: a.id}

    agents_query =
      cond do
        workspace_id -> where(agents_query, [a], a.workspace_id == ^workspace_id)
        user_workspace_ids != [] -> where(agents_query, [a], a.workspace_id in ^user_workspace_ids)
        true -> agents_query
      end

    agents = Repo.all(agents_query)
    active_count = Enum.count(agents, &(&1.status in ["active", "working"]))
    total_count = length(agents)

    live_runs_query =
      from s in Session,
        where: s.status == "active",
        join: a in Agent,
        on: s.agent_id == a.id,
        select: %{
          id: s.id,
          agent_id: a.id,
          agent_name: a.name,
          model: s.model,
          started_at: s.started_at,
          tokens_input: s.tokens_input,
          tokens_output: s.tokens_output,
          cost_cents: s.cost_cents
        },
        limit: 20,
        order_by: [desc: s.started_at]

    live_runs_query =
      cond do
        workspace_id -> where(live_runs_query, [s, a], a.workspace_id == ^workspace_id)
        user_workspace_ids != [] -> where(live_runs_query, [s, a], a.workspace_id in ^user_workspace_ids)
        true -> live_runs_query
      end

    live_runs = Repo.all(live_runs_query)

    recent_activity_query =
      from e in ActivityEvent,
        left_join: a in Agent,
        on: e.agent_id == a.id,
        order_by: [desc: e.inserted_at],
        limit: 20,
        select: %{
          id: e.id,
          type: e.event_type,
          agent_id: e.agent_id,
          agent_name: a.name,
          title: e.message,
          detail: e.message,
          level: e.level,
          metadata: e.metadata,
          created_at: e.inserted_at
        }

    recent_activity_query =
      cond do
        workspace_id -> where(recent_activity_query, [e], e.workspace_id == ^workspace_id)
        user_workspace_ids != [] -> where(recent_activity_query, [e], e.workspace_id in ^user_workspace_ids)
        true -> recent_activity_query
      end

    recent_activity = Repo.all(recent_activity_query)

    today = Date.utc_today()
    beginning_of_day = DateTime.new!(today, ~T[00:00:00], "Etc/UTC")

    beginning_of_week =
      DateTime.new!(Date.add(today, -Date.day_of_week(today) + 1), ~T[00:00:00], "Etc/UTC")

    beginning_of_month =
      DateTime.new!(Date.new!(today.year, today.month, 1), ~T[00:00:00], "Etc/UTC")

    # CostEvent has no workspace_id — join through Agent to scope costs
    cost_base_query =
      cond do
        workspace_id ->
          from ce in Canopy.Schemas.CostEvent,
            join: a in Agent,
            on: ce.agent_id == a.id,
            where: a.workspace_id == ^workspace_id

        user_workspace_ids != [] ->
          from ce in Canopy.Schemas.CostEvent,
            join: a in Agent,
            on: ce.agent_id == a.id,
            where: a.workspace_id in ^user_workspace_ids

        true ->
          from ce in Canopy.Schemas.CostEvent
      end

    today_cost =
      Repo.one(
        from ce in cost_base_query,
          where: ce.inserted_at >= ^beginning_of_day,
          select: coalesce(sum(ce.cost_cents), 0)
      ) || 0

    week_cost =
      Repo.one(
        from ce in cost_base_query,
          where: ce.inserted_at >= ^beginning_of_week,
          select: coalesce(sum(ce.cost_cents), 0)
      ) || 0

    month_cost =
      Repo.one(
        from ce in cost_base_query,
          where: ce.inserted_at >= ^beginning_of_month,
          select: coalesce(sum(ce.cost_cents), 0)
      ) || 0

    open_issues_query =
      from i in Issue, where: i.status in ["backlog", "in_progress"]

    open_issues_query =
      cond do
        workspace_id -> where(open_issues_query, [i], i.workspace_id == ^workspace_id)
        user_workspace_ids != [] -> where(open_issues_query, [i], i.workspace_id in ^user_workspace_ids)
        true -> open_issues_query
      end

    open_issues = Repo.aggregate(open_issues_query, :count)

    # BudgetPolicy uses scope_type/scope_id — match workspace_id via scope_id when present
    workspace_policy_query =
      from bp in BudgetPolicy,
        where: bp.scope_type == "workspace",
        limit: 1

    workspace_policy_query =
      cond do
        workspace_id -> where(workspace_policy_query, [bp], bp.scope_id == ^workspace_id)
        user_workspace_ids != [] -> where(workspace_policy_query, [bp], bp.scope_id in ^user_workspace_ids)
        true -> workspace_policy_query
      end

    workspace_policy = Repo.one(workspace_policy_query)

    {monthly_limit_cents, budget_remaining_pct} =
      case workspace_policy do
        nil ->
          {0, 100}

        %BudgetPolicy{monthly_limit_cents: limit} when limit > 0 ->
          used_pct = Float.round(month_cost / limit * 100, 1)
          remaining_pct = max(100.0 - used_pct, 0.0)
          {limit, remaining_pct}

        _ ->
          {0, 100}
      end

    memory_info = :erlang.memory()
    memory_mb = div(memory_info[:total], 1_048_576)

    json(conn, %{
      kpis: %{
        active_agents: active_count,
        total_agents: total_count,
        live_runs: length(live_runs),
        open_issues: open_issues,
        budget_remaining_pct: budget_remaining_pct
      },
      live_runs: live_runs,
      recent_activity: recent_activity,
      finance_summary: %{
        today_cents: today_cost,
        week_cents: week_cost,
        month_cents: month_cost,
        # daily_limit_cents: BudgetPolicy has no daily_limit_cents column yet
        daily_limit_cents: 0,
        monthly_limit_cents: monthly_limit_cents,
        # cache_savings_pct: no cache token tracking in CostEvent yet
        cache_savings_pct: 0
      },
      system_health: %{
        backend: "ok",
        primary_gateway: "anthropic",
        gateway_status: "ok",
        memory_mb: memory_mb,
        # cpu_pct: no system metrics collection yet
        cpu_pct: 0
      }
    })
  end
end
