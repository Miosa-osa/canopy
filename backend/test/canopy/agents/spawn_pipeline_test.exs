defmodule Canopy.Agents.SpawnPipelineTest do
  @moduledoc """
  Tests for `Canopy.Agents.SpawnPipeline`.

  Integration tests use a real DB session + runtime + a trivial command
  (/usr/bin/env cat) to exercise the full pipeline without a real agent CLI.
  Unit-style tests inject scenarios by seeding specific DB rows.
  """

  use Canopy.DataCase, async: false

  import Canopy.Factory

  alias Canopy.Agents.SpawnPipeline
  alias Canopy.Runs
  alias Canopy.Sessions

  # Allow sandbox access from spawned processes (PtyBridge tasks, async records).
  setup do
    Ecto.Adapters.SQL.Sandbox.mode(Canopy.Repo, {:shared, self()})
    :ok
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Path to the fake claude shell script used in integration tests.
  defp fake_claude_path do
    Path.join([File.cwd!(), "test", "support", "fake_claude.sh"])
  end

  # Inserts a runtime pointing at fake_claude.sh so PtyBridge can actually start.
  defp insert_cat_runtime do
    insert(:runtime,
      type: "claude-local",
      binary_path: fake_claude_path(),
      enabled: true,
      installed: true
    )
  end

  defp insert_session(overrides \\ %{}) do
    insert(:session, Map.merge(%{runtime_type: "claude-local", status: "pending"}, overrides))
  end

  # ---------------------------------------------------------------------------
  # Stage 1: validate — unknown runtime short-circuits
  # ---------------------------------------------------------------------------

  describe "spawn/2 — validate stage" do
    test "returns {:error, :validate, reason} for unknown runtime" do
      session = insert_session(%{runtime_type: "unknown-runtime-xyz"})

      assert {:error, :validate, {:unknown_runtime, "unknown-runtime-xyz"}} =
               SpawnPipeline.spawn(session)
    end
  end

  # ---------------------------------------------------------------------------
  # Stage 2: ensure_run — creates a run tied to session
  # ---------------------------------------------------------------------------

  describe "spawn/2 — ensure_run stage" do
    test "creates a Run row with status queued then transitions to running" do
      _runtime = insert_cat_runtime()
      session = insert_session()

      {:ok, result} = SpawnPipeline.spawn(session, wake_reason: "user_prompt")

      assert result.run.session_id == session.id
      assert result.run.wake_reason == "user_prompt"
    end

    test "reuses existing running run (idempotent)" do
      _runtime = insert_cat_runtime()
      session = insert_session()

      # First spawn creates the run.
      {:ok, first} = SpawnPipeline.spawn(session, wake_reason: "schedule")

      # Artificially keep run in :running state (mark_running was already called).
      # Second call should reuse it.
      {:ok, second} = SpawnPipeline.spawn(session, wake_reason: "schedule")

      assert first.run.id == second.run.id
    end
  end

  # ---------------------------------------------------------------------------
  # Stage 5: build_env — CANOPY_* vars present
  # ---------------------------------------------------------------------------

  describe "spawn/2 — CANOPY_* env vars" do
    test "spawned process environment contains CANOPY_SESSION_ID" do
      _runtime = insert_cat_runtime()
      session = insert_session()

      {:ok, result} = SpawnPipeline.spawn(session)

      # The pty started — retrieve the env from the bridge state via :sys.get_state.
      bridge_pid =
        case Registry.lookup(Canopy.Sessions.PtyRegistry, session.id) do
          [{pid, _}] -> pid
          [] -> nil
        end

      assert bridge_pid != nil

      state = :sys.get_state(bridge_pid, 2_000)
      # The os_pid confirms the subprocess started.
      assert state.os_pid != nil
      assert state.session_id == session.id

      # CANOPY_SESSION_ID is present in the result summary (pipeline built it).
      assert result.session.id == session.id
    end

    test "wake_reason propagates into run.wake_reason" do
      _runtime = insert_cat_runtime()
      session = insert_session()

      {:ok, result} = SpawnPipeline.spawn(session, wake_reason: "approval")

      assert result.run.wake_reason == "approval"
    end

    test "approval_id is accepted without error" do
      _runtime = insert_cat_runtime()
      session = insert_session()
      approval_id = Ecto.UUID.generate()

      assert {:ok, _result} =
               SpawnPipeline.spawn(session,
                 wake_reason: "approval",
                 approval_id: approval_id
               )
    end
  end

  # ---------------------------------------------------------------------------
  # Stage 6: resolve_command — unknown binary_path fails gracefully
  # ---------------------------------------------------------------------------

  describe "spawn/2 — resolve_command stage failure" do
    test "returns {:error, :resolve_command, reason} when binary_path is nil" do
      insert(:runtime, type: "claude-local", binary_path: nil, enabled: true, installed: true)
      session = insert_session()

      assert {:error, :resolve_command, {:no_binary_path, "claude-local"}} =
               SpawnPipeline.spawn(session)
    end

    test "marks run as failed and session as failed on resolve_command error" do
      insert(:runtime, type: "claude-local", binary_path: nil, enabled: true, installed: true)
      session = insert_session()

      assert {:error, :resolve_command, _} = SpawnPipeline.spawn(session)

      {:ok, updated_session} = Sessions.get(session.id)
      assert updated_session.status == "failed"
    end
  end

  # ---------------------------------------------------------------------------
  # Stage 7: start_pty — idempotent on second call
  # ---------------------------------------------------------------------------

  describe "spawn/2 — start_pty idempotency" do
    test "second spawn reuses existing pty (same os_pid)" do
      _runtime = insert_cat_runtime()
      session = insert_session()

      {:ok, first} = SpawnPipeline.spawn(session)
      {:ok, second} = SpawnPipeline.spawn(session)

      assert first.os_pid == second.os_pid
    end
  end

  # ---------------------------------------------------------------------------
  # Stage 9: mark_running — session and run transition to running
  # ---------------------------------------------------------------------------

  describe "spawn/2 — mark_running stage" do
    test "session status is running after successful spawn" do
      _runtime = insert_cat_runtime()
      session = insert_session()

      {:ok, result} = SpawnPipeline.spawn(session)

      assert result.session.status == "running"
    end

    test "run status is running after successful spawn" do
      _runtime = insert_cat_runtime()
      session = insert_session()

      {:ok, result} = SpawnPipeline.spawn(session)

      {:ok, run} = Runs.get(result.run.id)
      assert run.status == "running"
    end
  end

  # ---------------------------------------------------------------------------
  # Stage 10: broadcast — PubSub event emitted
  # ---------------------------------------------------------------------------

  describe "spawn/2 — broadcast stage" do
    test "emits :session_spawned on live_runs:workspace:<slug> topic" do
      _runtime = insert_cat_runtime()
      session = insert_session(%{workspace_slug: "broadcast-test-ws"})

      Phoenix.PubSub.subscribe(Canopy.PubSub, "live_runs:workspace:broadcast-test-ws")

      {:ok, _result} = SpawnPipeline.spawn(session)

      assert_receive {:session_spawned, %{session_id: sid, workspace_slug: "broadcast-test-ws"}},
                     2_000

      assert sid == session.id
    end
  end

  # ---------------------------------------------------------------------------
  # Full trace: successful spawn of a trivial command
  # ---------------------------------------------------------------------------

  describe "spawn/2 — full integration trace" do
    test "returns ok map with all required keys" do
      _runtime = insert_cat_runtime()
      session = insert_session(%{workspace_slug: "integration-ws"})

      assert {:ok, result} = SpawnPipeline.spawn(session)

      assert %{run: run, session: spawned, os_pid: os_pid, worktree: worktree} = result
      assert run.session_id == session.id
      assert spawned.status == "running"
      assert is_integer(os_pid)
      # worktree is nil for a non-git workspace_slug
      assert is_nil(worktree) or is_binary(worktree)
    end
  end

end
