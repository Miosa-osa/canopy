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
  alias Canopy.Runtimes.{Runtime, RuntimeModel}
  alias Canopy.Sessions.{Session, SessionMessage}
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
end
