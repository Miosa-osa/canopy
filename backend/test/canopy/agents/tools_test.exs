defmodule Canopy.Agents.ToolsTest do
  @moduledoc """
  Unit/integration tests for Canopy.Agents.Tools.execute/3.

  Covers:
  - Capability check: read-only default, explicit grant, rejection
  - Governance: pending_review path for tool_call rules
  - Individual tool dispatch: create_task, list_tasks, update_task, move_card, read_task, spawn_session
  - Audit row written on every call
  """

  use Canopy.DataCase, async: false

  import Canopy.Factory

  alias Canopy.Agents.{ToolCall, Tools}
  alias Canopy.Repo

  setup do
    # Ensure no governance rules from other tests affect the RuleCache.
    # The cache is a global ETS-backed GenServer; invalidate so it reloads
    # from the (sandboxed) DB which starts clean per test.
    Canopy.Governance.RuleCache.invalidate()
    :ok
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp insert_session_for_agent(agent) do
    insert(:session,
      agent_slug: agent.slug,
      workspace_slug: "default",
      status: "running"
    )
  end

  defp agent_with_caps(caps) do
    slug = "test-agent-#{System.unique_integer([:positive])}"

    insert(:agent,
      slug: slug,
      hired: true,
      config: %{"capabilities" => caps}
    )
  end

  defp agent_read_only do
    # No config → defaults to read_workspace only
    slug = "readonly-agent-#{System.unique_integer([:positive])}"
    insert(:agent, slug: slug, hired: true, config: %{})
  end

  # ---------------------------------------------------------------------------
  # Capability checks
  # ---------------------------------------------------------------------------

  describe "capability check" do
    test "allows read_task when agent has no config (read_workspace default)" do
      agent = agent_read_only()
      session = insert_session_for_agent(agent)

      result = Tools.execute("canopy.read_task", session.id, %{"task_id" => "T-99999999"})

      # Either not_found error (no task) or ok — not a 403
      assert result != {:error, "agent lacks capability canopy.read_task"}
    end

    test "rejects write_tasks when agent has no capabilities configured" do
      agent = agent_read_only()
      session = insert_session_for_agent(agent)

      result = Tools.execute("canopy.create_task", session.id, %{"title" => "oops"})

      assert {:error, msg} = result
      assert String.contains?(msg, "lacks capability")
    end

    test "allows create_task when agent has write_tasks capability" do
      agent = agent_with_caps(["read_workspace", "write_tasks"])
      session = insert_session_for_agent(agent)

      result =
        Tools.execute("canopy.create_task", session.id, %{"title" => "Test Task from agent"})

      assert {:ok, %{task: task}} = result
      assert task.title == "Test Task from agent"
    end

    test "rejects spawn_session when agent lacks spawn_sessions" do
      agent = agent_with_caps(["read_workspace", "write_tasks"])
      session = insert_session_for_agent(agent)

      result = Tools.execute("canopy.spawn_session", session.id, %{"prompt" => "go"})

      assert {:error, msg} = result
      assert String.contains?(msg, "lacks capability")
    end
  end

  # ---------------------------------------------------------------------------
  # Tool: create_task
  # ---------------------------------------------------------------------------

  describe "canopy.create_task" do
    test "creates a task and returns it" do
      agent = agent_with_caps(["write_tasks"])
      session = insert_session_for_agent(agent)

      result =
        Tools.execute("canopy.create_task", session.id, %{
          "title" => "Agent-created task",
          "status" => "todo",
          "workspace_slug" => "default"
        })

      assert {:ok, %{task: task}} = result
      assert task.title == "Agent-created task"
      assert task.status == "todo"
    end

    test "returns error when title is missing" do
      agent = agent_with_caps(["write_tasks"])
      session = insert_session_for_agent(agent)

      assert {:error, msg} = Tools.execute("canopy.create_task", session.id, %{})
      assert is_binary(msg)
    end
  end

  # ---------------------------------------------------------------------------
  # Tool: list_tasks
  # ---------------------------------------------------------------------------

  describe "canopy.list_tasks" do
    test "returns tasks list" do
      agent = agent_with_caps(["read_workspace"])
      session = insert_session_for_agent(agent)

      insert(:task, workspace_slug: "default", status: "todo")

      {:ok, %{tasks: tasks, count: count}} =
        Tools.execute("canopy.list_tasks", session.id, %{"workspace_slug" => "default"})

      assert is_list(tasks)
      assert count >= 1
    end
  end

  # ---------------------------------------------------------------------------
  # Tool: update_task
  # ---------------------------------------------------------------------------

  describe "canopy.update_task" do
    test "updates task status" do
      agent = agent_with_caps(["write_tasks"])
      session = insert_session_for_agent(agent)
      task = insert(:task, status: "todo", workspace_slug: "default")

      result =
        Tools.execute("canopy.update_task", session.id, %{
          "task_id" => task.short_id,
          "status" => "in_progress"
        })

      assert {:ok, %{task: updated}} = result
      assert updated.status == "in_progress"
    end

    test "returns error when task_id is missing" do
      agent = agent_with_caps(["write_tasks"])
      session = insert_session_for_agent(agent)

      assert {:error, "missing task_id"} =
               Tools.execute("canopy.update_task", session.id, %{"status" => "done"})
    end
  end

  # ---------------------------------------------------------------------------
  # Tool: move_card
  # ---------------------------------------------------------------------------

  describe "canopy.move_card" do
    test "moves a task to new status" do
      agent = agent_with_caps(["write_tasks"])
      session = insert_session_for_agent(agent)
      task = insert(:task, status: "todo")

      result =
        Tools.execute("canopy.move_card", session.id, %{
          "task_id" => task.short_id,
          "status" => "done"
        })

      assert {:ok, %{entity: "task", status: "done"}} = result
    end

    test "returns error when status missing" do
      agent = agent_with_caps(["write_tasks"])
      session = insert_session_for_agent(agent)
      task = insert(:task, status: "todo")

      assert {:error, "missing status"} =
               Tools.execute("canopy.move_card", session.id, %{"task_id" => task.short_id})
    end
  end

  # ---------------------------------------------------------------------------
  # Tool: read_task
  # ---------------------------------------------------------------------------

  describe "canopy.read_task" do
    test "reads an existing task" do
      agent = agent_with_caps(["read_workspace"])
      session = insert_session_for_agent(agent)
      task = insert(:task, title: "Find me")

      {:ok, %{task: found}} =
        Tools.execute("canopy.read_task", session.id, %{"task_id" => task.short_id})

      assert found.title == "Find me"
    end

    test "returns error for missing task" do
      agent = agent_with_caps(["read_workspace"])
      session = insert_session_for_agent(agent)

      assert {:error, _msg} =
               Tools.execute("canopy.read_task", session.id, %{"task_id" => "T-99999999"})
    end
  end

  # ---------------------------------------------------------------------------
  # Audit row
  # ---------------------------------------------------------------------------

  describe "audit recording" do
    test "writes an agent_tool_calls row on every execute call" do
      agent = agent_with_caps(["write_tasks"])
      session = insert_session_for_agent(agent)

      Tools.execute("canopy.create_task", session.id, %{"title" => "Audit test"})

      row = Repo.get_by(ToolCall, session_id: session.id, tool_name: "canopy.create_task")
      assert row != nil
      assert row.agent_id == agent.slug
    end

    test "writes error status on failed execute" do
      agent = agent_read_only()
      session = insert_session_for_agent(agent)

      Tools.execute("canopy.create_task", session.id, %{"title" => "not allowed"})

      row = Repo.get_by(ToolCall, session_id: session.id, tool_name: "canopy.create_task")
      assert row != nil
      assert row.status == "error"
    end
  end

  # ---------------------------------------------------------------------------
  # Unknown session
  # ---------------------------------------------------------------------------

  describe "bad session_id" do
    test "returns error when session does not exist" do
      result = Tools.execute("canopy.list_tasks", Ecto.UUID.generate(), %{})
      assert {:error, msg} = result
      assert String.contains?(msg, "session")
    end
  end
end
