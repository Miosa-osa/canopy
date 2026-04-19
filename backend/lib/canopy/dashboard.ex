defmodule Canopy.Dashboard do
  @moduledoc """
  Command Center context — full System Observability aggregation functions.

  No DB table. No layout persistence. No widget registry.
  Queries Sessions, SessionMessages, Workspaces, Files, and Governance directly.

  summary/0 fans out all widget queries in parallel via Task.async_stream.
  """

  import Ecto.Query

  alias Canopy.Budgets
  alias Canopy.Budgets.Budget
  alias Canopy.Governance.Approval
  alias Canopy.Repo
  alias Canopy.Sessions.Session
  alias Canopy.Sessions.SessionMessage

  require Logger

  # ---------------------------------------------------------------------------
  # Public API — 11 functions (3 original + 8 new)
  # ---------------------------------------------------------------------------

  @doc """
  Returns consolidated dashboard data for all widgets.

  Widget queries run in parallel via Task.async_stream with a 10-second timeout.
  Any individual widget failure returns its zero/empty shape rather than crashing
  the entire summary — callers receive degraded data, not an error.
  """
  @spec summary() :: map()
  def summary do
    tasks = [
      {:active_agents, fn -> active_agents() end},
      {:spend_this_month, fn -> spend_this_month() end},
      {:recent_sessions, fn -> recent_sessions(10) end},
      {:total_messages, fn -> total_messages() end},
      {:total_sessions, fn -> total_sessions() end},
      {:total_tokens, fn -> total_tokens() end},
      {:success_rate, fn -> success_rate() end},
      {:sandbox_usage_today, fn -> sandbox_usage_today() end},
      {:top_tools_30d, fn -> top_tools_30d() end},
      {:peak_hours_30d, fn -> peak_hours_30d() end},
      {:storage_overview, fn -> storage_overview() end},
      {:top_agents_by_usage, fn -> top_agents_by_usage() end},
      {:token_usage_by_period, fn -> token_usage_by_period() end}
    ]

    tasks
    |> Task.async_stream(
      fn {key, fun} -> {key, fun.()} end,
      timeout: 10_000,
      on_timeout: :kill_task
    )
    |> Enum.reduce(%{}, fn
      {:ok, {key, value}}, acc -> Map.put(acc, key, value)
      {:exit, _reason}, acc -> acc
    end)
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
  # New observability widgets (Wave 2)
  # ---------------------------------------------------------------------------

  @doc """
  Total count of all session messages across all sessions.

  Returns `%{count: integer}`.
  """
  @spec total_messages() :: map()
  def total_messages do
    count =
      from(m in SessionMessage, select: count(m.id))
      |> Repo.one!()

    %{count: count}
  end

  @doc """
  Total count of all sessions regardless of status.

  Returns `%{count: integer}`.
  """
  @spec total_sessions() :: map()
  def total_sessions do
    count =
      from(s in Session, select: count(s.id))
      |> Repo.one!()

    %{count: count}
  end

  @doc """
  Sum of all token fields (input + output + cache_read + cache_write) from
  completed sessions only.

  Returns `%{total: integer, input: integer, output: integer, cache_read: integer, cache_write: integer}`.
  """
  @spec total_tokens() :: map()
  def total_tokens do
    result =
      from(s in Session,
        where: not is_nil(s.completed_at),
        select: %{
          input: coalesce(sum(s.input_tokens), 0),
          output: coalesce(sum(s.output_tokens), 0),
          cache_read: coalesce(sum(s.cache_read_tokens), 0),
          cache_write: coalesce(sum(s.cache_write_tokens), 0)
        }
      )
      |> Repo.one!()

    total = result.input + result.output + result.cache_read + result.cache_write
    Map.put(result, :total, total)
  end

  @doc """
  Session success rate as a percentage over the last 30 days.

  Only counts sessions with status "completed" or "failed" (excludes cancelled,
  pending, running). Returns `%{rate: float, completed: integer, failed: integer}`.
  """
  @spec success_rate() :: map()
  def success_rate do
    cutoff = DateTime.add(DateTime.utc_now(), -30, :day)

    rows =
      from(s in Session,
        where: s.status in ["completed", "failed"] and s.inserted_at >= ^cutoff,
        group_by: s.status,
        select: {s.status, count(s.id)}
      )
      |> Repo.all()
      |> Map.new()

    completed = Map.get(rows, "completed", 0)
    failed = Map.get(rows, "failed", 0)
    total = completed + failed

    rate =
      if total == 0,
        do: 0.0,
        else: Float.round(completed / total * 100.0, 1)

    %{rate: rate, completed: completed, failed: failed}
  end

  @doc """
  Sandbox usage metrics for the current UTC calendar day.

  Returns `%{started: integer, stopped: integer, running_now: integer, avg_lifetime_min: float}`.
  """
  @spec sandbox_usage_today() :: map()
  def sandbox_usage_today do
    now = DateTime.utc_now()
    day_start = %{now | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}

    sandbox_sessions =
      from(s in Session,
        where: not is_nil(s.miosa_sandbox_status) and s.inserted_at >= ^day_start
      )
      |> Repo.all()

    started = length(sandbox_sessions)

    stopped =
      Enum.count(sandbox_sessions, fn s ->
        s.miosa_sandbox_status in ["destroyed", "failed"]
      end)

    running_now =
      Enum.count(sandbox_sessions, fn s ->
        s.miosa_sandbox_status in ["ready", "provisioning"]
      end)

    completed_with_times =
      Enum.filter(sandbox_sessions, fn s ->
        not is_nil(s.started_at) and not is_nil(s.completed_at)
      end)

    avg_lifetime_min =
      if completed_with_times == [] do
        0.0
      else
        total_ms =
          Enum.sum(
            Enum.map(completed_with_times, fn s ->
              DateTime.diff(s.completed_at, s.started_at, :millisecond)
            end)
          )

        Float.round(total_ms / length(completed_with_times) / 60_000, 1)
      end

    %{
      started: started,
      stopped: stopped,
      running_now: running_now,
      avg_lifetime_min: avg_lifetime_min
    }
  end

  @doc """
  Top N tools dispatched via tool_call messages in the last 30 days.

  Groups by `content->>'tool_name'` from session_messages where kind = "tool_call".
  Returns a list of `%{tool_name: string, call_count: integer}` ordered by count desc.
  """
  @spec top_tools_30d(pos_integer()) :: [map()]
  def top_tools_30d(limit \\ 10) do
    cutoff = DateTime.add(DateTime.utc_now(), -30, :day)

    from(m in SessionMessage,
      where: m.kind == "tool_call" and m.inserted_at >= ^cutoff,
      group_by: fragment("content->>'tool_name'"),
      having: not is_nil(fragment("content->>'tool_name'")),
      order_by: [desc: count(m.id)],
      limit: ^limit,
      select: %{
        tool_name: fragment("content->>'tool_name'"),
        call_count: count(m.id)
      }
    )
    |> Repo.all()
  end

  @doc """
  Hour-of-day histogram of sessions started over the last 30 days (UTC hours).

  Returns a list of 24 integers (index = UTC hour 0-23, value = session count).
  """
  @spec peak_hours_30d() :: [integer()]
  def peak_hours_30d do
    cutoff = DateTime.add(DateTime.utc_now(), -30, :day)

    rows =
      from(s in Session,
        where: not is_nil(s.started_at) and s.started_at >= ^cutoff,
        group_by: fragment("EXTRACT(HOUR FROM started_at)::int"),
        select: {fragment("EXTRACT(HOUR FROM started_at)::int"), count(s.id)}
      )
      |> Repo.all()
      |> Map.new()

    Enum.map(0..23, fn hour -> Map.get(rows, hour, 0) end)
  end

  @doc """
  Overview of workspaces and files stored in the system.

  Returns `%{workspaces: integer, files: integer, file_bytes: integer,
             knowledge_bases: 0, kb_chunks: 0, buckets: integer}`.

  `knowledge_bases` and `kb_chunks` are fixed at 0 until feature #105 lands.
  `buckets` is aliased from workspaces count.
  """
  @spec storage_overview() :: map()
  def storage_overview do
    workspace_count =
      from(w in Canopy.Workspaces.Workspace,
        where: is_nil(w.deleted_at),
        select: count(w.id)
      )
      |> Repo.one!()

    file_stats =
      from(f in "files",
        where: is_nil(f.archived_at),
        select: %{
          files: count(f.id),
          file_bytes: coalesce(sum(f.size_bytes), 0)
        }
      )
      |> Repo.one!()

    file_bytes =
      case file_stats.file_bytes do
        %Decimal{} = d -> Decimal.to_integer(d)
        n when is_integer(n) -> n
        _ -> 0
      end

    %{
      workspaces: workspace_count,
      files: file_stats.files,
      file_bytes: file_bytes,
      knowledge_bases: 0,
      kb_chunks: 0,
      buckets: workspace_count
    }
  end

  @doc """
  Top N agents by session count over the last 30 days.

  Returns a list of `%{agent_slug, session_count, total_cost_usd, avg_duration_s}`
  ordered by session_count desc.
  """
  @spec top_agents_by_usage(pos_integer()) :: [map()]
  def top_agents_by_usage(limit \\ 5) do
    cutoff = DateTime.add(DateTime.utc_now(), -30, :day)

    from(s in Session,
      where: not is_nil(s.agent_slug) and s.inserted_at >= ^cutoff,
      group_by: s.agent_slug,
      order_by: [desc: count(s.id)],
      limit: ^limit,
      select: %{
        agent_slug: s.agent_slug,
        session_count: count(s.id),
        total_cost_usd: coalesce(sum(s.cost_usd), ^Decimal.new(0)),
        avg_duration_s:
          fragment("ROUND(AVG(EXTRACT(EPOCH FROM (completed_at - started_at))))::int")
      }
    )
    |> Repo.all()
    |> Enum.map(fn row ->
      %{row | total_cost_usd: Decimal.to_string(row.total_cost_usd)}
    end)
  end

  @doc """
  Token usage breakdown for a given period (:day | :week | :month).

  Sums input/output/cache tokens from sessions completed within the period window.
  Returns `%{input_tokens, output_tokens, cache_read, cache_write, total}`.
  """
  @spec token_usage_by_period(:day | :week | :month) :: map()
  def token_usage_by_period(period \\ :month) do
    cutoff =
      case period do
        :day -> DateTime.add(DateTime.utc_now(), -1, :day)
        :week -> DateTime.add(DateTime.utc_now(), -7, :day)
        :month -> DateTime.add(DateTime.utc_now(), -30, :day)
      end

    result =
      from(s in Session,
        where: not is_nil(s.completed_at) and s.completed_at >= ^cutoff,
        select: %{
          input_tokens: coalesce(sum(s.input_tokens), 0),
          output_tokens: coalesce(sum(s.output_tokens), 0),
          cache_read: coalesce(sum(s.cache_read_tokens), 0),
          cache_write: coalesce(sum(s.cache_write_tokens), 0)
        }
      )
      |> Repo.one!()

    total = result.input_tokens + result.output_tokens + result.cache_read + result.cache_write
    Map.put(result, :total, total)
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
