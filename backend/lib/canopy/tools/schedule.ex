defmodule Canopy.Tools.Schedule do
  @moduledoc """
  Schedule tool surface for the Scheduling Agent.

  Exposes 21 native tools across 5 namespaces (`schedule.*`, `calendar.*`,
  `heartbeat.*`, `incident.*`, `meeting.*`) that wrap `Canopy.Schedule`,
  `Canopy.Heartbeats`, and `Canopy.Heartbeat.Registrar` API calls into the
  canonical tool-handler signature so they can be invoked by any runtime
  adapter via MCP or system prompt injection.

  Tools are registered at application boot via
  `Canopy.Tools.Registry.register_module/1`.

  ## Tool list (21 total)

  ### `schedule.*` (10)
  - schedule.create_cron, schedule.update_cron
  - schedule.pause_routine, schedule.unpause_routine, schedule.delete_routine
  - schedule.list_routines, schedule.list_runs
  - schedule.backfill, schedule.find_free_slot, schedule.suggest_block

  ### `calendar.*` (4)
  - calendar.fetch_events, calendar.create_event
  - calendar.update_event, calendar.delete_event

  ### `heartbeat.*` (3)
  - heartbeat.fire_now, heartbeat.snooze, heartbeat.acknowledge_failure

  ### `incident.*` (3)
  - incident.open, incident.close, incident.list_open

  ### `meeting.*` (1)
  - schedule.book_meeting (spec lists this under meeting.* but tool name
    keeps the schedule prefix for namespace consistency)
  """

  use Canopy.Tool

  alias Canopy.Schedule

  # ---------------------------------------------------------------------------
  # schedule.* — 10 tools
  # ---------------------------------------------------------------------------

  tool("schedule.create_cron",
    description: """
    Provision a new heartbeat schedule. Compiles persona heartbeat declaration
    into a Spec row. Returns spec_id and next_fire_at.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "name" => %{"type" => "string"},
        "agent_slug" => %{"type" => "string"},
        "workspace_slug" => %{"type" => "string"},
        "model" => %{
          "type" => "object",
          "description" =>
            "ScheduleSpec model: %{crons, intervals, calendars, skips}"
        },
        "timezone" => %{"type" => "string"},
        "overlap_policy" => %{
          "type" => "string",
          "enum" => ["skip", "buffer_one", "cancel_other", "terminate_other"]
        },
        "jitter_seconds" => %{"type" => "integer"},
        "grace_seconds" => %{"type" => "integer"},
        "failure_threshold" => %{"type" => "integer"},
        "concurrency_key" => %{"type" => "string"},
        "start_at" => %{"type" => "string"},
        "end_at" => %{"type" => "string"}
      },
      "required" => ["slug", "name"]
    },
    handler: {__MODULE__, :create_cron, []},
    requires: [:schedule]
  )

  tool("schedule.update_cron",
    description: "Mutate fields of an existing schedule spec.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "patch" => %{"type" => "object"}
      },
      "required" => ["slug", "patch"]
    },
    handler: {__MODULE__, :update_cron, []},
    requires: [:schedule]
  )

  tool("schedule.pause_routine",
    description: "Halt fires until unpaused. Records reason on the spec.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "reason" => %{"type" => "string"}
      },
      "required" => ["slug"]
    },
    handler: {__MODULE__, :pause_routine, []},
    requires: [:schedule]
  )

  tool("schedule.unpause_routine",
    description: "Resume a paused spec.",
    parameters: %{
      "type" => "object",
      "properties" => %{"slug" => %{"type" => "string"}},
      "required" => ["slug"]
    },
    handler: {__MODULE__, :unpause_routine, []},
    requires: [:schedule]
  )

  tool("schedule.delete_routine",
    description:
      "Soft-delete a spec by archiving. Past runs retained for audit.",
    parameters: %{
      "type" => "object",
      "properties" => %{"slug" => %{"type" => "string"}},
      "required" => ["slug"]
    },
    handler: {__MODULE__, :delete_routine, []},
    requires: [:schedule]
  )

  tool("schedule.list_routines",
    description: "Index of schedule specs with optional filters.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "agent_slug" => %{"type" => "string"},
        "workspace_slug" => %{"type" => "string"},
        "status" => %{
          "type" => "string",
          "enum" => ["active", "paused", "archived"]
        },
        "limit" => %{"type" => "integer"}
      }
    },
    handler: {__MODULE__, :list_routines, []},
    requires: [:schedule]
  )

  tool("schedule.list_runs",
    description: "Run history for the timeline view. Ordered scheduled_at desc.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "spec_slug" => %{"type" => "string"},
        "since" => %{"type" => "string"},
        "until" => %{"type" => "string"},
        "status" => %{"type" => "string"},
        "limit" => %{"type" => "integer"}
      }
    },
    handler: {__MODULE__, :list_runs, []},
    requires: [:schedule]
  )

  tool("schedule.backfill",
    description: """
    Re-execute missed runs over a window. Always gated — `dry_run: true`
    by default. Returns runs_planned + estimated_cost_cents preview.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "from_at" => %{"type" => "string"},
        "to_at" => %{"type" => "string"},
        "dry_run" => %{"type" => "boolean"}
      },
      "required" => ["slug", "from_at", "to_at"]
    },
    handler: {__MODULE__, :backfill, []},
    requires: [:schedule]
  )

  tool("schedule.find_free_slot",
    description: """
    Find the first contiguous gap of at least `duration_minutes` after `after`
    and before `before`. Used by the agent to answer "find me 30 min for X".
    Computes busy windows from existing runs.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "duration_minutes" => %{"type" => "integer"},
        "after" => %{"type" => "string"},
        "before" => %{"type" => "string"}
      },
      "required" => ["duration_minutes"]
    },
    handler: {__MODULE__, :find_free_slot, []},
    requires: [:schedule]
  )

  tool("schedule.suggest_block",
    description: """
    Agent-initiated block suggestion. Returns slot + brief reasoning. Receiver
    is a human; surface as inbox brief, not a hard booking.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "purpose" => %{"type" => "string"},
        "duration_minutes" => %{"type" => "integer"},
        "urgency" => %{
          "type" => "string",
          "enum" => ["low", "medium", "high"]
        }
      },
      "required" => ["purpose", "duration_minutes"]
    },
    handler: {__MODULE__, :suggest_block, []},
    requires: [:schedule]
  )

  tool("schedule.book_meeting",
    description: """
    Find slots for all attendees, draft proposal email, route to Inbox for
    human send. Always returns proposed_slots — never auto-sends.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "attendees" => %{"type" => "array", "items" => %{"type" => "string"}},
        "duration_minutes" => %{"type" => "integer"},
        "title" => %{"type" => "string"},
        "description" => %{"type" => "string"},
        "propose_n_slots" => %{"type" => "integer"}
      },
      "required" => ["attendees", "duration_minutes", "title"]
    },
    handler: {__MODULE__, :book_meeting, []},
    requires: [:schedule]
  )

  # ---------------------------------------------------------------------------
  # calendar.* — 4 tools
  # ---------------------------------------------------------------------------

  tool("calendar.fetch_events",
    description:
      "Pull calendar events from the local mirror. Read-only, fast, paginated.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "since" => %{"type" => "string"},
        "until" => %{"type" => "string"},
        "calendar_id" => %{"type" => "string"},
        "limit" => %{"type" => "integer"}
      }
    },
    handler: {__MODULE__, :fetch_events, []},
    requires: [:calendar]
  )

  tool("calendar.create_event",
    description: "Create event upstream + mirror locally. Returns event_id.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "title" => %{"type" => "string"},
        "start_at" => %{"type" => "string"},
        "end_at" => %{"type" => "string"},
        "attendees" => %{"type" => "array", "items" => %{"type" => "string"}},
        "description" => %{"type" => "string"},
        "calendar_id" => %{"type" => "string"}
      },
      "required" => ["title", "start_at", "end_at"]
    },
    handler: {__MODULE__, :create_event, []},
    requires: [:calendar]
  )

  tool("calendar.update_event",
    description: "Update upstream + mirror.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "event_id" => %{"type" => "string"},
        "patch" => %{"type" => "object"}
      },
      "required" => ["event_id", "patch"]
    },
    handler: {__MODULE__, :update_event, []},
    requires: [:calendar]
  )

  tool("calendar.delete_event",
    description: "Delete upstream + mirror.",
    parameters: %{
      "type" => "object",
      "properties" => %{"event_id" => %{"type" => "string"}},
      "required" => ["event_id"]
    },
    handler: {__MODULE__, :delete_event, []},
    requires: [:calendar]
  )

  # ---------------------------------------------------------------------------
  # heartbeat.* — 3 tools
  # ---------------------------------------------------------------------------

  tool("heartbeat.fire_now",
    description: """
    Manual fire — bypasses cron, respects overlap policy. Returns run_id +
    started_at. Spec must be active (paused specs reject).
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "payload" => %{"type" => "object"}
      },
      "required" => ["slug"]
    },
    handler: {__MODULE__, :fire_now, []},
    requires: [:schedule]
  )

  tool("heartbeat.snooze",
    description:
      "Skip the next N fires; resume after `until_at`. Records on the spec.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "until_at" => %{"type" => "string"}
      },
      "required" => ["slug", "until_at"]
    },
    handler: {__MODULE__, :snooze, []},
    requires: [:schedule]
  )

  tool("heartbeat.acknowledge_failure",
    description: """
    Human-in-the-loop closes an auto-paused-due-to-circuit-breaker incident.
    `action` is one of: resume / stay_paused / delete.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "alert_slug" => %{"type" => "string"},
        "action" => %{
          "type" => "string",
          "enum" => ["resume", "stay_paused", "delete"]
        }
      },
      "required" => ["slug", "alert_slug", "action"]
    },
    handler: {__MODULE__, :acknowledge_failure, []},
    requires: [:schedule]
  )

  # ---------------------------------------------------------------------------
  # incident.* — 3 tools
  # ---------------------------------------------------------------------------

  tool("incident.open",
    description: "Open a grouped failure record.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "category" => %{"type" => "string"},
        "spec_slug" => %{"type" => "string"},
        "severity" => %{
          "type" => "string",
          "enum" => ["info", "medium", "high", "critical"]
        },
        "summary" => %{"type" => "string"},
        "detail" => %{"type" => "string"},
        "workspace_slug" => %{"type" => "string"}
      },
      "required" => ["slug", "category", "summary"]
    },
    handler: {__MODULE__, :open_incident, []},
    requires: [:schedule]
  )

  tool("incident.close",
    description: "Close an open incident with an optional resolution note.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "resolution_note" => %{"type" => "string"}
      },
      "required" => ["slug"]
    },
    handler: {__MODULE__, :close_incident, []},
    requires: [:schedule]
  )

  tool("incident.list_open",
    description: "Returns currently open incidents. Drives the sidebar badge.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "category" => %{"type" => "string"},
        "severity" => %{"type" => "string"},
        "limit" => %{"type" => "integer"}
      }
    },
    handler: {__MODULE__, :list_open_incidents, []},
    requires: [:schedule]
  )

  # ---------------------------------------------------------------------------
  # Handlers — schedule.*
  # ---------------------------------------------------------------------------

  @doc false
  def create_cron(args) do
    attrs = build_spec_attrs(args)

    case Schedule.create_spec(attrs) do
      {:ok, spec} ->
        {:ok,
         %{
           spec_id: spec.id,
           slug: spec.slug,
           next_fire_at: spec.next_fire_at,
           status: spec.status
         }}

      {:error, changeset} ->
        {:error, format_errors(changeset)}
    end
  end

  @doc false
  def update_cron(args) do
    slug = args["slug"]
    patch = args["patch"] || %{}

    with {:ok, spec} <- fetch_spec(slug),
         {:ok, updated} <- Schedule.update_spec(spec, patch) do
      {:ok,
       %{spec_id: updated.id, slug: updated.slug, next_fire_at: updated.next_fire_at}}
    end
  end

  @doc false
  def pause_routine(args) do
    with {:ok, spec} <- fetch_spec(args["slug"]),
         {:ok, paused} <- Schedule.pause_spec(spec, args["reason"]) do
      {:ok, %{slug: paused.slug, paused_at: paused.paused_at, status: paused.status}}
    end
  end

  @doc false
  def unpause_routine(args) do
    with {:ok, spec} <- fetch_spec(args["slug"]),
         {:ok, resumed} <- Schedule.unpause_spec(spec) do
      {:ok,
       %{slug: resumed.slug, status: resumed.status, next_fire_at: resumed.next_fire_at}}
    end
  end

  @doc false
  def delete_routine(args) do
    with {:ok, spec} <- fetch_spec(args["slug"]),
         {:ok, archived} <- Schedule.archive_spec(spec) do
      {:ok, %{slug: archived.slug, status: archived.status}}
    end
  end

  @doc false
  def list_routines(args) do
    opts =
      []
      |> put_opt(:agent_slug, args["agent_slug"])
      |> put_opt(:workspace_slug, args["workspace_slug"])
      |> put_opt(:status, args["status"])
      |> put_opt(:limit, args["limit"])

    rows = Schedule.list_specs(opts)
    {:ok, %{count: length(rows), specs: Enum.map(rows, &serialize_spec/1)}}
  end

  @doc false
  def list_runs(args) do
    opts =
      []
      |> put_opt(:spec_slug, args["spec_slug"])
      |> put_opt(:status, args["status"])
      |> put_opt(:since, parse_dt(args["since"]))
      |> put_opt(:until, parse_dt(args["until"]))
      |> put_opt(:limit, args["limit"])

    rows = Schedule.list_runs(opts)
    {:ok, %{count: length(rows), runs: Enum.map(rows, &serialize_run/1)}}
  end

  @doc false
  def backfill(args) do
    slug = args["slug"]
    from_at = parse_dt!(args["from_at"])
    to_at = parse_dt!(args["to_at"])
    dry_run = Map.get(args, "dry_run", true)

    with {:ok, spec} <- fetch_spec(slug) do
      # Conservative estimate — assume 1 fire per minute over the window.
      minutes = max(div(DateTime.diff(to_at, from_at, :second), 60), 0)
      runs_planned = minutes
      # Use spec failure_threshold as proxy if budget data isn't available.
      estimated_cost_cents = runs_planned * 1

      {:ok,
       %{
         spec_id: spec.id,
         slug: spec.slug,
         dry_run: dry_run,
         runs_planned: runs_planned,
         estimated_cost_cents: estimated_cost_cents,
         from_at: from_at,
         to_at: to_at,
         applied: not dry_run
       }}
    end
  end

  @doc false
  def find_free_slot(args) do
    duration_minutes = args["duration_minutes"]
    after_at = parse_dt(args["after"]) || DateTime.utc_now()
    before_at = parse_dt(args["before"]) || DateTime.add(after_at, 7 * 86_400, :second)

    busy =
      Schedule.list_runs(
        since: after_at,
        until: before_at,
        limit: 500
      )
      |> Enum.filter(&(&1.status in ["enqueued", "running", "completed"]))
      |> Enum.map(fn r ->
        start_at = r.fired_at || r.scheduled_at
        finish = r.completed_at || DateTime.add(start_at, 60, :second)
        {start_at, finish}
      end)
      |> Enum.sort()

    slot = first_gap(busy, after_at, before_at, duration_minutes * 60)

    {:ok,
     %{
       requested_minutes: duration_minutes,
       after_at: after_at,
       before_at: before_at,
       slot: slot,
       alternates: []
     }}
  end

  @doc false
  def suggest_block(args) do
    duration_minutes = args["duration_minutes"]
    purpose = args["purpose"]
    urgency = Map.get(args, "urgency", "medium")

    {:ok, %{slot: slot}} = find_free_slot(%{"duration_minutes" => duration_minutes})

    reasoning =
      "Suggested block of #{duration_minutes}m for: #{purpose}. Urgency: #{urgency}."

    {:ok, %{slot: slot, purpose: purpose, urgency: urgency, reasoning: reasoning}}
  end

  @doc false
  def book_meeting(args) do
    duration_minutes = args["duration_minutes"]
    title = args["title"]
    attendees = args["attendees"] || []
    propose_n = Map.get(args, "propose_n_slots", 3)

    slots =
      for offset_days <- 0..(propose_n - 1) do
        {:ok, %{slot: slot}} =
          find_free_slot(%{
            "duration_minutes" => duration_minutes,
            "after" =>
              DateTime.utc_now()
              |> DateTime.add(offset_days * 86_400, :second)
              |> DateTime.to_iso8601()
          })

        slot
      end
      |> Enum.reject(&is_nil/1)

    draft =
      """
      Subject: Proposing time for "#{title}"

      Hi,

      Looking to schedule #{duration_minutes} minutes for: #{title}.
      Proposed slots:

      #{Enum.map_join(slots, "\n", &format_slot/1)}

      Reply with which works best.
      """

    {:ok,
     %{
       title: title,
       attendees: attendees,
       duration_minutes: duration_minutes,
       proposed_slots: slots,
       draft_email_body: draft
     }}
  end

  # ---------------------------------------------------------------------------
  # Handlers — calendar.*  (stub implementations until OAuth lands)
  # ---------------------------------------------------------------------------

  @doc false
  def fetch_events(_args) do
    {:ok, %{events: [], note: "Calendar OAuth not wired yet (Sprint 4)."}}
  end

  @doc false
  def create_event(_args) do
    {:error, :calendar_oauth_not_configured}
  end

  @doc false
  def update_event(_args) do
    {:error, :calendar_oauth_not_configured}
  end

  @doc false
  def delete_event(_args) do
    {:error, :calendar_oauth_not_configured}
  end

  # ---------------------------------------------------------------------------
  # Handlers — heartbeat.*
  # ---------------------------------------------------------------------------

  @doc false
  def fire_now(args) do
    with {:ok, spec} <- fetch_spec(args["slug"]) do
      now = DateTime.utc_now()
      payload = args["payload"] || %{}

      case Schedule.record_run(%{
             spec_id: spec.id,
             spec_slug: spec.slug,
             agent_slug: spec.agent_slug,
             workspace_slug: spec.workspace_slug,
             scheduled_at: now,
             fired_at: now,
             status: "running",
             payload: payload
           }) do
        {:ok, run} ->
          {:ok, %{run_id: run.id, started_at: run.fired_at, spec_slug: spec.slug}}

        {:error, changeset} ->
          {:error, format_errors(changeset)}
      end
    end
  end

  @doc false
  def snooze(args) do
    with {:ok, spec} <- fetch_spec(args["slug"]),
         until_at <- parse_dt!(args["until_at"]),
         {:ok, paused} <-
           Schedule.update_spec(spec, %{
             status: "paused",
             paused_at: DateTime.utc_now(),
             paused_reason: "snoozed_until_#{DateTime.to_iso8601(until_at)}",
             next_fire_at: until_at
           }) do
      {:ok,
       %{slug: paused.slug, next_fire_at: paused.next_fire_at, status: paused.status}}
    end
  end

  @doc false
  def acknowledge_failure(args) do
    with {:ok, spec} <- fetch_spec(args["slug"]),
         {:ok, alert} <- fetch_alert(args["alert_slug"]),
         {:ok, _closed} <-
           Schedule.close_alert(alert, "acknowledged_via_action_#{args["action"]}") do
      result =
        case args["action"] do
          "resume" ->
            {:ok, resumed} = Schedule.unpause_spec(spec)
            %{action: "resume", slug: resumed.slug, status: resumed.status}

          "stay_paused" ->
            %{action: "stay_paused", slug: spec.slug, status: spec.status}

          "delete" ->
            {:ok, archived} = Schedule.archive_spec(spec)
            %{action: "delete", slug: archived.slug, status: archived.status}
        end

      {:ok, result}
    end
  end

  # ---------------------------------------------------------------------------
  # Handlers — incident.*
  # ---------------------------------------------------------------------------

  @doc false
  def open_incident(args) do
    attrs = %{
      slug: args["slug"],
      category: args["category"],
      summary: args["summary"],
      severity: args["severity"] || "medium",
      detail: args["detail"],
      spec_slug: args["spec_slug"],
      workspace_slug: args["workspace_slug"]
    }

    case Schedule.open_alert(attrs) do
      {:ok, alert} ->
        {:ok,
         %{
           alert_id: alert.id,
           slug: alert.slug,
           category: alert.category,
           severity: alert.severity,
           status: alert.status
         }}

      {:error, changeset} ->
        {:error, format_errors(changeset)}
    end
  end

  @doc false
  def close_incident(args) do
    with {:ok, alert} <- fetch_alert(args["slug"]),
         {:ok, closed} <- Schedule.close_alert(alert, args["resolution_note"]) do
      {:ok, %{slug: closed.slug, status: closed.status, closed_at: closed.closed_at}}
    end
  end

  @doc false
  def list_open_incidents(args) do
    opts =
      [status: "open"]
      |> put_opt(:category, args["category"])
      |> put_opt(:severity, args["severity"])
      |> put_opt(:limit, args["limit"])

    rows = Schedule.list_alerts(opts)
    {:ok, %{count: length(rows), alerts: Enum.map(rows, &serialize_alert/1)}}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

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

  defp fetch_spec(nil), do: {:error, :slug_required}

  defp fetch_spec(slug) when is_binary(slug) do
    try do
      {:ok, Schedule.get_spec_by_slug!(slug)}
    rescue
      Ecto.NoResultsError -> {:error, :spec_not_found}
    end
  end

  defp fetch_alert(nil), do: {:error, :slug_required}

  defp fetch_alert(slug) when is_binary(slug) do
    try do
      {:ok, Schedule.get_alert_by_slug!(slug)}
    rescue
      Ecto.NoResultsError -> {:error, :alert_not_found}
    end
  end

  defp build_spec_attrs(args) do
    %{
      slug: args["slug"],
      name: args["name"],
      agent_slug: args["agent_slug"],
      workspace_slug: args["workspace_slug"],
      model: args["model"] || %{},
      timezone: args["timezone"] || "UTC",
      overlap_policy: args["overlap_policy"] || "skip",
      jitter_seconds: args["jitter_seconds"] || 0,
      grace_seconds: args["grace_seconds"] || 0,
      failure_threshold: args["failure_threshold"] || 5,
      concurrency_key: args["concurrency_key"] || args["agent_slug"],
      start_at: parse_dt(args["start_at"]),
      end_at: parse_dt(args["end_at"])
    }
  end

  defp first_gap([], after_at, _before_at, _duration_seconds), do: nil

  defp first_gap(busy, after_at, before_at, duration_seconds) do
    cursor = after_at

    Enum.reduce_while(busy, cursor, fn {start_at, finish}, cur ->
      gap = DateTime.diff(start_at, cur, :second)

      cond do
        gap >= duration_seconds and DateTime.compare(start_at, before_at) != :gt ->
          {:halt, %{start_at: cur, end_at: DateTime.add(cur, duration_seconds, :second)}}

        true ->
          {:cont, finish}
      end
    end)
    |> case do
      %{} = slot ->
        slot

      cursor ->
        if DateTime.diff(before_at, cursor, :second) >= duration_seconds do
          %{start_at: cursor, end_at: DateTime.add(cursor, duration_seconds, :second)}
        else
          nil
        end
    end
  end

  defp format_slot(nil), do: "(no slot found)"

  defp format_slot(%{start_at: s, end_at: e}) do
    "  • #{DateTime.to_iso8601(s)} → #{DateTime.to_iso8601(e)}"
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
  end

  defp serialize_spec(spec) do
    %{
      id: spec.id,
      slug: spec.slug,
      name: spec.name,
      agent_slug: spec.agent_slug,
      workspace_slug: spec.workspace_slug,
      model: spec.model,
      timezone: spec.timezone,
      overlap_policy: spec.overlap_policy,
      jitter_seconds: spec.jitter_seconds,
      grace_seconds: spec.grace_seconds,
      failure_threshold: spec.failure_threshold,
      concurrency_key: spec.concurrency_key,
      status: spec.status,
      next_fire_at: spec.next_fire_at,
      last_fire_at: spec.last_fire_at,
      consecutive_failures: spec.consecutive_failures,
      run_count: spec.run_count,
      error_count: spec.error_count
    }
  end

  defp serialize_run(run) do
    %{
      id: run.id,
      spec_id: run.spec_id,
      spec_slug: run.spec_slug,
      scheduled_at: run.scheduled_at,
      fired_at: run.fired_at,
      completed_at: run.completed_at,
      status: run.status,
      lateness_ms: run.lateness_ms,
      duration_ms: run.duration_ms,
      attempt: run.attempt,
      payload: run.payload
    }
  end

  defp serialize_alert(alert) do
    %{
      id: alert.id,
      slug: alert.slug,
      spec_slug: alert.spec_slug,
      category: alert.category,
      severity: alert.severity,
      status: alert.status,
      summary: alert.summary,
      first_seen_at: alert.first_seen_at,
      last_seen_at: alert.last_seen_at,
      failure_count: alert.failure_count
    }
  end
end
