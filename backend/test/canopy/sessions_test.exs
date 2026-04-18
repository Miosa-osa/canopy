defmodule Canopy.SessionsTest do
  @moduledoc """
  Integration tests for the Canopy.Sessions context module.
  """

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Sessions

  defp valid_attrs(overrides \\ %{}) do
    Map.merge(%{runtime_type: "claude-local", cwd: "/tmp/project"}, overrides)
  end

  describe "create/1" do
    test "creates a session with required attrs" do
      assert {:ok, session} = Sessions.create(valid_attrs())
      assert session.id != nil
      assert session.status == "pending"
      assert session.runtime_type == "claude-local"
    end

    test "returns changeset error on missing required fields" do
      assert {:error, cs} = Sessions.create(%{})
      assert %{runtime_type: ["can't be blank"]} = errors_on(cs)
    end

    test "assigns optional fields" do
      attrs = valid_attrs(%{agent_slug: "senior-dev", model_id: "claude-sonnet-4-6"})
      {:ok, session} = Sessions.create(attrs)
      assert session.agent_slug == "senior-dev"
      assert session.model_id == "claude-sonnet-4-6"
    end
  end

  describe "get!/1" do
    test "returns session by id" do
      {:ok, created} = Sessions.create(valid_attrs())
      fetched = Sessions.get!(created.id)
      assert fetched.id == created.id
    end

    test "raises on missing id" do
      assert_raise Ecto.NoResultsError, fn ->
        Sessions.get!(Ecto.UUID.generate())
      end
    end
  end

  describe "list_by_status/1" do
    test "returns sessions matching the status" do
      {:ok, _s1} = Sessions.create(valid_attrs())
      {:ok, s2} = Sessions.create(valid_attrs())
      {:ok, running} = Sessions.update_status(s2.id, "running")

      {:ok, pending} = Sessions.list_by_status("pending")
      {:ok, running_list} = Sessions.list_by_status("running")

      assert Enum.any?(pending, &(&1.status == "pending"))
      assert Enum.any?(running_list, &(&1.id == running.id))
    end
  end

  describe "update_status/2" do
    test "transitions status" do
      {:ok, session} = Sessions.create(valid_attrs())
      {:ok, updated} = Sessions.update_status(session.id, "running")
      assert updated.status == "running"
    end

    test "returns error for invalid status" do
      {:ok, session} = Sessions.create(valid_attrs())
      assert {:error, cs} = Sessions.update_status(session.id, "invalid")
      assert %{status: [_msg]} = errors_on(cs)
    end

    test "returns error for unknown id" do
      assert {:error, :not_found} = Sessions.update_status(Ecto.UUID.generate(), "running")
    end
  end

  describe "add_message/2" do
    test "appends a message to the session" do
      {:ok, session} = Sessions.create(valid_attrs())

      msg_attrs = %{
        sequence: 0,
        kind: "assistant",
        content: %{"text" => "Hello!"},
        emitted_at: DateTime.utc_now()
      }

      assert {:ok, msg} = Sessions.add_message(session.id, msg_attrs)
      assert msg.session_id == session.id
      assert msg.sequence == 0
    end

    test "rejects duplicate sequence" do
      {:ok, session} = Sessions.create(valid_attrs())

      attrs = %{sequence: 0, kind: "user", content: %{}, emitted_at: DateTime.utc_now()}
      {:ok, _first_msg} = Sessions.add_message(session.id, attrs)
      {:error, cs} = Sessions.add_message(session.id, attrs)
      assert %{sequence: ["has already been taken"]} = errors_on(cs)
    end

    test "redacts credential-shaped content before persisting" do
      {:ok, session} = Sessions.create(valid_attrs())

      # Simulate a user accidentally pasting an API key into a prompt
      msg_attrs = %{
        sequence: 0,
        kind: "user",
        content: %{"text" => "Use this key: sk-abcdefghijklmnopqrstuv"},
        emitted_at: DateTime.utc_now()
      }

      assert {:ok, msg} = Sessions.add_message(session.id, msg_attrs)

      # The persisted content must NOT contain the raw key
      persisted_text = msg.content["text"]
      refute persisted_text =~ "sk-abcdefghijklmnopqrstuv"
      assert persisted_text =~ "***REDACTED"
    end

    test "benign message content is persisted unchanged" do
      {:ok, session} = Sessions.create(valid_attrs())

      attrs = %{
        sequence: 0,
        kind: "assistant",
        content: %{"text" => "The answer is 42."},
        emitted_at: DateTime.utc_now()
      }

      assert {:ok, msg} = Sessions.add_message(session.id, attrs)
      assert msg.content["text"] == "The answer is 42."
    end
  end

  describe "list_messages/1" do
    test "returns messages ordered by sequence" do
      {:ok, session} = Sessions.create(valid_attrs())
      now = DateTime.utc_now()

      for seq <- [2, 0, 1] do
        Sessions.add_message(session.id, %{
          sequence: seq,
          kind: "assistant",
          content: %{},
          emitted_at: now
        })
      end

      {:ok, msgs} = Sessions.list_messages(session.id)
      sequences = Enum.map(msgs, & &1.sequence)
      assert sequences == [0, 1, 2]
    end
  end

  describe "create/1 — resume injection" do
    test "injects external_session_id from prior completed session" do
      # Create first session and complete it with an external ID
      first_attrs = %{
        runtime_type: "claude-local",
        cwd: "/tmp/agent-project",
        agent_slug: "senior-dev",
        workspace_slug: "acme-corp"
      }

      {:ok, first_session} = Sessions.create(first_attrs)
      {:ok, completed} = Sessions.finalize(first_session.id, %{})

      # Persist the external_session_id (as the adapter would via add_message :result)
      {:ok, _} = Canopy.Sessions.Resume.persist(completed.id, "ext-claude-session-001")

      # Create second session for same agent+workspace+cwd
      second_attrs = %{
        runtime_type: "claude-local",
        cwd: "/tmp/agent-project",
        agent_slug: "senior-dev",
        workspace_slug: "acme-corp"
      }

      {:ok, second_session} = Sessions.create(second_attrs)
      assert second_session.external_session_id == "ext-claude-session-001"
    end

    test "does not inject external_session_id when no prior completed session" do
      attrs = %{
        runtime_type: "claude-local",
        cwd: "/tmp/fresh-project",
        agent_slug: "junior-dev",
        workspace_slug: "new-workspace"
      }

      {:ok, session} = Sessions.create(attrs)
      assert session.external_session_id == nil
    end

    test "does not inject when agent_slug is absent (direct prompt)" do
      attrs = %{runtime_type: "claude-local", cwd: "/tmp/direct"}
      {:ok, session} = Sessions.create(attrs)
      assert session.external_session_id == nil
    end
  end

  describe "add_message/2 — resume persistence on :result" do
    test "persists external_session_id when kind is result and content has session_id" do
      {:ok, session} = Sessions.create(valid_attrs())

      result_attrs = %{
        sequence: 0,
        kind: "result",
        content: %{"session_id" => "ext-claude-abc", "cost_usd" => 0.001},
        emitted_at: DateTime.utc_now()
      }

      {:ok, _msg} = Sessions.add_message(session.id, result_attrs)

      # Give the sync call a moment — Resume.persist is synchronous
      reloaded = Canopy.Repo.get!(Canopy.Sessions.Session, session.id)
      assert reloaded.external_session_id == "ext-claude-abc"
    end

    test "does not persist when kind is not result" do
      {:ok, session} = Sessions.create(valid_attrs())

      attrs = %{
        sequence: 0,
        kind: "assistant",
        content: %{"session_id" => "should-not-persist"},
        emitted_at: DateTime.utc_now()
      }

      {:ok, _msg} = Sessions.add_message(session.id, attrs)

      reloaded = Canopy.Repo.get!(Canopy.Sessions.Session, session.id)
      assert reloaded.external_session_id == nil
    end

    test "does not persist when result content lacks session_id" do
      {:ok, session} = Sessions.create(valid_attrs())

      attrs = %{
        sequence: 0,
        kind: "result",
        content: %{"cost_usd" => 0.001},
        emitted_at: DateTime.utc_now()
      }

      {:ok, _msg} = Sessions.add_message(session.id, attrs)

      reloaded = Canopy.Repo.get!(Canopy.Sessions.Session, session.id)
      assert reloaded.external_session_id == nil
    end

    test "returns message insert result regardless of resume persist outcome" do
      {:ok, session} = Sessions.create(valid_attrs())

      attrs = %{
        sequence: 0,
        kind: "result",
        content: %{"session_id" => "ext-123"},
        emitted_at: DateTime.utc_now()
      }

      # Must still return {:ok, message} even with resume side-effect
      assert {:ok, msg} = Sessions.add_message(session.id, attrs)
      assert msg.session_id == session.id
    end
  end

  describe "finalize/2" do
    test "sets status to completed and records completed_at" do
      {:ok, session} = Sessions.create(valid_attrs())
      {:ok, updated} = Sessions.update_status(session.id, "running")

      cost = Decimal.new("0.001234")
      {:ok, final} = Sessions.finalize(updated.id, %{cost_usd: cost, input_tokens: 100})

      assert final.status == "completed"
      assert final.completed_at != nil
      assert Decimal.equal?(final.cost_usd, cost)
      assert final.input_tokens == 100
    end

    test "returns error for unknown session" do
      assert {:error, :not_found} = Sessions.finalize(Ecto.UUID.generate(), %{})
    end
  end

  # ---------------------------------------------------------------------------
  # Governance + budget gate tests
  # ---------------------------------------------------------------------------

  describe "create/1 gates" do
    test "governance :pass proceeds and creates session" do
      # No rules in DB → evaluate/1 returns :pass
      assert {:ok, session} = Sessions.create(valid_attrs())
      assert session.status == "pending"
    end

    test "governance :block returns {:error, {:governance_blocked, rule}}" do
      # Evaluator condition key for runtime_type is "runtime"
      rule =
        insert(:governance_rule,
          enabled: true,
          priority: 100,
          action: "block",
          conditions: %{"runtime" => "claude-local"}
        )

      result = Sessions.create(valid_attrs(%{runtime_type: "claude-local"}))
      assert {:error, {:governance_blocked, blocked_rule}} = result
      assert blocked_rule.id == rule.id
    end

    test "governance :warn logs and proceeds to insert" do
      insert(:governance_rule,
        enabled: true,
        priority: 100,
        action: "warn",
        conditions: %{"runtime" => "claude-local"}
      )

      assert {:ok, session} = Sessions.create(valid_attrs())
      assert session.status == "pending"
    end

    test "governance :require_approval inserts with status pending_approval" do
      rule =
        insert(:governance_rule,
          enabled: true,
          priority: 100,
          action: "require_approval",
          conditions: %{"runtime" => "claude-local"}
        )

      assert {:ok, session} = Sessions.create(valid_attrs())
      assert session.status == "pending_approval"
      assert session.metadata["governance_rule_id"] == rule.id
    end

    test "governance :require_approval creates an approval record" do
      insert(:governance_rule,
        enabled: true,
        priority: 100,
        action: "require_approval",
        conditions: %{"runtime" => "claude-local"}
      )

      assert {:ok, session} = Sessions.create(valid_attrs())

      approvals = Canopy.Governance.pending_approvals()
      assert Enum.any?(approvals, &(&1.session_id == session.id))
    end

    test "budget :block returns {:error, {:budget_blocked, budget, spent}}" do
      # Budget.changeset requires limit_usd > 0; use $0.001 with spend > limit
      budget =
        insert(:budget,
          scope_type: "global",
          scope_id: nil,
          period: "total",
          limit_usd: Decimal.new("0.001"),
          soft_alert_pct: 80,
          hard_ceiling: true,
          enabled: true
        )

      # Completed session with cost_usd > limit — pushes total spend over ceiling
      completed = insert(:completed_session, cost_usd: Decimal.new("0.01"))

      Canopy.Repo.update_all(
        from(s in Canopy.Sessions.Session, where: s.id == ^completed.id),
        set: [status: "completed", completed_at: DateTime.utc_now()]
      )

      result = Sessions.create(valid_attrs())
      assert {:error, {:budget_blocked, blocked_budget, _spent}} = result
      assert blocked_budget.id == budget.id
    end

    test "budget :warn logs and proceeds to insert" do
      # hard_ceiling=false → warn only even when limit exceeded
      insert(:budget,
        scope_type: "global",
        scope_id: nil,
        period: "total",
        limit_usd: Decimal.new("0.001"),
        soft_alert_pct: 80,
        hard_ceiling: false,
        enabled: true
      )

      completed = insert(:completed_session, cost_usd: Decimal.new("0.01"))

      Canopy.Repo.update_all(
        from(s in Canopy.Sessions.Session, where: s.id == ^completed.id),
        set: [status: "completed", completed_at: DateTime.utc_now()]
      )

      assert {:ok, session} = Sessions.create(valid_attrs())
      assert session.status == "pending"
    end

    test "combined: governance pass + budget block → budget wins" do
      # No governance rules → evaluate/1 returns :pass
      budget =
        insert(:budget,
          scope_type: "global",
          scope_id: nil,
          period: "total",
          limit_usd: Decimal.new("0.001"),
          hard_ceiling: true,
          enabled: true
        )

      completed = insert(:completed_session, cost_usd: Decimal.new("1.00"))

      Canopy.Repo.update_all(
        from(s in Canopy.Sessions.Session, where: s.id == ^completed.id),
        set: [status: "completed", completed_at: DateTime.utc_now()]
      )

      result = Sessions.create(valid_attrs())
      assert {:error, {:budget_blocked, blocked_budget, _spent}} = result
      assert blocked_budget.id == budget.id
    end
  end
end
