defmodule Canopy.Sessions.PersistenceTest do
  @moduledoc """
  Tests for disk snapshot + restore of live sessions.

  `async: false` because each test swaps `:session_state_path` on the
  application env and must not race siblings.
  """

  use Canopy.DataCase, async: false

  import Canopy.Factory

  alias Canopy.Sessions
  alias Canopy.Sessions.Persistence

  setup do
    path =
      Path.join(
        System.tmp_dir!(),
        "canopy-session-state-#{System.unique_integer([:positive])}.json"
      )

    previous = Application.get_env(:canopy, :session_state_path)
    Application.put_env(:canopy, :session_state_path, path)

    on_exit(fn ->
      File.rm(path)
      File.rm(path <> ".tmp")

      if previous do
        Application.put_env(:canopy, :session_state_path, previous)
      else
        Application.delete_env(:canopy, :session_state_path)
      end
    end)

    %{path: path}
  end

  describe "save_state/0" do
    test "writes live sessions to the configured JSON path", %{path: path} do
      live =
        insert(:session,
          status: "running",
          cwd: "/tmp/canopy-live",
          runtime_type: "claude-local",
          agent_slug: "senior-dev",
          workspace_slug: "ws-persist",
          external_session_id: "ext-abc",
          kind: "agent_conversation",
          worktree_path: "/tmp/canopy-live/.worktrees/s1",
          branch: "canopy/s1"
        )

      insert(:session, status: "completed", cwd: "/tmp/done")

      assert {:ok, %{path: ^path, count: 1}} = Persistence.save_state()
      assert File.exists?(path)

      payload = path |> File.read!() |> Jason.decode!()
      assert payload["version"] == 1
      assert is_binary(payload["saved_at"])
      assert [entry] = payload["sessions"]
      assert entry["id"] == live.id
      assert entry["status"] == "running"
      assert entry["cwd"] == "/tmp/canopy-live"
      assert entry["runtime_type"] == "claude-local"
      assert entry["agent_slug"] == "senior-dev"
      assert entry["workspace_slug"] == "ws-persist"
      assert entry["external_session_id"] == "ext-abc"
      assert entry["kind"] == "agent_conversation"
      assert entry["worktree_path"] == "/tmp/canopy-live/.worktrees/s1"
      assert entry["branch"] == "canopy/s1"
      assert entry["prompt_bundle_key"] == live.prompt_bundle_key
    end

    test "includes paused and pending sessions and skips cancelled/failed" do
      insert(:session, status: "paused", cwd: "/tmp/paused")
      insert(:session, status: "pending", cwd: "/tmp/pending")
      insert(:session, status: "cancelled", cwd: "/tmp/cancelled")
      insert(:session, status: "failed", cwd: "/tmp/failed")

      assert {:ok, %{count: 2}} = Persistence.save_state()
    end

    test "Sessions.save_state/0 delegates to Persistence" do
      insert(:session, status: "running")
      assert {:ok, %{count: 1}} = Sessions.save_state()
    end
  end

  describe "restore_state/0" do
    test "returns ok with zero restored when the snapshot file is missing", %{path: path} do
      refute File.exists?(path)
      assert {:ok, %{restored: 0, skipped: 0}} = Persistence.restore_state()
    end

    test "rehydrates a missing session row from the snapshot without spawning a pty" do
      session =
        insert(:session,
          status: "running",
          cwd: "/tmp/restore-me",
          runtime_type: "claude-local",
          agent_slug: "builder",
          workspace_slug: "ws-restore",
          external_session_id: "ext-restore",
          kind: "terminal"
        )

      assert {:ok, _} = Persistence.save_state()
      {:ok, _} = Sessions.delete(session.id)

      assert {:error, :not_found} = Sessions.get(session.id)
      assert {:ok, %{restored: 1, skipped: 0}} = Persistence.restore_state(relaunch: false)

      assert {:ok, restored} = Sessions.get(session.id)
      assert restored.id == session.id
      assert restored.status == "running"
      assert restored.cwd == "/tmp/restore-me"
      assert restored.runtime_type == "claude-local"
      assert restored.agent_slug == "builder"
      assert restored.workspace_slug == "ws-restore"
      assert restored.external_session_id == "ext-restore"
      assert restored.kind == "terminal"
    end

    test "a stale snapshot cannot resurrect a cancelled session" do
      session = insert(:session, status: "running", cwd: "/tmp/still-here")
      assert {:ok, _} = Persistence.save_state()
      {:ok, _} = Sessions.update_status(session.id, "cancelled")

      assert {:ok, %{restored: 0, skipped: 1}} = Persistence.restore_state(relaunch: false)
      assert {:ok, restored} = Sessions.get(session.id)
      assert restored.status == "cancelled"
      assert restored.cwd == "/tmp/still-here"
    end

    test "stale snapshot cannot overwrite a current approval hold" do
      session = insert(:session, status: "running", cwd: "/tmp/still-here")
      assert {:ok, _} = Persistence.save_state()
      {:ok, _} = Sessions.update_status(session.id, "pending_approval")
      assert {:ok, %{restored: 1}} = Persistence.restore_state()
      assert {:ok, %{status: "pending_approval"}} = Sessions.get(session.id)
    end

    test "paused sessions stay paused without spawning on restore" do
      session = insert(:session, status: "paused", runtime_type: "nonexistent-runtime")
      assert {:ok, _} = Persistence.save_state()
      assert {:ok, %{restored: 1}} = Persistence.restore_state()
      assert {:ok, %{status: "paused"}} = Sessions.get(session.id)
    end

    test "rejects an unsupported snapshot version", %{path: path} do
      File.write!(path, Jason.encode!(%{"version" => 999, "sessions" => []}))
      assert {:ok, %{error: :invalid_snapshot}} = Persistence.restore_state()
    end

    test "skips malformed UUIDs without aborting startup", %{path: path} do
      File.write!(
        path,
        Jason.encode!(%{
          "version" => 1,
          "sessions" => [
            %{
              "id" => "garbage",
              "runtime_type" => "claude-local",
              "cwd" => "/tmp",
              "status" => "running"
            }
          ]
        })
      )

      assert {:ok, %{restored: 0, skipped: 1}} = Persistence.restore_state()
    end

    test "snapshot is private to the current user", %{path: path} do
      assert {:ok, _} = Persistence.save_state()
      assert {:ok, stat} = File.stat(path)
      assert Bitwise.band(stat.mode, 0o777) == 0o600
    end

    test "skips a corrupt snapshot file", %{path: path} do
      File.write!(path, "not-json{{{")

      assert {:ok, %{restored: 0, skipped: 0, error: :invalid_snapshot}} =
               Persistence.restore_state()
    end

    test "Sessions.restore_state/0 delegates to Persistence" do
      assert {:ok, %{restored: 0}} = Sessions.restore_state()
    end
  end

  describe "state_path/0" do
    test "uses the configured override", %{path: path} do
      assert Persistence.state_path() == path
    end
  end
end
