defmodule Canopy.AnalyticsTest do
  @moduledoc """
  Tests for the Canopy.Analytics public API context.

  Covers telemetry ingestion, breadcrumb persistence, insight CRUD,
  alert CRUD, cost aggregation, and edge cases.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Analytics
  alias Canopy.Analytics.Alert
  alias Canopy.Analytics.Breadcrumb
  alias Canopy.Analytics.Insight

  # ---------------------------------------------------------------------------
  # record/1
  # ---------------------------------------------------------------------------

  describe "record/1" do
    test "records a minimal telemetry event" do
      assert :ok = Analytics.record(%{event: "agent.run.started"})

      events = Analytics.query_telemetry(event: "agent.run.started")
      assert length(events) == 1
      assert hd(events).event == "agent.run.started"
    end

    test "auto-fills ts when missing" do
      :ok = Analytics.record(%{event: "test.event"})
      [event] = Analytics.query_telemetry(event: "test.event")
      assert event.ts != nil
      assert DateTime.diff(DateTime.utc_now(), event.ts, :second) < 5
    end

    test "coerces atom event names to strings" do
      :ok = Analytics.record(%{event: :atom_event})
      events = Analytics.query_telemetry(event: "atom_event")
      assert length(events) == 1
    end

    test "swallows errors silently (returns :ok even on bad input)" do
      # Missing required `event` field — would fail validation
      assert :ok = Analytics.record(%{ts: DateTime.utc_now()})
      # No event was inserted
      assert Analytics.query_telemetry(limit: 100) == []
    end

    test "stores all expected fields" do
      run_id = Ecto.UUID.generate()
      session_id = Ecto.UUID.generate()
      agent_id = Ecto.UUID.generate()

      :ok =
        Analytics.record(%{
          event: "agent.run.finished",
          run_id: run_id,
          session_id: session_id,
          agent_id: agent_id,
          workspace_slug: "test-ws",
          runtime: "claude-local",
          model: "claude-sonnet-4-7",
          duration_ms: 1234,
          cost_cents: 42,
          status: "ok",
          payload: %{custom: "field"}
        })

      [event] = Analytics.query_telemetry(run_id: run_id)
      assert event.session_id == session_id
      assert event.agent_id == agent_id
      assert event.workspace_slug == "test-ws"
      assert event.runtime == "claude-local"
      assert event.duration_ms == 1234
      assert event.cost_cents == 42
      assert event.status == "ok"
      assert event.payload == %{"custom" => "field"}
    end
  end

  # ---------------------------------------------------------------------------
  # query_telemetry/1
  # ---------------------------------------------------------------------------

  describe "query_telemetry/1" do
    setup do
      run_id = Ecto.UUID.generate()
      :ok = Analytics.record(%{event: "a", run_id: run_id, cost_cents: 100})
      :ok = Analytics.record(%{event: "b", run_id: run_id, cost_cents: 200})
      :ok = Analytics.record(%{event: "a", run_id: Ecto.UUID.generate()})
      {:ok, run_id: run_id}
    end

    test "returns events sorted by ts descending" do
      events = Analytics.query_telemetry(limit: 10)
      tss = Enum.map(events, & &1.ts)
      assert tss == Enum.sort(tss, {:desc, DateTime})
    end

    test "filters by event", %{run_id: run_id} do
      events = Analytics.query_telemetry(run_id: run_id, event: "a")
      assert length(events) == 1
      assert hd(events).event == "a"
    end

    test "filters by run_id", %{run_id: run_id} do
      events = Analytics.query_telemetry(run_id: run_id)
      assert length(events) == 2
    end

    test "respects limit" do
      events = Analytics.query_telemetry(limit: 1)
      assert length(events) == 1
    end

    test "from/to window filters", %{run_id: run_id} do
      now = DateTime.utc_now()
      one_minute_ago = DateTime.add(now, -60, :second)
      future = DateTime.add(now, 60, :second)

      assert length(Analytics.query_telemetry(run_id: run_id, from: one_minute_ago)) == 2
      assert Analytics.query_telemetry(run_id: run_id, from: future) == []
      assert Analytics.query_telemetry(run_id: run_id, to: one_minute_ago) == []
    end
  end

  # ---------------------------------------------------------------------------
  # aggregate_costs/1
  # ---------------------------------------------------------------------------

  describe "aggregate_costs/1" do
    test "buckets by day" do
      :ok = Analytics.record(%{event: "x", cost_cents: 100})
      :ok = Analytics.record(%{event: "x", cost_cents: 250})

      rows = Analytics.aggregate_costs(granularity: :day)
      assert length(rows) == 1
      assert hd(rows).cost_cents == 350
      assert hd(rows).count == 2
    end

    test "ignores rows with nil cost_cents" do
      :ok = Analytics.record(%{event: "y", cost_cents: 50})
      :ok = Analytics.record(%{event: "y"})

      rows = Analytics.aggregate_costs(granularity: :day)
      total = rows |> Enum.map(& &1.cost_cents) |> Enum.sum()
      assert total == 50
    end

    test "respects from/to window" do
      :ok = Analytics.record(%{event: "z", cost_cents: 100})

      far_past_from = DateTime.add(DateTime.utc_now(), -86_400 * 60, :second)
      far_past_to = DateTime.add(DateTime.utc_now(), -86_400 * 30, :second)

      rows = Analytics.aggregate_costs(granularity: :day, from: far_past_from, to: far_past_to)
      assert rows == []
    end
  end

  # ---------------------------------------------------------------------------
  # Breadcrumbs (DB persistence)
  # ---------------------------------------------------------------------------

  describe "record_breadcrumb/1 and list_breadcrumbs/2" do
    test "persists a single breadcrumb" do
      run_id = Ecto.UUID.generate()

      assert {:ok, %Breadcrumb{} = b} =
               Analytics.record_breadcrumb(%{
                 run_id: run_id,
                 sequence: 0,
                 type: "tool_call",
                 category: "read_file",
                 level: "info",
                 message: "read README.md",
                 data: %{path: "README.md"}
               })

      assert b.run_id == run_id
      assert b.sequence == 0
      assert b.type == "tool_call"
    end

    test "rejects invalid type" do
      run_id = Ecto.UUID.generate()

      assert {:error, changeset} =
               Analytics.record_breadcrumb(%{
                 run_id: run_id,
                 sequence: 0,
                 type: "nonsense"
               })

      assert "is invalid" in errors_on(changeset).type
    end

    test "rejects negative sequence" do
      run_id = Ecto.UUID.generate()

      assert {:error, changeset} =
               Analytics.record_breadcrumb(%{
                 run_id: run_id,
                 sequence: -1,
                 type: "system"
               })

      refute Enum.empty?(errors_on(changeset).sequence)
    end

    test "lists breadcrumbs ordered by sequence" do
      run_id = Ecto.UUID.generate()

      for seq <- [3, 1, 2, 0] do
        Analytics.record_breadcrumb(%{run_id: run_id, sequence: seq, type: "system"})
      end

      crumbs = Analytics.list_breadcrumbs(run_id)
      assert Enum.map(crumbs, & &1.sequence) == [0, 1, 2, 3]
    end

    test "list_breadcrumbs/2 filters by level" do
      run_id = Ecto.UUID.generate()
      Analytics.record_breadcrumb(%{run_id: run_id, sequence: 0, type: "system", level: "info"})
      Analytics.record_breadcrumb(%{run_id: run_id, sequence: 1, type: "system", level: "error"})

      errors = Analytics.list_breadcrumbs(run_id, level: "error")
      assert length(errors) == 1
      assert hd(errors).level == "error"
    end

    test "list_breadcrumbs/2 returns empty for unknown run_id" do
      assert Analytics.list_breadcrumbs(Ecto.UUID.generate()) == []
    end
  end

  describe "record_breadcrumbs/1 (bulk)" do
    test "inserts many in one call" do
      run_id = Ecto.UUID.generate()

      entries =
        for seq <- 0..9 do
          %{run_id: run_id, sequence: seq, type: "tool_call", level: "info"}
        end

      assert {10, nil} = Analytics.record_breadcrumbs(entries)
      assert length(Analytics.list_breadcrumbs(run_id)) == 10
    end

    test "handles empty list" do
      assert {0, nil} = Analytics.record_breadcrumbs([])
    end
  end

  # ---------------------------------------------------------------------------
  # Insights
  # ---------------------------------------------------------------------------

  describe "Insights" do
    test "create_insight inserts a valid insight" do
      assert {:ok, %Insight{} = ins} =
               Analytics.create_insight(%{
                 slug: "anom-2026-04-27",
                 title: "Cost spike on claude-local",
                 body: "Detail goes here",
                 severity: "high",
                 kind: "anomaly",
                 detected_at: DateTime.utc_now()
               })

      assert ins.severity == "high"
      assert ins.kind == "anomaly"
    end

    test "create_insight rejects invalid severity" do
      assert {:error, changeset} =
               Analytics.create_insight(%{
                 slug: "bad-sev",
                 title: "T",
                 body: "B",
                 detected_at: DateTime.utc_now(),
                 severity: "explosive"
               })

      assert "is invalid" in errors_on(changeset).severity
    end

    test "create_insight rejects invalid kind" do
      assert {:error, changeset} =
               Analytics.create_insight(%{
                 slug: "bad-kind",
                 title: "T",
                 body: "B",
                 detected_at: DateTime.utc_now(),
                 kind: "weird"
               })

      assert "is invalid" in errors_on(changeset).kind
    end

    test "create_insight rejects duplicate slug" do
      attrs = %{
        slug: "dup-slug",
        title: "T",
        body: "B",
        detected_at: DateTime.utc_now()
      }

      assert {:ok, _} = Analytics.create_insight(attrs)
      assert {:error, changeset} = Analytics.create_insight(attrs)
      assert "has already been taken" in errors_on(changeset).slug
    end

    test "list_insights filters by severity" do
      Analytics.create_insight(%{
        slug: "low",
        title: "T",
        body: "B",
        severity: "info",
        detected_at: DateTime.utc_now()
      })

      Analytics.create_insight(%{
        slug: "high",
        title: "T",
        body: "B",
        severity: "high",
        detected_at: DateTime.utc_now()
      })

      [ins] = Analytics.list_insights(severity: "high")
      assert ins.slug == "high"
    end

    test "acknowledge_insight sets acknowledged_at and feedback" do
      {:ok, ins} =
        Analytics.create_insight(%{
          slug: "ack-test",
          title: "T",
          body: "B",
          detected_at: DateTime.utc_now()
        })

      assert {:ok, updated} =
               Analytics.acknowledge_insight(ins, "rhl", "true_positive")

      assert updated.acknowledged_by == "rhl"
      assert updated.feedback == "true_positive"
      assert updated.acknowledged_at != nil
    end

    test "get_insight! raises on unknown slug" do
      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_insight!("does-not-exist")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Alerts
  # ---------------------------------------------------------------------------

  describe "Alerts" do
    test "create_alert inserts a valid alert" do
      assert {:ok, %Alert{} = a} =
               Analytics.create_alert(%{
                 slug: "cost-anom",
                 name: "Cost anomaly",
                 metric: "cost_cents",
                 type: "anomaly",
                 sensitivity: 0.85
               })

      assert a.enabled == true
      assert a.fire_count == 0
    end

    test "create_alert rejects sensitivity > 1.0" do
      assert {:error, changeset} =
               Analytics.create_alert(%{
                 slug: "bad-sens",
                 name: "X",
                 metric: "y",
                 type: "anomaly",
                 sensitivity: 1.5
               })

      refute Enum.empty?(errors_on(changeset).sensitivity)
    end

    test "create_alert rejects invalid type" do
      assert {:error, changeset} =
               Analytics.create_alert(%{
                 slug: "bad-type",
                 name: "X",
                 metric: "y",
                 type: "fake"
               })

      assert "is invalid" in errors_on(changeset).type
    end

    test "record_fire/1 increments fire_count and timestamps" do
      {:ok, alert} =
        Analytics.create_alert(%{
          slug: "fire-test",
          name: "X",
          metric: "y",
          type: "threshold"
        })

      assert {:ok, updated} = Analytics.record_fire(alert)
      assert updated.fire_count == 1
      assert updated.last_fired_at != nil
      assert updated.last_evaluated_at != nil
    end

    test "list_alerts filters by enabled" do
      Analytics.create_alert(%{
        slug: "on",
        name: "X",
        metric: "y",
        type: "anomaly",
        enabled: true
      })

      Analytics.create_alert(%{
        slug: "off",
        name: "X",
        metric: "y",
        type: "anomaly",
        enabled: false
      })

      [on] = Analytics.list_alerts(enabled: true)
      assert on.slug == "on"
    end
  end
end
