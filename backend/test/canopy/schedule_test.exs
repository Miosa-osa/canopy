defmodule Canopy.ScheduleTest do
  @moduledoc """
  Tests for the Canopy.Schedule public API context.

  Covers spec CRUD + lifecycle, run history, overlap detection, alert
  grouping, and aggregation buckets.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Schedule
  alias Canopy.Schedule.Alert
  alias Canopy.Schedule.Run
  alias Canopy.Schedule.Spec

  # ---------------------------------------------------------------------------
  # Specs — CRUD + lifecycle
  # ---------------------------------------------------------------------------

  describe "create_spec/1" do
    test "inserts a valid spec with defaults" do
      assert {:ok, %Spec{} = spec} =
               Schedule.create_spec(%{
                 slug: "daily-digest",
                 name: "Daily digest",
                 model: %{"crons" => ["0 9 * * *"]}
               })

      assert spec.status == "active"
      assert spec.timezone == "UTC"
      assert spec.overlap_policy == "skip"
      assert spec.failure_threshold == 5
    end

    test "rejects duplicate slug" do
      attrs = %{slug: "dup", name: "X"}
      assert {:ok, _} = Schedule.create_spec(attrs)
      assert {:error, changeset} = Schedule.create_spec(attrs)
      assert "has already been taken" in errors_on(changeset).slug
    end

    test "rejects invalid overlap_policy" do
      assert {:error, changeset} =
               Schedule.create_spec(%{
                 slug: "bad-policy",
                 name: "X",
                 overlap_policy: "explode"
               })

      assert "is invalid" in errors_on(changeset).overlap_policy
    end

    test "rejects invalid status" do
      assert {:error, changeset} =
               Schedule.create_spec(%{
                 slug: "bad-status",
                 name: "X",
                 status: "elsewhere"
               })

      assert "is invalid" in errors_on(changeset).status
    end

    test "rejects end_at before start_at" do
      now = DateTime.utc_now()
      future = DateTime.add(now, 3600, :second)

      assert {:error, changeset} =
               Schedule.create_spec(%{
                 slug: "bad-window",
                 name: "X",
                 start_at: future,
                 end_at: now
               })

      refute Enum.empty?(errors_on(changeset).end_at)
    end

    test "rejects out-of-range jitter_seconds" do
      assert {:error, changeset} =
               Schedule.create_spec(%{
                 slug: "bad-jitter",
                 name: "X",
                 jitter_seconds: 99_999
               })

      refute Enum.empty?(errors_on(changeset).jitter_seconds)
    end
  end

  describe "lifecycle (pause / unpause / archive)" do
    setup do
      {:ok, spec} = Schedule.create_spec(%{slug: "lc", name: "Lifecycle"})
      {:ok, spec: spec}
    end

    test "pause sets status, paused_at, paused_reason", %{spec: spec} do
      assert {:ok, paused} = Schedule.pause_spec(spec, "manual_test")
      assert paused.status == "paused"
      assert paused.paused_at != nil
      assert paused.paused_reason == "manual_test"
    end

    test "unpause clears paused fields and resets failures", %{spec: spec} do
      {:ok, paused} = Schedule.pause_spec(spec, "x")
      assert {:ok, resumed} = Schedule.unpause_spec(paused)
      assert resumed.status == "active"
      assert resumed.paused_at == nil
      assert resumed.paused_reason == nil
      assert resumed.consecutive_failures == 0
    end

    test "archive sets status to archived", %{spec: spec} do
      assert {:ok, archived} = Schedule.archive_spec(spec)
      assert archived.status == "archived"
    end
  end

  describe "list_specs/1" do
    test "filters by status" do
      {:ok, _} = Schedule.create_spec(%{slug: "active-1", name: "A"})
      {:ok, paused} = Schedule.create_spec(%{slug: "paused-1", name: "B"})
      {:ok, _} = Schedule.pause_spec(paused, "x")

      [a] = Schedule.list_specs(status: "active")
      [p] = Schedule.list_specs(status: "paused")
      assert a.slug == "active-1"
      assert p.slug == "paused-1"
    end

    test "filters by agent_slug" do
      {:ok, _} = Schedule.create_spec(%{slug: "a-spec", name: "X", agent_slug: "iris"})
      {:ok, _} = Schedule.create_spec(%{slug: "b-spec", name: "Y", agent_slug: "scheduler"})

      [iris_spec] = Schedule.list_specs(agent_slug: "iris")
      assert iris_spec.slug == "a-spec"
    end
  end

  # ---------------------------------------------------------------------------
  # Runs — history + transitions
  # ---------------------------------------------------------------------------

  describe "record_run/1" do
    setup do
      {:ok, spec} = Schedule.create_spec(%{slug: "run-test", name: "RT"})
      {:ok, spec: spec}
    end

    test "inserts a valid run", %{spec: spec} do
      now = DateTime.utc_now()

      assert {:ok, %Run{} = run} =
               Schedule.record_run(%{
                 spec_id: spec.id,
                 spec_slug: spec.slug,
                 scheduled_at: now,
                 status: "enqueued"
               })

      assert run.spec_id == spec.id
      assert run.status == "enqueued"
      assert run.attempt == 1
    end

    test "rejects invalid status", %{spec: spec} do
      assert {:error, changeset} =
               Schedule.record_run(%{
                 spec_id: spec.id,
                 scheduled_at: DateTime.utc_now(),
                 status: "weird"
               })

      assert "is invalid" in errors_on(changeset).status
    end

    test "rejects attempt < 1", %{spec: spec} do
      assert {:error, changeset} =
               Schedule.record_run(%{
                 spec_id: spec.id,
                 scheduled_at: DateTime.utc_now(),
                 attempt: 0
               })

      refute Enum.empty?(errors_on(changeset).attempt)
    end
  end

  describe "list_runs/1" do
    setup do
      {:ok, spec} = Schedule.create_spec(%{slug: "rl", name: "RL"})

      now = DateTime.utc_now()
      one_hour_ago = DateTime.add(now, -3600, :second)
      two_hours_ago = DateTime.add(now, -7200, :second)

      Schedule.record_run(%{
        spec_id: spec.id,
        spec_slug: spec.slug,
        scheduled_at: now,
        status: "completed"
      })

      Schedule.record_run(%{
        spec_id: spec.id,
        spec_slug: spec.slug,
        scheduled_at: one_hour_ago,
        status: "failed"
      })

      Schedule.record_run(%{
        spec_id: spec.id,
        spec_slug: spec.slug,
        scheduled_at: two_hours_ago,
        status: "completed"
      })

      {:ok, spec: spec, now: now, one_hour_ago: one_hour_ago}
    end

    test "returns runs ordered scheduled_at desc", %{spec: spec} do
      runs = Schedule.list_runs(spec_id: spec.id)
      timestamps = Enum.map(runs, & &1.scheduled_at)
      assert timestamps == Enum.sort(timestamps, {:desc, DateTime})
    end

    test "filters by status", %{spec: spec} do
      [run] = Schedule.list_runs(spec_id: spec.id, status: "failed")
      assert run.status == "failed"
    end

    test "filters by since/until window", %{spec: spec, one_hour_ago: cutoff} do
      runs = Schedule.list_runs(spec_id: spec.id, since: cutoff)
      assert length(runs) == 2
    end

    test "respects limit", %{spec: spec} do
      runs = Schedule.list_runs(spec_id: spec.id, limit: 1)
      assert length(runs) == 1
    end
  end

  describe "aggregate_runs/1" do
    test "buckets by day with status counts" do
      {:ok, spec} = Schedule.create_spec(%{slug: "agg", name: "Agg"})
      now = DateTime.utc_now()

      Schedule.record_run(%{
        spec_id: spec.id,
        scheduled_at: now,
        status: "completed"
      })

      Schedule.record_run(%{
        spec_id: spec.id,
        scheduled_at: now,
        status: "failed"
      })

      Schedule.record_run(%{
        spec_id: spec.id,
        scheduled_at: now,
        status: "missed"
      })

      [bucket] = Schedule.aggregate_runs(granularity: :day, spec_id: spec.id)
      assert bucket.total == 3
      assert bucket.succeeded == 1
      assert bucket.failed == 1
      assert bucket.missed == 1
    end
  end

  # ---------------------------------------------------------------------------
  # Overlap detection
  # ---------------------------------------------------------------------------

  describe "detect_overlaps/1" do
    test "flags two runs scheduled within tolerance for same spec" do
      {:ok, spec} = Schedule.create_spec(%{slug: "ov", name: "Overlap"})
      now = DateTime.utc_now()
      thirty_seconds_later = DateTime.add(now, 30, :second)

      Schedule.record_run(%{
        spec_id: spec.id,
        spec_slug: spec.slug,
        scheduled_at: now,
        status: "running"
      })

      Schedule.record_run(%{
        spec_id: spec.id,
        spec_slug: spec.slug,
        scheduled_at: thirty_seconds_later,
        status: "enqueued"
      })

      [overlap] = Schedule.detect_overlaps(tolerance_seconds: 60, spec_id: spec.id)
      assert overlap.spec_id == spec.id
      assert overlap.gap_seconds == 30
    end

    test "no overlap when gap exceeds tolerance" do
      {:ok, spec} = Schedule.create_spec(%{slug: "noov", name: "NoOverlap"})
      now = DateTime.utc_now()
      far_later = DateTime.add(now, 600, :second)

      Schedule.record_run(%{
        spec_id: spec.id,
        scheduled_at: now,
        status: "running"
      })

      Schedule.record_run(%{
        spec_id: spec.id,
        scheduled_at: far_later,
        status: "enqueued"
      })

      assert Schedule.detect_overlaps(tolerance_seconds: 60, spec_id: spec.id) == []
    end
  end

  # ---------------------------------------------------------------------------
  # Alerts (incidents)
  # ---------------------------------------------------------------------------

  describe "Alerts" do
    test "open_alert inserts with first_seen_at + last_seen_at" do
      assert {:ok, %Alert{} = a} =
               Schedule.open_alert(%{
                 slug: "circuit-1",
                 category: "circuit_breaker",
                 severity: "high",
                 summary: "Circuit breaker for daily-digest"
               })

      assert a.status == "open"
      assert a.first_seen_at != nil
      assert a.last_seen_at != nil
      assert a.failure_count == 1
    end

    test "rejects invalid category" do
      assert {:error, changeset} =
               Schedule.open_alert(%{
                 slug: "bad-cat",
                 category: "explode",
                 summary: "X"
               })

      assert "is invalid" in errors_on(changeset).category
    end

    test "rejects duplicate slug" do
      attrs = %{slug: "dup-alert", category: "miss", summary: "X"}
      assert {:ok, _} = Schedule.open_alert(attrs)
      assert {:error, changeset} = Schedule.open_alert(attrs)
      assert "has already been taken" in errors_on(changeset).slug
    end

    test "close_alert sets closed_at and status" do
      {:ok, alert} =
        Schedule.open_alert(%{slug: "to-close", category: "failure", summary: "X"})

      assert {:ok, closed} = Schedule.close_alert(alert, "fixed")
      assert closed.status == "closed"
      assert closed.closed_at != nil
      assert closed.resolution_note == "fixed"
    end

    test "acknowledge_alert sets acknowledged fields" do
      {:ok, alert} =
        Schedule.open_alert(%{slug: "to-ack", category: "late", summary: "X"})

      assert {:ok, acked} = Schedule.acknowledge_alert(alert, "rhl")
      assert acked.status == "acknowledged"
      assert acked.acknowledged_by == "rhl"
      assert acked.acknowledged_at != nil
    end

    test "record_alert_failure increments and dedupes related runs" do
      {:ok, alert} =
        Schedule.open_alert(%{slug: "grp", category: "failure", summary: "X"})

      run_id = Ecto.UUID.generate()
      assert {:ok, after1} = Schedule.record_alert_failure(alert, run_id)
      assert after1.failure_count == 2
      assert run_id in after1.related_run_ids

      assert {:ok, after2} = Schedule.record_alert_failure(after1, run_id)
      # Same run_id stays unique in array
      assert after2.failure_count == 3
      assert Enum.count(after2.related_run_ids, &(&1 == run_id)) == 1
    end

    test "list_alerts filters by status" do
      Schedule.open_alert(%{slug: "open-x", category: "miss", summary: "X"})

      {:ok, c} =
        Schedule.open_alert(%{slug: "closed-x", category: "miss", summary: "X"})

      Schedule.close_alert(c)

      [open] = Schedule.list_alerts(status: "open")
      assert open.slug == "open-x"
    end
  end
end
