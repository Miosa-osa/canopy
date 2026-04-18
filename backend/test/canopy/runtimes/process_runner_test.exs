defmodule Canopy.Runtimes.ProcessRunnerTest do
  @moduledoc """
  Tests for ghost-session prevention in `Canopy.Runtimes.ProcessRunner`.

  Verifies that a non-zero exit from a subprocess persists `status: "failed"` on
  the session row so sessions never get stuck in `:running` after a crash.

  Uses a minimal inline adapter (`EchoRunner`) backed by a real Port so the full
  `handle_info({port, {:exit_status, code}})` path is exercised end-to-end.

  NOT async — spawns real OS processes and uses PubSub subscriptions.
  The DataCase runs in shared-sandbox mode (async: false) so the spawned
  GenServer processes can access the DB without explicit Sandbox.allow.
  """

  use ExUnit.Case
  use Canopy.DataCase, async: false

  alias Canopy.Sessions
  alias Canopy.Runtimes.TranscriptEntry

  # ---------------------------------------------------------------------------
  # Inline minimal adapter
  # ---------------------------------------------------------------------------

  defmodule EchoRunner do
    @moduledoc false
    use Canopy.Runtimes.ProcessRunner

    @impl Canopy.Runtimes.ProcessRunner
    def parse_line(_raw), do: []

    @impl Canopy.Runtimes.ProcessRunner
    def use_stdin?, do: false
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_running_session! do
    {:ok, session} = Sessions.create(%{runtime_type: "echo-runner", cwd: "/tmp"})
    {:ok, running} = Sessions.update_status(session.id, "running")
    running
  end

  # Drain PubSub until we see a :system entry or the deadline passes.
  defp wait_for_system_entry(deadline) do
    remaining = max(0, deadline - System.monotonic_time(:millisecond))

    receive do
      {:transcript_entry, %TranscriptEntry{kind: :system} = entry} -> {:ok, entry}
      {:transcript_entry, _} -> wait_for_system_entry(deadline)
    after
      remaining -> {:error, :timeout}
    end
  end

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  describe "handle_info({port, {:exit_status, code}}) — ghost-session fix" do
    setup do
      session = create_running_session!()
      :ok = Phoenix.PubSub.subscribe(Canopy.PubSub, "session:#{session.id}")
      {:ok, session: session}
    end

    test "persists status=failed on non-zero exit", %{session: session} do
      # /usr/bin/false exits immediately with code 1
      {:ok, _pid} =
        EchoRunner.start_link(
          session_id: session.id,
          port_cmd: {"/usr/bin/false", []},
          cwd: System.tmp_dir!(),
          prompt: ""
        )

      deadline = System.monotonic_time(:millisecond) + 3_000
      assert {:ok, _entry} = wait_for_system_entry(deadline)

      # Give the DB write a brief moment to complete after the PubSub broadcast
      Process.sleep(50)

      {:ok, updated} = Sessions.get(session.id)
      assert updated.status == "failed"
    end

    test "system entry carries exit_code field on non-zero exit", %{session: session} do
      {:ok, _pid} =
        EchoRunner.start_link(
          session_id: session.id,
          port_cmd: {"/usr/bin/false", []},
          cwd: System.tmp_dir!(),
          prompt: ""
        )

      deadline = System.monotonic_time(:millisecond) + 3_000
      assert {:ok, entry} = wait_for_system_entry(deadline)
      # emit_system_entry passes %{exit_code: code} — atom key in the content map
      assert entry.content[:exit_code] == 1
    end
  end
end
