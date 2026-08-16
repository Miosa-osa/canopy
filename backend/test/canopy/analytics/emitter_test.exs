defmodule Canopy.Analytics.EmitterTest do
  @moduledoc """
  Verifies each Emitter helper produces the right telemetry record (and, for
  governance helpers, the right breadcrumb).

  Covers:
  - Event names match the canonical vocabulary in `Canopy.Analytics.Telemetry`.
  - Common fields (run_id, session_id, agent_id, workspace_slug, runtime,
    model) flow from caller-supplied attrs into the persisted row.
  - Status defaults are correct ("ok" / "warn" / "error" / "info").
  - Payload merging works (rule metadata + caller-supplied extras).
  - All helpers return :ok and never raise.
  """

  use Canopy.DataCase, async: false

  alias Canopy.Analytics
  alias Canopy.Analytics.Breadcrumbs
  alias Canopy.Analytics.Emitter

  defp recent_event(name) do
    case Analytics.query_telemetry(event: name, limit: 1) do
      [event | _] -> event
      [] -> nil
    end
  end

  # ---------------------------------------------------------------------------
  # Agent run lifecycle
  # ---------------------------------------------------------------------------

  describe "agent_run_started/1" do
    test "records agent.run.started with run/session/runtime/model" do
      run_id = Ecto.UUID.generate()
      session_id = Ecto.UUID.generate()

      assert :ok =
               Emitter.agent_run_started(%{
                 run_id: run_id,
                 session_id: session_id,
                 workspace_slug: "ws-1",
                 runtime: "claude-local",
                 model: "sonnet-4"
               })

      event = recent_event("agent.run.started")
      assert event != nil
      assert event.run_id == run_id
      assert event.session_id == session_id
      assert event.workspace_slug == "ws-1"
      assert event.runtime == "claude-local"
      assert event.model == "sonnet-4"
      assert event.status == "info"
    end
  end

  describe "agent_run_finished/2" do
    test "records agent.run.finished with metrics" do
      run_id = Ecto.UUID.generate()

      assert :ok =
               Emitter.agent_run_finished(
                 %{run_id: run_id, runtime: "claude-local"},
                 %{duration_ms: 4321, cost_cents: 17}
               )

      event = recent_event("agent.run.finished")
      assert event.run_id == run_id
      assert event.duration_ms == 4321
      assert event.cost_cents == 17
      assert event.status == "ok"
    end
  end

  describe "agent_run_failed/2" do
    test "records agent.run.failed with reason payload" do
      run_id = Ecto.UUID.generate()

      assert :ok =
               Emitter.agent_run_failed(
                 %{run_id: run_id},
                 %{reason: "timeout", duration_ms: 99}
               )

      event = recent_event("agent.run.failed")
      assert event.run_id == run_id
      assert event.status == "error"
      assert event.duration_ms == 99
      assert event.payload["reason"] == "timeout"
    end
  end

  # ---------------------------------------------------------------------------
  # Sessions
  # ---------------------------------------------------------------------------

  describe "session_created/1" do
    test "records session.created" do
      session_id = Ecto.UUID.generate()
      assert :ok = Emitter.session_created(%{session_id: session_id, runtime: "codex-local"})

      event = recent_event("session.created")
      assert event.session_id == session_id
      assert event.runtime == "codex-local"
      assert event.status == "info"
    end
  end

  describe "session_completed/1" do
    test "records session.completed with duration + cost" do
      session_id = Ecto.UUID.generate()

      assert :ok =
               Emitter.session_completed(%{
                 session_id: session_id,
                 duration_ms: 1500,
                 cost_cents: 9
               })

      event = recent_event("session.completed")
      assert event.session_id == session_id
      assert event.duration_ms == 1500
      assert event.cost_cents == 9
      assert event.status == "ok"
    end
  end

  describe "session_cancelled/1" do
    test "records session.cancelled" do
      session_id = Ecto.UUID.generate()
      assert :ok = Emitter.session_cancelled(%{session_id: session_id})

      event = recent_event("session.cancelled")
      assert event.session_id == session_id
      assert event.status == "warn"
    end
  end

  # ---------------------------------------------------------------------------
  # Governance
  # ---------------------------------------------------------------------------

  describe "governance_approved/2" do
    test "records governance.approved with rule metadata in payload" do
      session_id = Ecto.UUID.generate()
      rule = %{id: "rule-uuid-approved", name: "max-cost", action: "require_approval"}

      assert :ok = Emitter.governance_approved(%{session_id: session_id}, rule)

      event = recent_event("governance.approved")
      assert event.session_id == session_id
      assert event.status == "ok"
      assert event.payload["rule_id"] == "rule-uuid-approved"
      assert event.payload["rule_name"] == "max-cost"
    end

    test "adds breadcrumb when run_id is provided" do
      run_id = Ecto.UUID.generate()
      rule = %{id: "rid", name: "approve-rule"}

      assert :ok =
               Emitter.governance_approved(%{run_id: run_id, session_id: nil}, rule)

      crumbs = Breadcrumbs.list(run_id)
      assert Enum.any?(crumbs, fn c -> c.type == "governance" and c.category == "approve-rule" end)

      Breadcrumbs.drop(run_id)
    end
  end

  describe "governance_rejected/2" do
    test "records governance.rejected with status=error" do
      session_id = Ecto.UUID.generate()
      rule = %{id: "rid-rej", name: "no-prod-deploy", action: "block"}

      assert :ok = Emitter.governance_rejected(%{session_id: session_id}, rule)

      event = recent_event("governance.rejected")
      assert event.session_id == session_id
      assert event.status == "error"
      assert event.payload["rule_name"] == "no-prod-deploy"
    end
  end

  describe "governance_escalated/2" do
    test "records governance.escalated with status=warn" do
      session_id = Ecto.UUID.generate()
      rule = %{id: "rid-esc", name: "needs-review"}

      assert :ok = Emitter.governance_escalated(%{session_id: session_id}, rule)

      event = recent_event("governance.escalated")
      assert event.session_id == session_id
      assert event.status == "warn"
      assert event.payload["rule_name"] == "needs-review"
    end
  end

  # ---------------------------------------------------------------------------
  # Budgets
  # ---------------------------------------------------------------------------

  describe "budget_warned/2" do
    test "records budget.threshold_warned with serialised Decimal limit" do
      assert :ok =
               Emitter.budget_warned(%{}, %{
                 budget_id: "b1",
                 scope_type: "global",
                 limit_usd: Decimal.new("100.00"),
                 spent: Decimal.new("90.00")
               })

      event = recent_event("budget.threshold_warned")
      assert event.status == "warn"
      assert event.payload["budget_id"] == "b1"
      assert event.payload["scope_type"] == "global"
      assert event.payload["limit_usd"] == "100.00"
    end
  end

  describe "budget_blocked/2" do
    test "records budget.ceiling_blocked with status=error" do
      assert :ok =
               Emitter.budget_blocked(%{}, %{
                 budget_id: "b2",
                 scope_type: "agent",
                 limit_usd: Decimal.new("50"),
                 spent: Decimal.new("75"),
                 reason: "hard_ceiling"
               })

      event = recent_event("budget.ceiling_blocked")
      assert event.status == "error"
      assert event.payload["budget_id"] == "b2"
      assert event.payload["reason"] == "hard_ceiling"
    end
  end

  # ---------------------------------------------------------------------------
  # Heartbeats
  # ---------------------------------------------------------------------------

  describe "heartbeat_fired/1" do
    test "records heartbeat.fired with payload" do
      session_id = Ecto.UUID.generate()

      assert :ok =
               Emitter.heartbeat_fired(%{
                 session_id: session_id,
                 payload: %{"agent_slug" => "iris"}
               })

      event = recent_event("heartbeat.fired")
      assert event.session_id == session_id
      assert event.status == "info"
      assert event.payload["agent_slug"] == "iris"
    end
  end

  describe "heartbeat_missed/1" do
    test "records heartbeat.missed with status=warn" do
      assert :ok =
               Emitter.heartbeat_missed(%{
                 payload: %{"agent_slug" => "iris", "reason" => "not_found"}
               })

      event = recent_event("heartbeat.missed")
      assert event.status == "warn"
      assert event.payload["reason"] == "not_found"
    end
  end

  # ---------------------------------------------------------------------------
  # Runtimes
  # ---------------------------------------------------------------------------

  describe "runtime_swapped/2" do
    test "records runtime.swapped with runtime + payload" do
      assert :ok =
               Emitter.runtime_swapped("claude-local", %{
                 payload: %{"previous" => "OldMod", "current" => "NewMod"}
               })

      event = recent_event("runtime.swapped")
      assert event.runtime == "claude-local"
      assert event.status == "info"
      assert event.payload["current"] == "NewMod"
    end
  end

  describe "runtime_test_failed/2" do
    test "records runtime.test_failed with status=error" do
      assert :ok =
               Emitter.runtime_test_failed("codex-local", %{
                 payload: %{"reason" => ":not_installed"}
               })

      event = recent_event("runtime.test_failed")
      assert event.runtime == "codex-local"
      assert event.status == "error"
      assert event.payload["reason"] == ":not_installed"
    end
  end

  # ---------------------------------------------------------------------------
  # Breadcrumbs
  # ---------------------------------------------------------------------------

  describe "tool_call_breadcrumb/3" do
    test "no-ops when run_id is nil" do
      assert :ok = Emitter.tool_call_breadcrumb(nil, "read_file", %{"path" => "/tmp/x"})
    end

    test "adds a tool_call breadcrumb when run_id is given" do
      run_id = Ecto.UUID.generate()

      assert :ok =
               Emitter.tool_call_breadcrumb(run_id, "read_file", %{
                 "path" => "/tmp/x.txt",
                 "depth" => 3
               })

      [crumb] = Breadcrumbs.list(run_id)
      assert crumb.type == "tool_call"
      assert crumb.category == "read_file"
      assert crumb.level == "info"
      assert crumb.data["path"] == "/tmp/x.txt"

      Breadcrumbs.drop(run_id)
    end

    test "summarises long string args" do
      run_id = Ecto.UUID.generate()
      long = String.duplicate("a", 500)

      assert :ok = Emitter.tool_call_breadcrumb(run_id, "write_file", %{"body" => long})

      [crumb] = Breadcrumbs.list(run_id)
      truncated = crumb.data["body"]
      assert is_binary(truncated)
      assert byte_size(truncated) < 500

      Breadcrumbs.drop(run_id)
    end
  end

  # ---------------------------------------------------------------------------
  # Resilience
  # ---------------------------------------------------------------------------

  describe "resilience" do
    test "all helpers return :ok with empty input and never raise" do
      assert :ok = Emitter.agent_run_started(%{})
      assert :ok = Emitter.agent_run_finished(%{})
      assert :ok = Emitter.agent_run_failed(%{})
      assert :ok = Emitter.session_created(%{})
      assert :ok = Emitter.session_completed(%{})
      assert :ok = Emitter.session_cancelled(%{})
      assert :ok = Emitter.governance_approved(%{})
      assert :ok = Emitter.governance_rejected(%{})
      assert :ok = Emitter.governance_escalated(%{})
      assert :ok = Emitter.budget_warned(%{})
      assert :ok = Emitter.budget_blocked(%{})
      assert :ok = Emitter.heartbeat_fired(%{})
      assert :ok = Emitter.heartbeat_missed(%{})
      assert :ok = Emitter.runtime_swapped(nil)
      assert :ok = Emitter.runtime_test_failed(nil)
    end
  end
end
