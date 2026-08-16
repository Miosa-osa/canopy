defmodule Canopy.SandboxesNgTest do
  @moduledoc """
  Tests for the Canopy.SandboxesNg public API context.

  Covers lifecycle event recording, snapshot CRUD with retention policy,
  port-forward open/close semantics with the active-uniqueness invariant,
  and alert configuration.
  """

  use Canopy.DataCase, async: true

  alias Canopy.SandboxesNg
  alias Canopy.SandboxesNg.Alert
  alias Canopy.SandboxesNg.LifecycleEvent
  alias Canopy.SandboxesNg.PortForward
  alias Canopy.SandboxesNg.Snapshot

  # ---------------------------------------------------------------------------
  # record_event/1
  # ---------------------------------------------------------------------------

  describe "record_event/1" do
    test "records a minimal lifecycle event" do
      assert :ok =
               SandboxesNg.record_event(%{
                 sandbox_id: "sbx-1",
                 state: "provisioning"
               })

      events = SandboxesNg.list_events(sandbox_id: "sbx-1")
      assert length(events) == 1
      assert hd(events).state == "provisioning"
    end

    test "auto-fills ts when missing" do
      :ok = SandboxesNg.record_event(%{sandbox_id: "sbx-2", state: "running"})
      [event] = SandboxesNg.list_events(sandbox_id: "sbx-2")
      assert event.ts != nil
      assert DateTime.diff(DateTime.utc_now(), event.ts, :second) < 5
    end

    test "swallows errors silently on bad state" do
      assert :ok =
               SandboxesNg.record_event(%{
                 sandbox_id: "sbx-3",
                 state: "frobnicated"
               })

      assert SandboxesNg.list_events(sandbox_id: "sbx-3") == []
    end

    test "stores all expected fields" do
      owner_id = Ecto.UUID.generate()

      :ok =
        SandboxesNg.record_event(%{
          sandbox_id: "sbx-4",
          state: "running",
          prior_state: "provisioning",
          owner_agent_id: owner_id,
          workspace_slug: "test-ws",
          reason: "test:setup",
          payload: %{custom: "field"}
        })

      [event] = SandboxesNg.list_events(sandbox_id: "sbx-4")
      assert event.prior_state == "provisioning"
      assert event.owner_agent_id == owner_id
      assert event.workspace_slug == "test-ws"
      assert event.reason == "test:setup"
      assert event.payload == %{"custom" => "field"}
    end
  end

  # ---------------------------------------------------------------------------
  # list_current_states/1
  # ---------------------------------------------------------------------------

  describe "list_current_states/1" do
    test "returns most-recent event per sandbox" do
      now = DateTime.utc_now()
      earlier = DateTime.add(now, -300, :second)

      :ok =
        SandboxesNg.record_event(%{
          sandbox_id: "sbx-cur-1",
          state: "provisioning",
          ts: earlier
        })

      :ok =
        SandboxesNg.record_event(%{
          sandbox_id: "sbx-cur-1",
          state: "running",
          prior_state: "provisioning",
          ts: now
        })

      states = SandboxesNg.list_current_states()
      cur = Enum.find(states, &(&1.sandbox_id == "sbx-cur-1"))
      assert cur.state == "running"
    end
  end

  # ---------------------------------------------------------------------------
  # Snapshots
  # ---------------------------------------------------------------------------

  describe "create_snapshot/1" do
    test "creates a filesystem snapshot with no retention_until" do
      assert {:ok, %Snapshot{} = snap} =
               SandboxesNg.create_snapshot(%{
                 slug: "snap-fs-1",
                 sandbox_id: "sbx-snap-1",
                 kind: "filesystem"
               })

      assert snap.kind == "filesystem"
      assert snap.retention_until == nil
    end

    test "creates a directory snapshot with 30-day retention" do
      now = DateTime.utc_now()

      assert {:ok, snap} =
               SandboxesNg.create_snapshot(%{
                 slug: "snap-dir-1",
                 sandbox_id: "sbx-snap-2",
                 kind: "directory",
                 path: "/work"
               })

      assert snap.retention_until != nil
      diff_days = DateTime.diff(snap.retention_until, now, :second) / 86_400
      assert diff_days > 29 and diff_days < 31
    end

    test "creates a memory snapshot with 7-day retention" do
      now = DateTime.utc_now()

      assert {:ok, snap} =
               SandboxesNg.create_snapshot(%{
                 slug: "snap-mem-1",
                 sandbox_id: "sbx-snap-3",
                 kind: "memory"
               })

      assert snap.retention_until != nil
      diff_days = DateTime.diff(snap.retention_until, now, :second) / 86_400
      assert diff_days > 6 and diff_days < 8
    end

    test "rejects invalid kind" do
      assert {:error, changeset} =
               SandboxesNg.create_snapshot(%{
                 slug: "snap-bad-1",
                 sandbox_id: "sbx-snap-4",
                 kind: "ram-dump"
               })

      assert "is invalid" in errors_on(changeset).kind
    end

    test "rejects duplicate slug" do
      attrs = %{slug: "dup-snap", sandbox_id: "sbx-snap-5", kind: "memory"}
      assert {:ok, _} = SandboxesNg.create_snapshot(attrs)
      assert {:error, changeset} = SandboxesNg.create_snapshot(attrs)
      assert "has already been taken" in errors_on(changeset).slug
    end

    test "list_snapshots filters by kind" do
      SandboxesNg.create_snapshot(%{
        slug: "filt-fs-1",
        sandbox_id: "sbx-filt",
        kind: "filesystem"
      })

      SandboxesNg.create_snapshot(%{
        slug: "filt-mem-1",
        sandbox_id: "sbx-filt",
        kind: "memory"
      })

      [s] = SandboxesNg.list_snapshots(sandbox_id: "sbx-filt", kind: "filesystem")
      assert s.kind == "filesystem"
    end

    test "reap_snapshot marks reaped_at" do
      {:ok, snap} =
        SandboxesNg.create_snapshot(%{
          slug: "reap-1",
          sandbox_id: "sbx-reap",
          kind: "memory"
        })

      assert {:ok, reaped} = SandboxesNg.reap_snapshot(snap)
      assert reaped.reaped_at != nil
    end

    test "list_expired_snapshots returns past-retention non-reaped only" do
      past = DateTime.add(DateTime.utc_now(), -60, :second)
      future = DateTime.add(DateTime.utc_now(), 60, :second)

      {:ok, expired} =
        SandboxesNg.create_snapshot(%{
          slug: "exp-1",
          sandbox_id: "sbx-exp",
          kind: "memory",
          retention_until: past
        })

      {:ok, _live} =
        SandboxesNg.create_snapshot(%{
          slug: "live-1",
          sandbox_id: "sbx-exp",
          kind: "memory",
          retention_until: future
        })

      slugs = SandboxesNg.list_expired_snapshots() |> Enum.map(& &1.slug)
      assert "exp-1" in slugs
      refute "live-1" in slugs

      {:ok, _} = SandboxesNg.reap_snapshot(expired)
      slugs = SandboxesNg.list_expired_snapshots() |> Enum.map(& &1.slug)
      refute "exp-1" in slugs
    end
  end

  # ---------------------------------------------------------------------------
  # Port forwards
  # ---------------------------------------------------------------------------

  describe "Port forwards" do
    test "creates a private forward by default" do
      assert {:ok, %PortForward{} = pf} =
               SandboxesNg.create_port_forward(%{
                 sandbox_id: "sbx-port-1",
                 internal_port: 3000
               })

      assert pf.visibility == "private"
      assert pf.protocol == "http"
      assert pf.closed_at == nil
    end

    test "rejects two open forwards for the same sandbox+port" do
      attrs = %{sandbox_id: "sbx-port-2", internal_port: 8080}
      assert {:ok, _} = SandboxesNg.create_port_forward(attrs)

      assert {:error, changeset} = SandboxesNg.create_port_forward(attrs)
      assert errors_on(changeset)[:sandbox_id]
    end

    test "allows reusing port after the prior forward is closed" do
      attrs = %{sandbox_id: "sbx-port-3", internal_port: 5432}
      {:ok, first} = SandboxesNg.create_port_forward(attrs)

      {:ok, _closed} = SandboxesNg.close_port_forward(first)

      assert {:ok, _second} = SandboxesNg.create_port_forward(attrs)
    end

    test "rejects port outside 1..65535" do
      assert {:error, changeset} =
               SandboxesNg.create_port_forward(%{
                 sandbox_id: "sbx-port-4",
                 internal_port: 0
               })

      refute Enum.empty?(errors_on(changeset).internal_port)

      assert {:error, changeset2} =
               SandboxesNg.create_port_forward(%{
                 sandbox_id: "sbx-port-4",
                 internal_port: 100_000
               })

      refute Enum.empty?(errors_on(changeset2).internal_port)
    end

    test "rejects invalid visibility" do
      assert {:error, changeset} =
               SandboxesNg.create_port_forward(%{
                 sandbox_id: "sbx-port-5",
                 internal_port: 4444,
                 visibility: "world-readable"
               })

      assert "is invalid" in errors_on(changeset).visibility
    end

    test "update_visibility flips a forward's tier" do
      {:ok, pf} =
        SandboxesNg.create_port_forward(%{
          sandbox_id: "sbx-port-6",
          internal_port: 6000
        })

      assert {:ok, updated} = SandboxesNg.update_visibility(pf, "token")
      assert updated.visibility == "token"
    end

    test "get_active_forward returns the open row" do
      {:ok, pf} =
        SandboxesNg.create_port_forward(%{
          sandbox_id: "sbx-port-7",
          internal_port: 7777
        })

      assert SandboxesNg.get_active_forward("sbx-port-7", 7777).id == pf.id

      {:ok, _} = SandboxesNg.close_port_forward(pf)
      assert SandboxesNg.get_active_forward("sbx-port-7", 7777) == nil
    end

    test "list_port_forwards open_only filters out closed" do
      {:ok, open} =
        SandboxesNg.create_port_forward(%{
          sandbox_id: "sbx-port-8",
          internal_port: 8001
        })

      {:ok, closed} =
        SandboxesNg.create_port_forward(%{
          sandbox_id: "sbx-port-9",
          internal_port: 8002
        })

      {:ok, _} = SandboxesNg.close_port_forward(closed)

      ids =
        SandboxesNg.list_port_forwards(open_only: true)
        |> Enum.map(& &1.id)

      assert open.id in ids
      refute closed.id in ids
    end
  end

  # ---------------------------------------------------------------------------
  # Alerts
  # ---------------------------------------------------------------------------

  describe "Alerts" do
    test "creates a valid alert" do
      assert {:ok, %Alert{} = a} =
               SandboxesNg.create_alert(%{
                 slug: "ng-public-port-high",
                 name: "Public port count high",
                 metric: "public_port_count",
                 type: "threshold"
               })

      assert a.enabled == true
      assert a.fire_count == 0
    end

    test "rejects invalid type" do
      assert {:error, changeset} =
               SandboxesNg.create_alert(%{
                 slug: "ng-bad-type",
                 name: "X",
                 metric: "y",
                 type: "magic"
               })

      assert "is invalid" in errors_on(changeset).type
    end

    test "rejects duplicate slug" do
      attrs = %{
        slug: "ng-dup",
        name: "X",
        metric: "y",
        type: "threshold"
      }

      assert {:ok, _} = SandboxesNg.create_alert(attrs)
      assert {:error, changeset} = SandboxesNg.create_alert(attrs)
      assert "has already been taken" in errors_on(changeset).slug
    end

    test "record_fire/1 increments fire_count and timestamps" do
      {:ok, alert} =
        SandboxesNg.create_alert(%{
          slug: "ng-fire-test",
          name: "X",
          metric: "y",
          type: "threshold"
        })

      assert {:ok, updated} = SandboxesNg.record_fire(alert)
      assert updated.fire_count == 1
      assert updated.last_fired_at != nil
      assert updated.last_evaluated_at != nil
    end

    test "list_alerts filters by enabled" do
      SandboxesNg.create_alert(%{
        slug: "ng-on",
        name: "X",
        metric: "y",
        type: "threshold",
        enabled: true
      })

      SandboxesNg.create_alert(%{
        slug: "ng-off",
        name: "X",
        metric: "y",
        type: "threshold",
        enabled: false
      })

      [on] = SandboxesNg.list_alerts(enabled: true)
      assert on.slug == "ng-on"
    end
  end

  # ---------------------------------------------------------------------------
  # LifecycleEvent struct sanity
  # ---------------------------------------------------------------------------

  describe "LifecycleEvent" do
    test "states/0 returns the 8 user-facing taxonomy" do
      assert LifecycleEvent.states() == [
               "provisioning",
               "running",
               "paused",
               "snapshotting",
               "archived",
               "resizing",
               "error",
               "destroyed"
             ]
    end
  end
end
