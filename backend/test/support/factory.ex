defmodule Canopy.Factory do
  @moduledoc """
  ExMachina factory for test data.

  Usage in tests:

      use Canopy.DataCase
      import Canopy.Factory

      session = insert(:session)
      agent = insert(:agent, hired: true)
  """

  use ExMachina.Ecto, repo: Canopy.Repo

  alias Canopy.Agents.Agent
  alias Canopy.Budgets.{Budget, SpendSnapshot}
  alias Canopy.Governance.{Approval, Rule}
  alias Canopy.Runtimes.{Runtime, RuntimeModel}
  alias Canopy.Sessions.{Session, SessionMessage}
  alias Canopy.Skills.Skill
  alias Canopy.Workspaces.Workspace

  def runtime_factory do
    %Runtime{
      type: sequence(:type, &"runtime-type-#{&1}"),
      kind: "cli",
      name: sequence(:name, &"Runtime #{&1}"),
      enabled: true,
      installed: true,
      version: "1.0.0",
      binary_path: "/usr/local/bin/runtime",
      config: %{},
      capabilities: ["session_resume"]
    }
  end

  def runtime_model_factory do
    %RuntimeModel{
      runtime: build(:runtime),
      model_id: sequence(:model_id, &"model-#{&1}"),
      display_name: "Test Model",
      context_window: 200_000,
      input_cost_per_mtok: Decimal.new("3.0"),
      output_cost_per_mtok: Decimal.new("15.0"),
      supports_thinking: false,
      supports_tools: true,
      supports_vision: false,
      is_default: false
    }
  end

  def workspace_factory do
    %Workspace{
      slug: sequence(:slug, &"workspace-#{&1}"),
      name: sequence(:name, &"Workspace #{&1}"),
      root_path: sequence(:root_path, &"/tmp/workspace-#{&1}"),
      template: nil
    }
  end

  def agent_factory do
    slug = sequence(:slug, &"agent-#{&1}")

    %Agent{
      slug: slug,
      category: "engineering",
      name: sequence(:name, &"Agent #{&1}"),
      persona_path: "engineering/#{slug}.md",
      hired: false
    }
  end

  def session_factory do
    %Session{
      runtime_type: "claude-local",
      cwd: "/tmp/project",
      status: "pending",
      sequence_number: 0,
      cost_usd: Decimal.new("0"),
      input_tokens: 0,
      output_tokens: 0,
      cache_read_tokens: 0,
      cache_write_tokens: 0,
      metadata: %{}
    }
  end

  def running_session_factory do
    build(:session, status: "running", started_at: DateTime.utc_now())
  end

  def completed_session_factory do
    build(:session,
      status: "completed",
      started_at: DateTime.add(DateTime.utc_now(), -60),
      completed_at: DateTime.utc_now(),
      cost_usd: Decimal.new("0.001"),
      input_tokens: 1000,
      output_tokens: 500
    )
  end

  def session_message_factory do
    %SessionMessage{
      session: build(:session),
      sequence: 0,
      kind: "assistant",
      content: %{"text" => "Hello from the assistant"},
      emitted_at: DateTime.utc_now()
    }
  end

  def tool_call_message_factory do
    build(:session_message,
      kind: "tool_call",
      content: %{"tool" => "bash", "args" => ["ls", "-la"]},
      tool_call_id: sequence(:tool_call_id, &"call-#{&1}")
    )
  end

  def budget_factory do
    %Budget{
      scope_type: "global",
      scope_id: nil,
      period: "monthly",
      limit_usd: Decimal.new("100.00"),
      soft_alert_pct: 80,
      hard_ceiling: true,
      enabled: true
    }
  end

  def spend_snapshot_factory do
    now = DateTime.utc_now()

    %SpendSnapshot{
      budget: build(:budget),
      period_start: %{now | day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}},
      period_end: DateTime.add(now, 30, :day),
      actual_spend_usd: Decimal.new("0.00"),
      session_count: 0,
      snapshot_at: now,
      inserted_at: now
    }
  end

  def governance_rule_factory do
    %Rule{
      name: sequence(:name, &"governance-rule-#{&1}"),
      description: "Test governance rule",
      enabled: true,
      priority: 0,
      conditions: %{},
      action: "log",
      audit_context: %{}
    }
  end

  def governance_approval_factory do
    %Approval{
      rule: build(:governance_rule),
      session_id: Ecto.UUID.generate(),
      status: "pending",
      requested_at: DateTime.utc_now()
    }
  end

  def skill_factory do
    content = sequence(:content, &"# Skill #{&1}\n\nDo the thing.")

    %Skill{
      slug: sequence(:slug, &"skill-#{&1}"),
      name: sequence(:name, &"Skill #{&1}"),
      description: "A test skill",
      provider_format: "generic",
      content: content,
      content_hash: :crypto.hash(:sha256, content) |> Base.encode16(case: :lower),
      source: "local",
      tags: [],
      enabled: true
    }
  end
end
