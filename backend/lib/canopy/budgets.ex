defmodule Canopy.Budgets do
  @moduledoc """
  Public API for Canopy budget enforcement (ported from canopy-legacy).

  Budget enforcement operates at three tiers:

    1. **Visibility** — spend is always tracked and surfaced via `current_spend/3`.
    2. **Soft alert at `soft_alert_pct`%** — `check/3` returns `{:warn, budget, spent}`.
       The session MAY proceed but the caller should surface a warning.
    3. **Hard ceiling at 100%** — `check/3` returns `{:block, budget, spent}` when
       `hard_ceiling: true`. The session MUST be denied. When `hard_ceiling: false`
       the hard threshold still returns `{:warn, ...}` so no execution is blocked
       without explicit opt-in.

  Spend is computed by summing `cost_usd` on completed sessions scoped to the budget's
  `scope_type` + `scope_id` within the current period window.

  Callers wiring budget checks pre-session-create should use `check/3`. The
  `snapshot_all/0` function is used by the Oban cron worker for historical snapshots.

  ## Period windows

  | Period  | Window anchor                           |
  |---------|-----------------------------------------|
  | daily   | Midnight UTC on the current date        |
  | weekly  | Monday 00:00 UTC of the current ISO week|
  | monthly | First of the current calendar month UTC |
  | total   | Epoch (all time)                        |
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Analytics.Emitter
  alias Canopy.Budgets.{Budget, SpendSnapshot}
  alias Canopy.Repo
  alias Canopy.Sessions.Session

  # ---------------------------------------------------------------------------
  # CRUD
  # ---------------------------------------------------------------------------

  @doc "Returns all budgets. Accepts `scope_type:` and `enabled:` keyword filters."
  @spec list(keyword()) :: {:ok, [Budget.t()]}
  def list(opts \\ []) do
    query =
      from(b in Budget, order_by: [asc: b.scope_type, asc: b.period])
      |> apply_scope_type_filter(Keyword.get(opts, :scope_type))
      |> apply_enabled_filter(Keyword.get(opts, :enabled))

    {:ok, Repo.all(query)}
  end

  @doc "Returns a budget by ID, raising `Ecto.NoResultsError` if not found."
  @spec get!(binary()) :: Budget.t()
  def get!(id), do: Repo.get!(Budget, id)

  @doc "Creates a new budget. Returns `{:ok, budget}` or `{:error, changeset}`."
  @spec create(map()) :: {:ok, Budget.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %Budget{}
    |> Budget.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates mutable fields on an existing budget."
  @spec update(Budget.t(), map()) :: {:ok, Budget.t()} | {:error, Ecto.Changeset.t()}
  def update(%Budget{} = budget, attrs) do
    budget
    |> Budget.update_changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a budget record."
  @spec delete(Budget.t()) :: {:ok, Budget.t()} | {:error, Ecto.Changeset.t()}
  def delete(%Budget{} = budget), do: Repo.delete(budget)

  @doc "Sets `enabled: true` on a budget."
  @spec enable(Budget.t()) :: {:ok, Budget.t()} | {:error, Ecto.Changeset.t()}
  def enable(%Budget{} = budget), do: update(budget, %{enabled: true})

  @doc "Sets `enabled: false` on a budget."
  @spec disable(Budget.t()) :: {:ok, Budget.t()} | {:error, Ecto.Changeset.t()}
  def disable(%Budget{} = budget), do: update(budget, %{enabled: false})

  # ---------------------------------------------------------------------------
  # Spend calculation
  # ---------------------------------------------------------------------------

  @doc """
  Computes the total spend (USD) for the given scope + period window.

  Sums `cost_usd` from sessions in `completed` status, filtered by scope, within
  the current period's time boundaries.

  Returns `{:ok, Decimal.t()}`.
  """
  @spec current_spend(String.t(), binary() | nil, String.t()) :: {:ok, Decimal.t()}
  def current_spend(scope_type, scope_id, period) do
    {period_start, period_end} = period_window(period)

    query =
      from(s in Session,
        where: s.status == "completed",
        where: s.completed_at >= ^period_start,
        where: s.completed_at < ^period_end,
        select: coalesce(sum(s.cost_usd), ^Decimal.new(0))
      )
      |> apply_session_scope(scope_type, scope_id)

    {:ok, Repo.one!(query)}
  end

  # ---------------------------------------------------------------------------
  # Enforcement check
  # ---------------------------------------------------------------------------

  @doc """
  Preflight budget check for a given scope + projected cost.

  Finds all enabled budgets matching the scope and evaluates each. Returns the
  most restrictive result across all matching budgets:

    - `:ok` — within budget for all applicable policies.
    - `{:warn, budget, spent}` — at or above `soft_alert_pct`% of limit on at
      least one policy (agent may proceed but caller should warn).
    - `{:block, budget, spent}` — at or above 100% of limit on a policy where
      `hard_ceiling: true`. Session MUST be denied.

  When `hard_ceiling: false`, a policy that would block instead returns `{:warn, ...}`.

  `projected_cost` is added to the current spend before threshold evaluation.
  Defaults to `Decimal.new(0)` — pass the expected session cost if known upfront.
  """
  @spec check(String.t(), binary() | nil, Decimal.t()) ::
          :ok | {:warn, Budget.t(), Decimal.t()} | {:block, Budget.t(), Decimal.t()}
  def check(scope_type, scope_id, projected_cost \\ Decimal.new(0)) do
    budgets = query_budgets_for_scope(scope_type, scope_id)
    evaluate_budgets(budgets, scope_type, scope_id, projected_cost, :ok)
  end

  @spec query_budgets_for_scope(String.t(), binary() | nil) :: [Budget.t()]
  defp query_budgets_for_scope(scope_type, nil) do
    Repo.all(
      from(b in Budget,
        where: b.enabled == true and b.scope_type == ^scope_type and is_nil(b.scope_id)
      )
    )
  end

  defp query_budgets_for_scope(scope_type, scope_id) do
    Repo.all(
      from(b in Budget,
        where:
          b.enabled == true and b.scope_type == ^scope_type and
            b.scope_id == ^scope_id
      )
    )
  end

  # ---------------------------------------------------------------------------
  # Snapshot
  # ---------------------------------------------------------------------------

  @doc """
  Inserts a `SpendSnapshot` for every enabled budget.

  Called by `Canopy.Budgets.Snapshotter` hourly. Each call appends a new snapshot
  row — existing snapshots are never mutated.
  """
  @spec snapshot_all() :: {:ok, non_neg_integer()}
  def snapshot_all do
    now = DateTime.utc_now()

    budgets = Repo.all(from(b in Budget, where: b.enabled == true))

    inserted =
      Enum.reduce(budgets, 0, fn budget, acc ->
        {period_start, period_end} = period_window(budget.period)
        {:ok, spend} = current_spend(budget.scope_type, budget.scope_id, budget.period)

        session_count =
          Repo.aggregate(
            from(s in Session,
              where:
                s.status == "completed" and
                  s.completed_at >= ^period_start and
                  s.completed_at < ^period_end
            )
            |> apply_session_scope(budget.scope_type, budget.scope_id),
            :count
          )

        attrs = %{
          budget_id: budget.id,
          period_start: period_start,
          period_end: period_end,
          actual_spend_usd: spend,
          session_count: session_count,
          snapshot_at: now,
          inserted_at: now
        }

        case %SpendSnapshot{}
             |> SpendSnapshot.changeset(attrs)
             |> Repo.insert() do
          {:ok, _snapshot} -> acc + 1
          {:error, _changeset} -> acc
        end
      end)

    {:ok, inserted}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec evaluate_budgets([Budget.t()], String.t(), binary() | nil, Decimal.t(), term()) ::
          :ok | {:warn, Budget.t(), Decimal.t()} | {:block, Budget.t(), Decimal.t()}
  defp evaluate_budgets([], _scope_type, _scope_id, _projected, acc), do: acc

  defp evaluate_budgets([budget | rest], scope_type, scope_id, projected, acc) do
    {:ok, current} = current_spend(scope_type, scope_id, budget.period)
    spent = Decimal.add(current, projected)

    result = classify_spend(budget, spent)
    emit_budget_telemetry(result, budget, spent)
    merged = merge_result(acc, result, budget, spent)
    evaluate_budgets(rest, scope_type, scope_id, projected, merged)
  end

  @spec emit_budget_telemetry(:ok | :warn | :block, Budget.t(), Decimal.t()) :: :ok
  defp emit_budget_telemetry(:ok, _budget, _spent), do: :ok

  defp emit_budget_telemetry(:warn, budget, spent) do
    Emitter.budget_warned(%{}, %{
      budget_id: budget.id,
      scope_type: budget.scope_type,
      scope_id: budget.scope_id,
      limit_usd: budget.limit_usd,
      spent: spent
    })

    :ok
  end

  defp emit_budget_telemetry(:block, budget, spent) do
    Emitter.budget_blocked(%{}, %{
      budget_id: budget.id,
      scope_type: budget.scope_type,
      scope_id: budget.scope_id,
      limit_usd: budget.limit_usd,
      spent: spent,
      reason: "hard_ceiling"
    })

    :ok
  end

  @spec classify_spend(Budget.t(), Decimal.t()) :: :ok | :warn | :block
  defp classify_spend(
         %Budget{limit_usd: limit, soft_alert_pct: pct, hard_ceiling: ceiling},
         spent
       ) do
    pct_decimal = Decimal.div(Decimal.new(pct), Decimal.new(100))
    soft_threshold = Decimal.mult(limit, pct_decimal)

    cond do
      Decimal.compare(spent, limit) in [:gt, :eq] and ceiling -> :block
      Decimal.compare(spent, limit) in [:gt, :eq] -> :warn
      Decimal.compare(spent, soft_threshold) in [:gt, :eq] -> :warn
      true -> :ok
    end
  end

  # Merge two results, escalating toward the most restrictive
  @spec merge_result(term(), atom(), Budget.t(), Decimal.t()) ::
          :ok | {:warn, Budget.t(), Decimal.t()} | {:block, Budget.t(), Decimal.t()}
  defp merge_result(_old, :block, budget, spent), do: {:block, budget, spent}
  defp merge_result({:block, _b, _s} = old, _new, _budget, _spent), do: old
  defp merge_result(_old, :warn, budget, spent), do: {:warn, budget, spent}
  defp merge_result({:warn, _b, _s} = old, :ok, _budget, _spent), do: old
  defp merge_result(:ok, :ok, _budget, _spent), do: :ok

  @spec apply_session_scope(Ecto.Query.t(), String.t(), binary() | nil) :: Ecto.Query.t()
  defp apply_session_scope(query, "agent", scope_id) when not is_nil(scope_id) do
    from(s in query, where: s.agent_slug == ^scope_id)
  end

  defp apply_session_scope(query, "workspace", scope_id) when not is_nil(scope_id) do
    from(s in query, where: s.workspace_slug == ^scope_id)
  end

  defp apply_session_scope(query, "runtime", scope_id) when not is_nil(scope_id) do
    from(s in query, where: s.runtime_type == ^scope_id)
  end

  defp apply_session_scope(query, _scope_type, _scope_id), do: query

  @spec apply_scope_type_filter(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  defp apply_scope_type_filter(query, nil), do: query
  defp apply_scope_type_filter(query, val), do: from(b in query, where: b.scope_type == ^val)

  @spec apply_enabled_filter(Ecto.Query.t(), boolean() | nil) :: Ecto.Query.t()
  defp apply_enabled_filter(query, nil), do: query
  defp apply_enabled_filter(query, val), do: from(b in query, where: b.enabled == ^val)

  @doc """
  Returns the `{period_start, period_end}` DateTime tuple for the given period
  relative to the current UTC time.
  """
  @spec period_window(String.t()) :: {DateTime.t(), DateTime.t()}
  def period_window("daily") do
    now = DateTime.utc_now()
    start = %{now | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
    {start, DateTime.add(start, 1, :day)}
  end

  def period_window("weekly") do
    now = Date.utc_today()
    days_since_monday = Date.day_of_week(now) - 1
    monday = Date.add(now, -days_since_monday)
    start = DateTime.new!(monday, ~T[00:00:00], "Etc/UTC")
    {start, DateTime.add(start, 7, :day)}
  end

  def period_window("monthly") do
    now = DateTime.utc_now()
    start = %{now | day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}

    next_month =
      Date.add(
        Date.new!(now.year, now.month, 1),
        Date.days_in_month(Date.new!(now.year, now.month, 1))
      )

    finish = DateTime.new!(next_month, ~T[00:00:00], "Etc/UTC")
    {start, finish}
  end

  def period_window("total") do
    epoch = ~U[1970-01-01 00:00:00Z]
    far_future = ~U[9999-12-31 23:59:59Z]
    {epoch, far_future}
  end
end
