defmodule Canopy.Sessions.PtyBridgePauseTest do
  @moduledoc """
  Tests for PtyBridge.pause/1 and PtyBridge.resume/1.

  Spawns a real `cat` subprocess (reads stdin, echoes to stdout). A subscriber
  process collects {:pty_output, data} messages. Assertions:
    - While paused, output is buffered and NOT forwarded.
    - On resume, the buffered output IS flushed.
    - After resume, subsequent output is forwarded normally.
    - Buffer overflow (> 4096 bytes) drops oldest bytes, keeps last 4096.

  The PtyBridge calls async_record/4 for heartbeat telemetry. In tests the
  Ecto sandbox does not own those spawned Task processes, so the async inserts
  fail silently (fire-and-forget). The test assertions are unaffected.
  """

  use Canopy.DataCase, async: false

  alias Canopy.Sessions.PtyBridge

  setup do
    cat = System.find_executable("cat")

    unless cat do
      raise "cat not found on PATH — cannot run PtyBridge tests"
    end

    session_id = Ecto.UUID.generate()

    spec = PtyBridge.child_spec({session_id, cat, [], []})

    {:ok, _pid} =
      DynamicSupervisor.start_child(Canopy.Sessions.PtySupervisor, spec)

    on_exit(fn ->
      PtyBridge.stop(session_id)
    end)

    # Allow a moment for the port to open.
    Process.sleep(50)

    %{session_id: session_id}
  end

  defp collect_output(timeout \\ 200) do
    collect_output([], timeout)
  end

  defp collect_output(acc, timeout) do
    receive do
      {:pty_output, data} -> collect_output([data | acc], timeout)
    after
      timeout -> Enum.reverse(acc) |> Enum.join()
    end
  end

  describe "pause/1 and resume/1" do
    test "output is NOT forwarded while paused, then flushed on resume", %{session_id: sid} do
      PtyBridge.attach(sid, self())

      # Normal write — should receive it.
      PtyBridge.send_input(sid, "hello\n")
      output_before = collect_output()
      assert String.contains?(output_before, "hello")

      # Pause, then write while paused.
      PtyBridge.pause(sid)
      PtyBridge.send_input(sid, "paused-data\n")

      # Nothing should arrive during pause window.
      received_while_paused =
        receive do
          {:pty_output, _} = msg -> msg
        after
          150 -> nil
        end

      assert received_while_paused == nil,
             "Expected no output while paused, got: #{inspect(received_while_paused)}"

      # Resume — buffered data should flush.
      PtyBridge.resume(sid)
      flushed = collect_output(300)

      assert String.contains?(flushed, "paused-data"),
             "Expected buffered data on resume, got: #{inspect(flushed)}"

      # Normal output after resume.
      PtyBridge.send_input(sid, "after-resume\n")
      after_output = collect_output()
      assert String.contains?(after_output, "after-resume")
    end

    test "empty buffer on resume produces no spurious output", %{session_id: sid} do
      PtyBridge.attach(sid, self())
      PtyBridge.pause(sid)
      PtyBridge.resume(sid)

      msg =
        receive do
          {:pty_output, _} = m -> m
        after
          150 -> nil
        end

      assert msg == nil
    end

    test "buffer overflow keeps last 65536 bytes", %{session_id: sid} do
      PtyBridge.attach(sid, self())
      PtyBridge.pause(sid)

      # With a real PTY the kernel line buffer is ~4096 bytes per write, so we
      # inject output directly into the GenServer via crafted {:stdout, os_pid, data}
      # messages rather than routing through cat+PTY echo (which has its own limits).
      # This tests the GenServer buffer-capping logic in isolation.
      [{bridge_pid, _}] = Registry.lookup(Canopy.Sessions.PtyRegistry, sid)

      # Retrieve the os_pid from the bridge state so the pattern match passes.
      os_pid = :sys.get_state(bridge_pid).os_pid

      # Send two chunks that together exceed the 64 KB cap.
      chunk1 = String.duplicate("A", 40_000) <> "\n"
      chunk2 = String.duplicate("B", 40_000) <> "\n"

      send(bridge_pid, {:stdout, os_pid, chunk1})
      send(bridge_pid, {:stdout, os_pid, chunk2})

      # Give the GenServer time to process both messages.
      Process.sleep(100)

      PtyBridge.resume(sid)
      flushed = collect_output(400)

      assert byte_size(flushed) <= 65_536, "Buffer should be capped at 65536 bytes"
      assert String.contains?(flushed, "B"), "Last chunk's content should survive overflow"
    end
  end
end
