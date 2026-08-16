defmodule Canopy.Tasks.ApplyVerbTest do
  @moduledoc """
  Integration tests for Canopy.Tasks.apply_verb/3.

  All 6 verb paths: start/build, pause, resume, stop/cancel, done, noop.
  No pty is running in tests — PtyBridge calls are no-ops (Registry returns []).
  """

  use Canopy.DataCase, async: false

  import Canopy.Factory

  alias Canopy.Tasks
  alias Canopy.Sessions

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp unique_slug, do: "av-agent-#{:rand.uniform(999_999)}"

  defp task_with_agent(opts \\ []) do
    slug = unique_slug()

    agent =
      insert(:agent,
        hired: true,
        slug: slug,
        default_runtime: "claude-local"
      )

    insert(:task, Keyword.merge([assignee_type: "agent", assignee_id: agent.slug], opts))
  end

  defp task_with_session(status) do
    session = insert(:session, status: status)
    insert(:task, status: "in_progress", session_id: session.id)
  end

  # ---------------------------------------------------------------------------
  # "start" / "build"
  # ---------------------------------------------------------------------------

  describe "apply_verb/3 — start" do
    test "dispatches task to agent, returns session_id" do
      task = task_with_agent(status: "todo")
      assert {:ok, updated, session_id} = Tasks.apply_verb(task, "start")
      assert updated.status == "in_progress"
      assert is_binary(session_id)
    end

    test "build alias behaves identically to start" do
      task = task_with_agent(status: "todo")
      assert {:ok, _updated, session_id} = Tasks.apply_verb(task, "build")
      assert is_binary(session_id)
    end

    test "returns {:error, :no_target} when task has no agent" do
      task = insert(:task, assignee_type: nil, assignee_id: nil)
      assert {:error, :no_target} = Tasks.apply_verb(task, "start")
    end

    test "accepts short_id string instead of struct" do
      task = task_with_agent()
      assert {:ok, _updated, session_id} = Tasks.apply_verb(task.short_id, "start")
      assert is_binary(session_id)
    end
  end

  # ---------------------------------------------------------------------------
  # "pause"
  # ---------------------------------------------------------------------------

  describe "apply_verb/3 — pause" do
    test "returns task unchanged when no session_id" do
      task = insert(:task, status: "todo", session_id: nil)
      assert {:ok, updated, nil} = Tasks.apply_verb(task, "pause", "in_progress")
      assert updated.status == "in_progress"
    end

    test "pauses session DB record when session exists" do
      task = task_with_session("running")
      assert {:ok, _updated, _session_id} = Tasks.apply_verb(task, "pause")
      {:ok, session} = Sessions.get(task.session_id)
      assert session.status == "paused"
    end

    test "updates task status when target_status provided" do
      task = insert(:task, status: "todo")
      assert {:ok, updated, _} = Tasks.apply_verb(task, "pause", "in_progress")
      assert updated.status == "in_progress"
    end
  end

  # ---------------------------------------------------------------------------
  # "resume"
  # ---------------------------------------------------------------------------

  describe "apply_verb/3 — resume" do
    test "resumes session DB record" do
      task = task_with_session("paused")
      assert {:ok, _updated, _session_id} = Tasks.apply_verb(task, "resume")
      {:ok, session} = Sessions.get(task.session_id)
      assert session.status == "running"
    end

    test "no-ops cleanly when task has no session_id" do
      task = insert(:task, status: "todo", session_id: nil)
      assert {:ok, _updated, nil} = Tasks.apply_verb(task, "resume")
    end
  end

  # ---------------------------------------------------------------------------
  # "stop" / "cancel"
  # ---------------------------------------------------------------------------

  describe "apply_verb/3 — stop" do
    test "sets task status to todo and clears session_id" do
      task = task_with_session("running")
      assert {:ok, updated, nil} = Tasks.apply_verb(task, "stop")
      assert updated.status == "todo"
      assert updated.session_id == nil
    end

    test "cancel alias behaves identically to stop" do
      task = task_with_session("running")
      assert {:ok, updated, nil} = Tasks.apply_verb(task, "cancel")
      assert updated.status == "todo"
    end

    test "session is marked cancelled" do
      task = task_with_session("running")
      session_id = task.session_id
      Tasks.apply_verb(task, "stop")
      {:ok, session} = Sessions.get(session_id)
      assert session.status == "cancelled"
    end
  end

  # ---------------------------------------------------------------------------
  # "done"
  # ---------------------------------------------------------------------------

  describe "apply_verb/3 — done" do
    test "marks task done with completed_at" do
      task = insert(:task, status: "in_progress")
      assert {:ok, updated, nil} = Tasks.apply_verb(task, "done")
      assert updated.status == "done"
      assert %DateTime{} = updated.completed_at
    end

    test "stops session when present" do
      task = task_with_session("running")
      session_id = task.session_id
      Tasks.apply_verb(task, "done")
      {:ok, session} = Sessions.get(session_id)
      assert session.status == "cancelled"
    end
  end

  # ---------------------------------------------------------------------------
  # "noop"
  # ---------------------------------------------------------------------------

  describe "apply_verb/3 — noop" do
    test "updates task status without touching pty" do
      task = insert(:task, status: "todo")
      assert {:ok, updated, nil} = Tasks.apply_verb(task, "noop", "in_progress")
      assert updated.status == "in_progress"
    end

    test "preserves existing session_id" do
      task = task_with_session("running")
      assert {:ok, updated, returned_session_id} = Tasks.apply_verb(task, "noop")
      assert updated.session_id == task.session_id
      assert returned_session_id == task.session_id
    end

    test "unknown verbs fall through as noop" do
      task = insert(:task, status: "todo")
      assert {:ok, _updated, _} = Tasks.apply_verb(task, "unknown_verb")
    end
  end

  # ---------------------------------------------------------------------------
  # not_found
  # ---------------------------------------------------------------------------

  describe "apply_verb/3 — not found" do
    test "returns {:error, :not_found} for unknown short_id" do
      assert {:error, :not_found} = Tasks.apply_verb("T-00000000", "noop")
    end
  end
end
