defmodule Canopy.GovernanceTest do
  @moduledoc """
  Integration tests for the Canopy.Governance public API.

  Covers rule CRUD, evaluate/1 priority ordering, approval lifecycle,
  audit log appending, and the exit-criteria scenario:
    a rule with prompt_regex "deploy" + action "block" correctly returns
    {:block, rule} for a session with prompt "please deploy the app".
  """

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Governance
  alias Canopy.Governance.{Approval, Rule}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp rule_attrs(overrides) do
    Map.merge(
      %{
        "name" => "test-rule-#{System.unique_integer([:positive])}",
        "action" => "log",
        "enabled" => true,
        "priority" => 0,
        "conditions" => %{}
      },
      overrides
    )
  end

  defp create_rule!(overrides) do
    {:ok, rule} = Governance.create_rule(rule_attrs(overrides))
    rule
  end

  defp session_id, do: insert(:session).id

  # ---------------------------------------------------------------------------
  # list_rules / get_rule!
  # ---------------------------------------------------------------------------

  describe "list_rules/1" do
    test "returns empty list when no rules exist" do
      assert [] = Governance.list_rules()
    end

    test "returns all rules ordered by priority descending" do
      create_rule!(%{"name" => "low", "priority" => 1})
      create_rule!(%{"name" => "high", "priority" => 10})
      create_rule!(%{"name" => "mid", "priority" => 5})

      rules = Governance.list_rules()
      priorities = Enum.map(rules, & &1.priority)
      assert priorities == Enum.sort(priorities, :desc)
    end

    test "enabled_only: true filters disabled rules" do
      create_rule!(%{"name" => "enabled-one", "enabled" => true})
      create_rule!(%{"name" => "disabled-one", "enabled" => false})

      rules = Governance.list_rules(enabled_only: true)
      assert Enum.all?(rules, & &1.enabled)
    end
  end

  describe "get_rule!/1" do
    test "returns rule by id" do
      rule = create_rule!(%{})
      fetched = Governance.get_rule!(rule.id)
      assert fetched.id == rule.id
    end

    test "raises Ecto.NoResultsError for unknown id" do
      assert_raise Ecto.NoResultsError, fn ->
        Governance.get_rule!(Ecto.UUID.generate())
      end
    end
  end

  # ---------------------------------------------------------------------------
  # create_rule / update_rule / delete_rule
  # ---------------------------------------------------------------------------

  describe "create_rule/1" do
    test "creates a rule with all fields" do
      attrs =
        rule_attrs(%{
          "description" => "Block deploy prompts",
          "action" => "block",
          "conditions" => %{"prompt_regex" => "deploy"},
          "priority" => 100
        })

      assert {:ok, rule} = Governance.create_rule(attrs)
      assert rule.action == "block"
      assert rule.conditions == %{"prompt_regex" => "deploy"}
      assert rule.priority == 100
    end

    test "returns changeset error on missing name" do
      assert {:error, cs} = Governance.create_rule(%{"action" => "block"})
      assert %{name: ["can't be blank"]} = errors_on(cs)
    end

    test "returns changeset error on invalid action" do
      assert {:error, cs} = Governance.create_rule(rule_attrs(%{"action" => "unknown"}))
      assert %{action: _} = errors_on(cs)
    end

    test "enforces unique name" do
      create_rule!(%{"name" => "unique-rule"})
      assert {:error, cs} = Governance.create_rule(rule_attrs(%{"name" => "unique-rule"}))
      assert %{name: _} = errors_on(cs)
    end
  end

  describe "update_rule/2" do
    test "updates rule fields" do
      rule = create_rule!(%{"priority" => 0})
      {:ok, updated} = Governance.update_rule(rule, %{"priority" => 50})
      assert updated.priority == 50
    end

    test "returns changeset error on invalid update" do
      rule = create_rule!(%{})
      assert {:error, _cs} = Governance.update_rule(rule, %{"action" => "bad"})
    end
  end

  describe "delete_rule/1" do
    test "deletes the rule" do
      rule = create_rule!(%{})
      assert {:ok, _} = Governance.delete_rule(rule)

      assert_raise Ecto.NoResultsError, fn ->
        Governance.get_rule!(rule.id)
      end
    end
  end

  describe "enable_rule/1 and disable_rule/1" do
    test "enable_rule sets enabled to true" do
      rule = create_rule!(%{"enabled" => false})
      {:ok, enabled} = Governance.enable_rule(rule)
      assert enabled.enabled == true
    end

    test "disable_rule sets enabled to false" do
      rule = create_rule!(%{"enabled" => true})
      {:ok, disabled} = Governance.disable_rule(rule)
      assert disabled.enabled == false
    end
  end

  # ---------------------------------------------------------------------------
  # evaluate/1 — EXIT CRITERIA scenario
  # ---------------------------------------------------------------------------

  describe "evaluate/1" do
    test "EXIT CRITERIA: block rule with prompt_regex 'deploy' blocks deploy prompt" do
      create_rule!(%{
        "name" => "no-deploy",
        "action" => "block",
        "conditions" => %{"prompt_regex" => "deploy"},
        "priority" => 100,
        "enabled" => true
      })

      result = Governance.evaluate(%{"prompt" => "please deploy the app"})
      assert {:block, %Rule{name: "no-deploy"}} = result
    end

    test "returns :pass when no rules exist" do
      assert :pass = Governance.evaluate(%{"prompt" => "hello world"})
    end

    test "returns :pass when no rules match" do
      create_rule!(%{"action" => "block", "conditions" => %{"prompt_regex" => "deploy"}})
      assert :pass = Governance.evaluate(%{"prompt" => "run the tests"})
    end

    test "returns :pass when all rules are disabled" do
      create_rule!(%{"action" => "block", "enabled" => false, "conditions" => %{}})
      assert :pass = Governance.evaluate(%{"prompt" => "anything"})
    end

    test "require_approval action returns {:require_approval, rule}" do
      rule =
        create_rule!(%{
          "action" => "require_approval",
          "conditions" => %{"runtime" => "claude-local"}
        })

      result = Governance.evaluate(%{"runtime_type" => "claude-local"})
      assert {:require_approval, %Rule{id: id}} = result
      assert id == rule.id
    end

    test "warn action returns {:warn, rule}" do
      rule = create_rule!(%{"action" => "warn", "conditions" => %{"agent_slug" => "risky-agent"}})

      result = Governance.evaluate(%{"agent_slug" => "risky-agent"})
      assert {:warn, %Rule{id: id}} = result
      assert id == rule.id
    end

    test "log action does not block — evaluation continues to next rule" do
      create_rule!(%{
        "name" => "log-rule",
        "action" => "log",
        "conditions" => %{},
        "priority" => 10
      })

      block_rule =
        create_rule!(%{
          "name" => "block-rule",
          "action" => "block",
          "conditions" => %{"prompt_regex" => "deploy"},
          "priority" => 5
        })

      result = Governance.evaluate(%{"prompt" => "deploy the thing"})
      assert {:block, %Rule{id: id}} = result
      assert id == block_rule.id
    end

    test "higher priority rule wins over lower priority rule" do
      create_rule!(%{
        "name" => "low-prio-block",
        "action" => "block",
        "conditions" => %{"prompt_regex" => "deploy"},
        "priority" => 1
      })

      high_rule =
        create_rule!(%{
          "name" => "high-prio-warn",
          "action" => "warn",
          "conditions" => %{"prompt_regex" => "deploy"},
          "priority" => 100
        })

      result = Governance.evaluate(%{"prompt" => "please deploy the app"})
      assert {:warn, %Rule{id: id}} = result
      assert id == high_rule.id
    end

    test "evaluate/1 writes audit log entry on pass" do
      count_before = length(Governance.list_audit())
      Governance.evaluate(%{"prompt" => "hello"})
      count_after = length(Governance.list_audit())
      assert count_after >= count_before + 1
    end

    test "evaluate/1 writes session_blocked audit entry on block" do
      create_rule!(%{
        "action" => "block",
        "conditions" => %{"prompt_regex" => "danger"},
        "priority" => 99
      })

      sid = session_id()
      Governance.evaluate(%{"prompt" => "danger zone", "session_id" => sid})

      audit = Governance.list_audit(event_type: "session_blocked", session_id: sid)
      assert length(audit) >= 1
    end
  end

  # ---------------------------------------------------------------------------
  # request_approval / approve / reject
  # ---------------------------------------------------------------------------

  describe "request_approval/2" do
    test "creates a pending approval record" do
      rule = create_rule!(%{"action" => "require_approval"})
      sid = session_id()

      assert {:ok, %Approval{status: "pending"}} = Governance.request_approval(rule.id, sid)
    end

    test "writes approval_requested audit entry" do
      rule = create_rule!(%{"action" => "require_approval"})
      sid = session_id()

      Governance.request_approval(rule.id, sid)

      audit = Governance.list_audit(event_type: "approval_requested", session_id: sid)
      assert length(audit) >= 1
    end
  end

  describe "approve/3" do
    setup do
      rule = create_rule!(%{"action" => "require_approval"})
      sid = session_id()
      {:ok, approval} = Governance.request_approval(rule.id, sid)
      %{approval: approval, session_id: sid}
    end

    test "transitions approval to approved", %{approval: approval} do
      assert {:ok, updated} = Governance.approve(approval.id, "roberto", "looks good")
      assert updated.status == "approved"
      assert updated.decided_by == "roberto"
      assert updated.decision_reason == "looks good"
      assert %DateTime{} = updated.decided_at
    end

    test "writes approval_granted audit entry", %{approval: approval, session_id: sid} do
      Governance.approve(approval.id, "roberto", "ok")
      audit = Governance.list_audit(event_type: "approval_granted", session_id: sid)
      assert length(audit) >= 1
    end

    test "returns :not_found for unknown approval id" do
      assert {:error, :not_found} = Governance.approve(Ecto.UUID.generate(), "roberto", "ok")
    end

    test "returns already_decided error on double-approve", %{approval: approval} do
      {:ok, _} = Governance.approve(approval.id, "roberto", "ok")

      assert {:error, {:already_decided, "approved"}} =
               Governance.approve(approval.id, "roberto", "again")
    end
  end

  describe "reject/3" do
    setup do
      rule = create_rule!(%{"action" => "require_approval"})
      sid = session_id()
      {:ok, approval} = Governance.request_approval(rule.id, sid)
      %{approval: approval, session_id: sid}
    end

    test "transitions approval to rejected", %{approval: approval} do
      assert {:ok, updated} = Governance.reject(approval.id, "roberto", "too risky")
      assert updated.status == "rejected"
      assert updated.decision_reason == "too risky"
    end

    test "writes approval_rejected audit entry", %{approval: approval, session_id: sid} do
      Governance.reject(approval.id, "roberto", "denied")
      audit = Governance.list_audit(event_type: "approval_rejected", session_id: sid)
      assert length(audit) >= 1
    end

    test "returns already_decided error if already rejected", %{approval: approval} do
      {:ok, _} = Governance.reject(approval.id, "roberto", "no")

      assert {:error, {:already_decided, "rejected"}} =
               Governance.reject(approval.id, "roberto", "no again")
    end
  end

  # ---------------------------------------------------------------------------
  # pending_approvals/0
  # ---------------------------------------------------------------------------

  describe "pending_approvals/0" do
    test "returns only pending approvals" do
      rule = create_rule!(%{"action" => "require_approval"})
      sid1 = session_id()
      sid2 = session_id()

      {:ok, a1} = Governance.request_approval(rule.id, sid1)
      {:ok, a2} = Governance.request_approval(rule.id, sid2)

      Governance.approve(a2.id, "roberto", "ok")

      pending = Governance.pending_approvals()
      pending_ids = Enum.map(pending, & &1.id)

      assert a1.id in pending_ids
      refute a2.id in pending_ids
    end
  end

  # ---------------------------------------------------------------------------
  # list_audit/1
  # ---------------------------------------------------------------------------

  describe "list_audit/1" do
    test "filters by event_type" do
      create_rule!(%{"action" => "block", "conditions" => %{"prompt_regex" => "destroy"}})
      Governance.evaluate(%{"prompt" => "destroy the world"})

      entries = Governance.list_audit(event_type: "session_blocked")
      assert Enum.all?(entries, &(&1.event_type == "session_blocked"))
    end

    test "filters by since datetime" do
      before_dt = DateTime.utc_now()
      Governance.evaluate(%{"prompt" => "hello"})

      entries = Governance.list_audit(since: before_dt)
      assert length(entries) >= 1
      assert Enum.all?(entries, &(DateTime.compare(&1.occurred_at, before_dt) in [:gt, :eq]))
    end

    test "audit log entries are never updated (append-only)" do
      Governance.evaluate(%{"prompt" => "test"})
      entries = Governance.list_audit()

      # AuditLog schema has no updated_at — verify struct doesn't have it
      entry = List.first(entries)
      refute Map.has_key?(entry, :updated_at)
    end
  end
end
