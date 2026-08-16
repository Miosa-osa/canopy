defmodule Canopy.Tasks.DispatcherTest do
  @moduledoc """
  Integration tests for Canopy.Tasks.Dispatcher.

  Uses the Ecto sandbox — no mocking. The PtyBridge is not started in the test
  environment, so "pty alive" checks always return false for freshly inserted
  sessions. Tests verify the DB-side effects (task status, session_id, dispatched_at)
  and the error paths.
  """

  use Canopy.DataCase, async: false

  import Canopy.Factory

  alias Canopy.Tasks
  alias Canopy.Tasks.Dispatcher

  # ---------------------------------------------------------------------------
  # dispatch/2 — task not found
  # ---------------------------------------------------------------------------

  describe "dispatch/2 with unknown short_id" do
    test "returns {:error, :not_found}" do
      assert {:error, :not_found} = Dispatcher.dispatch("T-99999999")
    end
  end

  # ---------------------------------------------------------------------------
  # dispatch/2 — no target
  # ---------------------------------------------------------------------------

  describe "dispatch/2 with no assignee" do
    test "returns {:error, :no_target} when task has no assignee and no session_id" do
      task = insert(:task, assignee_type: nil, assignee_id: nil)
      assert {:error, :no_target} = Dispatcher.dispatch(task.short_id)
    end

    test "returns {:error, :no_target} when assignee_type is 'user' (not an agent)" do
      task = insert(:task, assignee_type: "user", assignee_id: Ecto.UUID.generate())
      assert {:error, :no_target} = Dispatcher.dispatch(task.short_id)
    end

    test "returns {:error, :no_target} when agent slug does not exist" do
      task = insert(:task, assignee_type: "agent", assignee_id: "nonexistent-agent")
      assert {:error, :no_target} = Dispatcher.dispatch(task.short_id)
    end
  end

  # ---------------------------------------------------------------------------
  # dispatch/2 — agent assignee, no running session (spawns new session)
  # ---------------------------------------------------------------------------

  describe "dispatch/2 with agent assignee and no running session" do
    test "creates a new session, updates task.session_id, marks task in_progress" do
      agent =
        insert(:agent,
          hired: true,
          slug: "test-dispatch-agent-1",
          default_runtime: "claude-local"
        )

      task = insert(:task, assignee_type: "agent", assignee_id: agent.slug, status: "todo")

      assert {:ok, %{session_id: session_id, task: updated_task}} =
               Dispatcher.dispatch(task.short_id)

      # session_id is a valid UUID
      assert is_binary(session_id)
      assert {:ok, _} = Ecto.UUID.cast(session_id)

      # task updated in DB
      {:ok, reloaded} = Tasks.get(task.short_id)
      assert reloaded.status == "in_progress"
      assert reloaded.session_id == session_id
      assert %DateTime{} = reloaded.dispatched_at

      # returned task struct reflects updates
      assert updated_task.session_id == session_id
      assert updated_task.status == "in_progress"
    end

    test "does not override status if task is already in_progress" do
      agent =
        insert(:agent,
          hired: true,
          slug: "test-dispatch-agent-2",
          default_runtime: "claude-local"
        )

      task = insert(:task, assignee_type: "agent", assignee_id: agent.slug, status: "in_progress")

      assert {:ok, %{task: updated_task}} = Dispatcher.dispatch(task.short_id)
      assert updated_task.status == "in_progress"
    end

    test "uses override agent_slug when provided" do
      _default_agent =
        insert(:agent, hired: true, slug: "default-agent-1", default_runtime: "claude-local")

      override_agent =
        insert(:agent, hired: true, slug: "override-agent-1", default_runtime: "claude-local")

      task = insert(:task, assignee_type: "agent", assignee_id: "default-agent-1", status: "todo")

      assert {:ok, %{session_id: session_id}} =
               Dispatcher.dispatch(task.short_id, agent_slug: override_agent.slug)

      # Verify the session was created with the override agent
      session = Canopy.Repo.get!(Canopy.Sessions.Session, session_id)
      assert session.agent_slug == override_agent.slug
    end
  end

  # ---------------------------------------------------------------------------
  # dispatch/2 — task already bound to a session_id but pty is not alive
  # ---------------------------------------------------------------------------

  describe "dispatch/2 with task.session_id set but pty dead" do
    test "falls back to agent resolution when pty is dead" do
      agent =
        insert(:agent,
          hired: true,
          slug: "test-dispatch-agent-3",
          default_runtime: "claude-local"
        )

      existing_session = insert(:session, agent_slug: agent.slug, status: "completed")

      task =
        insert(:task,
          assignee_type: "agent",
          assignee_id: agent.slug,
          session_id: existing_session.id,
          status: "todo"
        )

      # PtyBridge is NOT running for this session in tests — pty_alive? returns false.
      # The dispatcher should fall through to agent resolution and spawn a new session.
      assert {:ok, %{session_id: new_session_id}} = Dispatcher.dispatch(task.short_id)

      # Must have gotten a different session (existing one has dead pty)
      assert new_session_id != existing_session.id
    end
  end

  # ---------------------------------------------------------------------------
  # dispatch/2 — accepts Task struct directly
  # ---------------------------------------------------------------------------

  describe "dispatch/2 with Task struct" do
    test "accepts a Task struct instead of a short_id string" do
      agent =
        insert(:agent,
          hired: true,
          slug: "test-dispatch-agent-4",
          default_runtime: "claude-local"
        )

      task = insert(:task, assignee_type: "agent", assignee_id: agent.slug)

      assert {:ok, %{session_id: session_id, task: _}} = Dispatcher.dispatch(task)
      assert is_binary(session_id)
    end
  end

  # ---------------------------------------------------------------------------
  # dispatch/2 — CLI runtimes succeed without stored credentials
  # ---------------------------------------------------------------------------

  describe "dispatch/2 with CLI runtime (degrades gracefully)" do
    test "claude-local succeeds without a stored credential — CLI manages its own auth" do
      # Auth.session_env_for always returns {:ok, %{}} for CLI runtimes when no credential
      # is stored in Canopy. The agent CLI binary handles its own token storage.
      agent =
        insert(:agent,
          hired: true,
          slug: "test-dispatch-agent-5",
          default_runtime: "claude-local"
        )

      task = insert(:task, assignee_type: "agent", assignee_id: agent.slug)

      assert {:ok, %{session_id: session_id}} = Dispatcher.dispatch(task.short_id)
      assert is_binary(session_id)
    end

    test "spawned session has correct runtime_type from agent.default_runtime" do
      agent =
        insert(:agent,
          hired: true,
          slug: "test-dispatch-agent-6",
          default_runtime: "codex-local"
        )

      task = insert(:task, assignee_type: "agent", assignee_id: agent.slug)

      assert {:ok, %{session_id: session_id}} = Dispatcher.dispatch(task.short_id)
      session = Canopy.Repo.get!(Canopy.Sessions.Session, session_id)
      assert session.runtime_type == "codex-local"
    end
  end
end
