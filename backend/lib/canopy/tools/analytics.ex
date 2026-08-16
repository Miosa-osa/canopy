defmodule Canopy.Tools.Analytics do
  @moduledoc """
  Analytics tool surface for the Iris agent.

  Exposes 6 native tools (`analytics.*`) that wrap `Canopy.Analytics` API
  calls into the canonical tool-handler signature so they can be invoked by
  any runtime adapter (Claude / Codex / Gemini / etc.) via MCP or system
  prompt injection.

  Tools are registered at application boot via
  `Canopy.Tools.register_all_builtins/0` (which also picks up modules listed
  in `:canopy, :tool_modules` config).

  ## Tool list

  - `analytics.query_telemetry` — query telemetry events
  - `analytics.aggregate_costs` — bucketed cost breakdown
  - `analytics.compare_periods` — A/B period delta
  - `analytics.list_agents_by_metric` — leaderboard for a metric
  - `analytics.investigate_breadcrumbs` — breadcrumbs for a run
  - `analytics.summarize_session` — terse session report
  """

  use Canopy.Tool

  alias Canopy.Analytics

  # ---------------------------------------------------------------------------
  # Tool declarations
  # ---------------------------------------------------------------------------

  tool("analytics.query_telemetry",
    description: """
    Query telemetry events with optional filters. Returns a list of events
    sorted by timestamp descending.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "event" => %{"type" => "string", "description" => "Exact event name"},
        "agent_id" => %{"type" => "string"},
        "session_id" => %{"type" => "string"},
        "run_id" => %{"type" => "string"},
        "workspace_slug" => %{"type" => "string"},
        "runtime" => %{"type" => "string"},
        "from" => %{
          "type" => "string",
          "description" => "ISO-8601 lower bound on timestamp"
        },
        "to" => %{
          "type" => "string",
          "description" => "ISO-8601 upper bound on timestamp"
        },
        "limit" => %{"type" => "integer"}
      }
    },
    handler: {__MODULE__, :query_telemetry, []},
    requires: [:analytics]
  )

  tool("analytics.aggregate_costs",
    description: """
    Aggregate cost telemetry into time buckets. Returns
    `[%{bucket, cost_cents, count}, ...]` for the given window.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "granularity" => %{
          "type" => "string",
          "enum" => ["hour", "day", "week", "month"],
          "description" => "Bucket size (default day)"
        },
        "from" => %{"type" => "string"},
        "to" => %{"type" => "string"},
        "agent_id" => %{"type" => "string"},
        "workspace_slug" => %{"type" => "string"},
        "runtime" => %{"type" => "string"}
      }
    },
    handler: {__MODULE__, :aggregate_costs, []},
    requires: [:analytics]
  )

  tool("analytics.compare_periods",
    description: """
    Compare a metric across two consecutive windows of equal length.
    Returns `%{current, previous, delta_pct, delta_abs}`.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "metric" => %{
          "type" => "string",
          "enum" => ["cost_cents", "duration_ms", "event_count"],
          "description" => "Which value to compare"
        },
        "from" => %{"type" => "string"},
        "to" => %{"type" => "string"},
        "agent_id" => %{"type" => "string"},
        "workspace_slug" => %{"type" => "string"}
      },
      "required" => ["metric", "from", "to"]
    },
    handler: {__MODULE__, :compare_periods, []},
    requires: [:analytics]
  )

  tool("analytics.list_agents_by_metric",
    description: """
    Returns the top N agents ranked by a given metric over a window.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "metric" => %{
          "type" => "string",
          "enum" => ["cost_cents", "duration_ms", "run_count", "error_rate"]
        },
        "from" => %{"type" => "string"},
        "to" => %{"type" => "string"},
        "limit" => %{"type" => "integer", "description" => "default 10"},
        "workspace_slug" => %{"type" => "string"}
      },
      "required" => ["metric"]
    },
    handler: {__MODULE__, :list_agents_by_metric, []},
    requires: [:analytics]
  )

  tool("analytics.investigate_breadcrumbs",
    description: """
    Returns breadcrumbs for a single run, ordered by sequence. Used for
    forensic investigation of an anomaly or failure.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "run_id" => %{"type" => "string"},
        "level" => %{
          "type" => "string",
          "enum" => ["debug", "info", "warning", "error", "fatal"]
        },
        "type" => %{"type" => "string"},
        "limit" => %{"type" => "integer"}
      },
      "required" => ["run_id"]
    },
    handler: {__MODULE__, :investigate_breadcrumbs, []},
    requires: [:analytics]
  )

  tool("analytics.summarize_session",
    description: """
    Returns a terse summary of a session — duration, total cost, message
    counts by kind, and any error breadcrumbs. Used by Iris to answer
    "what happened in session X?" without dumping the full transcript.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "session_id" => %{"type" => "string"}
      },
      "required" => ["session_id"]
    },
    handler: {__MODULE__, :summarize_session, []},
    requires: [:analytics]
  )

  # ---------------------------------------------------------------------------
  # Handlers
  # ---------------------------------------------------------------------------

  @doc false
  def query_telemetry(args) do
    opts = build_query_opts(args)
    events = Analytics.query_telemetry(opts)

    {:ok, %{count: length(events), events: Enum.map(events, &serialize_event/1)}}
  end

  @doc false
  def aggregate_costs(args) do
    opts =
      []
      |> put_opt(:granularity, parse_granularity(args["granularity"]))
      |> put_opt(:from, parse_dt(args["from"]))
      |> put_opt(:to, parse_dt(args["to"]))
      |> put_opt(:agent_id, args["agent_id"])
      |> put_opt(:workspace_slug, args["workspace_slug"])
      |> put_opt(:runtime, args["runtime"])

    rows = Analytics.aggregate_costs(opts)
    {:ok, %{rows: Enum.map(rows, &serialize_bucket/1)}}
  end

  @doc false
  def compare_periods(args) do
    metric = args["metric"]
    from = parse_dt!(args["from"])
    to = parse_dt!(args["to"])
    span = DateTime.diff(to, from, :microsecond)
    prev_from = DateTime.add(from, -span, :microsecond)
    prev_to = from

    base_opts = [
      agent_id: args["agent_id"],
      workspace_slug: args["workspace_slug"]
    ]

    current = sum_metric(metric, [{:from, from}, {:to, to} | base_opts])
    previous = sum_metric(metric, [{:from, prev_from}, {:to, prev_to} | base_opts])
    delta = current - previous

    delta_pct =
      if previous == 0, do: nil, else: Float.round(delta / previous * 100, 2)

    {:ok,
     %{
       metric: metric,
       current: current,
       previous: previous,
       delta_abs: delta,
       delta_pct: delta_pct,
       window: %{
         current: %{from: from, to: to},
         previous: %{from: prev_from, to: prev_to}
       }
     }}
  end

  @doc false
  def list_agents_by_metric(args) do
    limit = args["limit"] || 10

    base_opts = [
      from: parse_dt(args["from"]),
      to: parse_dt(args["to"]),
      workspace_slug: args["workspace_slug"]
    ]

    events =
      base_opts
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Analytics.query_telemetry()

    grouped =
      events
      |> Enum.reject(&is_nil(&1.agent_id))
      |> Enum.group_by(& &1.agent_id)

    rows =
      grouped
      |> Enum.map(fn {agent_id, agent_events} ->
        %{
          agent_id: agent_id,
          run_count: length(agent_events),
          cost_cents: agent_events |> Enum.map(&(&1.cost_cents || 0)) |> Enum.sum(),
          duration_ms: agent_events |> Enum.map(&(&1.duration_ms || 0)) |> Enum.sum(),
          error_count:
            agent_events
            |> Enum.filter(&(&1.status == "error"))
            |> Enum.count()
        }
      end)
      |> Enum.sort_by(&Map.get(&1, String.to_atom(args["metric"]), 0), :desc)
      |> Enum.take(limit)

    {:ok, %{rows: rows}}
  end

  @doc false
  def investigate_breadcrumbs(args) do
    run_id = args["run_id"]

    opts =
      []
      |> put_opt(:limit, args["limit"])
      |> put_opt(:level, args["level"])
      |> put_opt(:type, args["type"])

    crumbs = Analytics.list_breadcrumbs(run_id, opts)

    {:ok,
     %{
       run_id: run_id,
       count: length(crumbs),
       breadcrumbs: Enum.map(crumbs, &serialize_breadcrumb/1)
     }}
  end

  @doc false
  def summarize_session(args) do
    session_id = args["session_id"]

    events = Analytics.query_telemetry(session_id: session_id, limit: 1000)

    cost = events |> Enum.map(&(&1.cost_cents || 0)) |> Enum.sum()
    duration = events |> Enum.map(&(&1.duration_ms || 0)) |> Enum.sum()

    by_kind =
      events
      |> Enum.group_by(& &1.event)
      |> Enum.map(fn {kind, evts} -> {kind, length(evts)} end)
      |> Enum.into(%{})

    error_events =
      events
      |> Enum.filter(&(&1.status == "error"))
      |> Enum.map(&serialize_event/1)

    {:ok,
     %{
       session_id: session_id,
       event_count: length(events),
       cost_cents: cost,
       duration_ms: duration,
       events_by_kind: by_kind,
       errors: error_events
     }}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp build_query_opts(args) do
    []
    |> put_opt(:event, args["event"])
    |> put_opt(:agent_id, args["agent_id"])
    |> put_opt(:session_id, args["session_id"])
    |> put_opt(:run_id, args["run_id"])
    |> put_opt(:workspace_slug, args["workspace_slug"])
    |> put_opt(:runtime, args["runtime"])
    |> put_opt(:from, parse_dt(args["from"]))
    |> put_opt(:to, parse_dt(args["to"]))
    |> put_opt(:limit, args["limit"])
  end

  defp put_opt(opts, _key, nil), do: opts
  defp put_opt(opts, key, value), do: [{key, value} | opts]

  defp parse_dt(nil), do: nil

  defp parse_dt(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_dt!(str) do
    parse_dt(str) || raise(ArgumentError, "invalid timestamp: #{inspect(str)}")
  end

  defp parse_granularity(nil), do: :day
  defp parse_granularity("hour"), do: :hour
  defp parse_granularity("day"), do: :day
  defp parse_granularity("week"), do: :week
  defp parse_granularity("month"), do: :month
  defp parse_granularity(_), do: :day

  defp sum_metric(metric, opts) do
    events = Analytics.query_telemetry(opts)

    case metric do
      "cost_cents" -> events |> Enum.map(&(&1.cost_cents || 0)) |> Enum.sum()
      "duration_ms" -> events |> Enum.map(&(&1.duration_ms || 0)) |> Enum.sum()
      "event_count" -> length(events)
      _ -> 0
    end
  end

  defp serialize_event(event) do
    %{
      id: event.id,
      ts: event.ts,
      event: event.event,
      run_id: event.run_id,
      session_id: event.session_id,
      agent_id: event.agent_id,
      workspace_slug: event.workspace_slug,
      runtime: event.runtime,
      model: event.model,
      duration_ms: event.duration_ms,
      cost_cents: event.cost_cents,
      status: event.status,
      payload: event.payload
    }
  end

  defp serialize_breadcrumb(b) do
    %{
      id: b.id,
      run_id: b.run_id,
      session_id: b.session_id,
      sequence: b.sequence,
      ts: b.ts,
      type: b.type,
      category: b.category,
      level: b.level,
      message: b.message,
      data: b.data
    }
  end

  defp serialize_bucket(row) do
    %{
      bucket: row.bucket,
      cost_cents: row.cost_cents || 0,
      count: row.count
    }
  end
end
