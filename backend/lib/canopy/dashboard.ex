defmodule Canopy.Dashboard do
  @moduledoc """
  Command Center context — 3 aggregation functions for the dashboard.

  No DB table. No layout persistence. No widget registry.
  Queries Sessions, Budgets, and Governance directly.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Budgets
  alias Canopy.Budgets.Budget
  alias Canopy.Governance.Approval
  alias Canopy.Repo
  alias Canopy.Sessions.Session

  require Logger

  # ---------------------------------------------------------------------------
  # Public API — 3 functions
  # ---------------------------------------------------------------------------

  @doc """
  Returns consolidated dashboard data: active_agents, spend_this_month, recent_sessions.

  All queries run sequentially. Returns a plain map.
  """
  @spec summary() :: map()
  def summary do
    %{
      active_agents: active_agents(),
      spend_this_month: spend_this_month(),
      recent_sessions: recent_sessions(10)
    }
  end

  @doc """
  Returns agents with currently running sessions (status="running"). Cap: 50.
  """
  @spec active_agents() :: [map()]
  def active_agents do
    from(s in Session,
      where: s.status == "running",
      order_by: [desc: s.started_at],
      limit: 50,
      select: %{
        agent_slug: s.agent_slug,
        current_session_id: s.id,
        started_at: s.started_at
      }
    )
    |> Repo.all()
  end

  @doc """
  Total spend in USD for the current calendar month, grouped by agent_slug.

  Returns `%{total_usd: string, by_agent: [%{agent_slug, cost_usd}]}`.
  """
  @spec spend_this_month() :: map()
  def spend_this_month do
    {start, finish} = Budgets.period_window("monthly")

    base =
      from(s in Session,
        where:
          s.status == "completed" and
            s.completed_at >= ^start and
            s.completed_at < ^finish
      )

    total =
      from(s in base, select: coalesce(sum(s.cost_usd), ^Decimal.new(0)))
      |> Repo.one!()

    by_agent =
      from(s in base,
        where: not is_nil(s.agent_slug),
        group_by: s.agent_slug,
        order_by: [desc: sum(s.cost_usd)],
        select: %{agent_slug: s.agent_slug, cost_usd: coalesce(sum(s.cost_usd), ^Decimal.new(0))}
      )
      |> Repo.all()
      |> Enum.map(fn row -> %{row | cost_usd: Decimal.to_string(row.cost_usd)} end)

    %{total_usd: Decimal.to_string(total), by_agent: by_agent}
  end

  @doc """
  Returns the N most recent sessions with minimal fields. Default N: 10, max: 50.
  """
  @spec recent_sessions(pos_integer()) :: [map()]
  def recent_sessions(n \\ 10) do
    limit = min(n, 50)

    from(s in Session,
      order_by: [desc: s.inserted_at],
      limit: ^limit,
      select: %{
        id: s.id,
        agent_slug: s.agent_slug,
        status: s.status,
        runtime_type: s.runtime_type,
        started_at: s.started_at,
        completed_at: s.completed_at,
        cost_usd: s.cost_usd,
        inserted_at: s.inserted_at
      }
    )
    |> Repo.all()
    |> Enum.map(fn row ->
      %{row | cost_usd: if(row.cost_usd, do: Decimal.to_string(row.cost_usd), else: nil)}
    end)
  end

  # ---------------------------------------------------------------------------
  # Internal helpers used by the summary (kept for pending_approvals widget)
  # ---------------------------------------------------------------------------

  @doc "Pending governance approvals count + list."
  @spec pending_approvals() :: map()
  def pending_approvals do
    approvals = Canopy.Governance.pending_approvals()

    items =
      Enum.map(approvals, fn %Approval{} = a ->
        %{id: a.id, session_id: a.session_id, requested_at: a.requested_at}
      end)

    %{count: length(items), items: items}
  end

  # ---------------------------------------------------------------------------
  # Budget helpers (used by Widgets.budget_burn — kept for session counts)
  # ---------------------------------------------------------------------------

  @doc false
  def budget_burn do
    {:ok, all_budgets} = Budgets.list(enabled: true)

    items =
      Enum.map(all_budgets, fn %Budget{} = b ->
        {:ok, spent} = Budgets.current_spend(b.scope_type, b.scope_id, b.period)
        percent = compute_percent(spent, b.limit_usd)

        %{
          id: b.id,
          scope_type: b.scope_type,
          limit_usd: Decimal.to_string(b.limit_usd),
          spent_usd: Decimal.to_string(spent),
          percent: percent
        }
      end)

    %{budgets: items}
  end

  defp compute_percent(spent, limit) do
    if Decimal.eq?(limit, Decimal.new(0)) do
      0.0
    else
      limit
      |> then(&Decimal.div(spent, &1))
      |> Decimal.mult(100)
      |> Decimal.to_float()
      |> Float.round(1)
    end
  end
end
