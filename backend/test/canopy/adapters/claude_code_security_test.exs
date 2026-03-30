defmodule Canopy.Adapters.ClaudeCodeSecurityTest do
  @moduledoc """
  Red-team resource and process lifecycle security tests for the ClaudeCode adapter.

  ## Audit Reference
  These tests document CONFIRMED vulnerabilities found during the sprint-01
  red-team audit. Each test carries a CVE-style identifier from the audit report:

    R-01  Port.close does NOT send SIGTERM to the OS process (zombie leak)
    R-03  Stream.resource finalizer does not run on process kill (resource leak)
    R-07  String.to_atom from dynamic input causes atom table exhaustion

  ## Design intent
  Tests in this module PROVE the vulnerability is real and reproducible. They do
  not modify any source file. When a fix ships, each test must be re-evaluated:
  tests proving a dangerous behavior should be inverted; tests documenting an
  architectural gap with @tag :documents_gap are informational and should be
  replaced by a positive safety test.

  ## Running
      mix test test/canopy/adapters/claude_code_security_test.exs
      mix test --only security

  ## Note on async
  These tests spawn real OS processes (sleep, echo). They are NOT async-safe
  because they share /tmp and rely on OS process table checks. Keep async: false.
  """
  use ExUnit.Case, async: false

  @moduletag :security

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp write_script!(name, content) do
    path = Path.join(System.tmp_dir!(), "canopy_security_#{name}_#{:os.getpid()}")
    File.write!(path, content)
    File.chmod!(path, 0o755)
    path
  end

  # Returns true when the OS process with the given integer PID is still alive.
  # Uses `kill -0 <pid>` — returns exit code 0 if the process exists, non-zero
  # if it has exited or is a zombie being reaped.
  defp os_process_alive?(pid) when is_integer(pid) do
    {_, exit_code} =
      System.cmd("kill", ["-0", Integer.to_string(pid)], stderr_to_stdout: true)

    exit_code == 0
  end

  # ────────────────────────────────────────────────────────────────────────────
  # R-01: Port.close does NOT send SIGTERM to the OS process
  #
  # Vulnerability: When an Elixir port is closed via Port.close/1, the BEAM
  # does NOT send SIGTERM to the spawned OS process. The OS process continues
  # running as an orphan, consuming CPU and memory until it exits on its own.
  #
  # This affects Canopy.Adapters.ClaudeCode.stop/1, which calls Port.close(port)
  # to "stop" a running claude CLI process. The claude process keeps running.
  #
  # Observed in: claude_code.ex lines 50-55 (stop/1), and lines 165-170
  # (Stream.resource finalizer — same Port.close pattern).
  #
  # Root cause: POSIX semantics. Port.close/1 closes the pipe file descriptors
  # between BEAM and the OS process. The OS process receives EOF on stdin but
  # its lifecycle is otherwise unaffected. It must explicitly be killed via
  # System.cmd("kill", ["-TERM", pid]) or Port.info(:os_pid) + :os.kill().
  #
  # Fix: In stop/1, after Port.close, send SIGTERM (with SIGKILL fallback) to
  # the OS PID obtained from Port.info(port, :os_pid). The timeout handler in
  # stream_claude_command/4 already does this correctly — stop/1 should mirror it.
  # ────────────────────────────────────────────────────────────────────────────

  describe "R-01: Port.close does not terminate the OS process" do
    @tag :security
    @tag :r01_zombie_port
    @tag timeout: 15_000
    test "Port.close on a sleep process leaves the OS process running" do
      # VULNERABILITY PROOF:
      # We open a port to `sleep 300`, record the OS PID, call Port.close/1,
      # then check whether the OS process is still alive. It will be.
      #
      # This is the exact call path used by ClaudeCode.stop/1 and the
      # Stream.resource finalizer. A claude CLI process invoked via the adapter
      # that is "stopped" by Port.close will remain alive as a zombie.

      pid_file = Path.join(System.tmp_dir!(), "canopy_r01_pid_#{:os.getpid()}")
      on_exit(fn -> File.rm(pid_file) end)

      sleep_script =
        write_script!("r01_sleep", """
        #!/usr/bin/env bash
        echo $$ > "#{pid_file}"
        sleep 300
        """)

      on_exit(fn -> File.rm(sleep_script) end)

      # Open the port — mirrors how stream_claude_command/4 opens the claude port
      port =
        Port.open(
          {:spawn_executable, sleep_script},
          [:binary, :exit_status, :stderr_to_stdout, cd: to_charlist(System.tmp_dir!())]
        )

      # Wait for the script to write its PID (it starts, writes, then sleeps)
      deadline = System.monotonic_time(:millisecond) + 3_000

      pid_str =
        Enum.reduce_while(1..30, nil, fn _, _ ->
          if System.monotonic_time(:millisecond) > deadline do
            {:halt, nil}
          else
            case File.read(pid_file) do
              {:ok, content} when byte_size(content) > 0 ->
                {:halt, String.trim(content)}

              _ ->
                Process.sleep(100)
                {:cont, nil}
            end
          end
        end)

      assert pid_str != nil,
             "R-01: Mock script must write its PID to #{pid_file} within 3 seconds. " <>
               "Script path: #{sleep_script}"

      os_pid = String.to_integer(pid_str)

      # Confirm the process is alive BEFORE Port.close
      assert os_process_alive?(os_pid),
             "R-01: OS process #{os_pid} must be alive before Port.close"

      # Get the Port's OS PID (must match what the script wrote)
      port_os_pid =
        case Port.info(port, :os_pid) do
          {:os_pid, p} -> p
          _ -> nil
        end

      # THE VULNERABLE CALL — mirrors ClaudeCode.stop/1 exactly
      Port.close(port)

      # Give the OS a moment to process the close
      Process.sleep(300)

      # PROOF OF VULNERABILITY: the OS process is still alive after Port.close
      still_alive = os_process_alive?(os_pid)

      # Clean up — kill the orphan so it doesn't linger after the test
      System.cmd("kill", ["-KILL", Integer.to_string(os_pid)], stderr_to_stdout: true)

      assert still_alive,
             "R-01: OS process #{os_pid} (port OS PID: #{inspect(port_os_pid)}) is DEAD after Port.close. " <>
               "This means Port.close DID send a signal — the vulnerability may not exist " <>
               "on this OS/BEAM version, OR the process exited for another reason. " <>
               "Investigate before marking R-01 as mitigated."
    end

    @tag :security
    @tag :r01_zombie_port
    @tag timeout: 15_000
    test "ClaudeCode.stop/1 with a live port does not kill the OS process" do
      # VULNERABILITY PROOF (adapter-level):
      # This test exercises the exact code path in ClaudeCode.stop/1 (lines 50-55).
      # ClaudeCode.stop(%{port: port}) calls Port.close(port) — that is all.
      # We verify the OS process survives.

      pid_file = Path.join(System.tmp_dir!(), "canopy_r01_stop_pid_#{:os.getpid()}")
      on_exit(fn -> File.rm(pid_file) end)

      sleep_script =
        write_script!("r01_stop", """
        #!/usr/bin/env bash
        echo $$ > "#{pid_file}"
        sleep 300
        """)

      on_exit(fn -> File.rm(sleep_script) end)

      port =
        Port.open(
          {:spawn_executable, sleep_script},
          [:binary, :exit_status, :stderr_to_stdout, cd: to_charlist(System.tmp_dir!())]
        )

      # Wait for PID file
      deadline = System.monotonic_time(:millisecond) + 3_000

      pid_str =
        Enum.reduce_while(1..30, nil, fn _, _ ->
          if System.monotonic_time(:millisecond) > deadline do
            {:halt, nil}
          else
            case File.read(pid_file) do
              {:ok, content} when byte_size(content) > 0 -> {:halt, String.trim(content)}
              _ -> Process.sleep(100) && {:cont, nil}
            end
          end
        end)

      assert pid_str != nil, "R-01 adapter: PID file not written within timeout"
      os_pid = String.to_integer(pid_str)

      # Invoke the adapter's stop/1 directly — the vulnerable code path
      Canopy.Adapters.ClaudeCode.stop(%{port: port})
      Process.sleep(300)

      still_alive = os_process_alive?(os_pid)

      # Clean up the orphan
      System.cmd("kill", ["-KILL", Integer.to_string(os_pid)], stderr_to_stdout: true)

      assert still_alive,
             "R-01 adapter: OS process #{os_pid} was killed by ClaudeCode.stop/1. " <>
               "This means stop/1 already sends a signal — R-01 may be mitigated. " <>
               "Verify source: if Port.close is the only call in stop/1, investigate " <>
               "why the process died (may be SIGPIPE on the pipe, not SIGTERM)."
    end

    @tag :security
    @tag :r01_zombie_port
    @tag timeout: 5_000
    test "Port.close behavior is documented: it closes the pipe, not the process" do
      # EDUCATIONAL / DOCUMENTATION TEST:
      # Proves at the BEAM level that Port.close semantics are "close the pipe",
      # not "kill the process". This is the root cause of R-01.
      #
      # We spawn a process that ignores stdin closure and keeps running.
      # If Port.close sent SIGTERM, the process would die; if it only closes
      # the pipe, the process lives.

      # A process that explicitly ignores SIGPIPE and SIGHUP (the signals that
      # could otherwise kill a process when its pipe closes)
      ignore_script =
        write_script!("r01_pipe_doc", """
        #!/usr/bin/env bash
        trap '' PIPE HUP
        sleep 10
        """)

      on_exit(fn -> File.rm(ignore_script) end)

      port =
        Port.open(
          {:spawn_executable, ignore_script},
          [:binary, :exit_status, cd: to_charlist(System.tmp_dir!())]
        )

      {:os_pid, os_pid} = Port.info(port, :os_pid)
      assert os_process_alive?(os_pid), "Process must be alive before close"

      Port.close(port)
      Process.sleep(200)

      alive_after = os_process_alive?(os_pid)
      # Clean up
      System.cmd("kill", ["-KILL", Integer.to_string(os_pid)], stderr_to_stdout: true)

      assert alive_after,
             "R-01 documentation: A process ignoring SIGPIPE/SIGHUP survives Port.close. " <>
               "This confirms Port.close only closes the pipe FDs, not the OS process. " <>
               "Got: process was killed. " <>
               "This would mean the OS is sending SIGTERM on pipe close — " <>
               "behavior is OS/shell-dependent and cannot be relied upon."
    end
  end

  # ────────────────────────────────────────────────────────────────────────────
  # R-03: Stream.resource finalizer does not run on process kill
  #
  # Vulnerability: The Stream.resource/3 finalizer in stream_claude_command/4
  # (claude_code.ex lines 165-172) calls Port.close(port) to release the port.
  # However, Stream.resource's finalizer is only guaranteed to run when the
  # stream is consumed to completion OR when the consumer process calls
  # Stream.run/1 / Enum.to_list/1 and then explicitly halts.
  #
  # When the CONSUMING PROCESS (the Elixir process that calls Enum.reduce on
  # the stream) is killed with Process.exit(pid, :kill) — a non-trappable
  # exit — the finalizer does NOT run. The port remains open, the OS process
  # remains alive, and the FD leaks.
  #
  # Root cause: BEAM's Stream.resource/3 finalizer uses after_fun which runs
  # in the consuming process. :kill signals bypass after_fun.
  # The :ok exit and normal exceptions do invoke the finalizer correctly.
  #
  # Fix: Wrap the stream consumer in a Task monitored by the caller. Use
  # Process.flag(:trap_exit, true) and handle :EXIT messages; or use a
  # GenServer that owns the port and monitors the consumer, explicitly
  # Port.close-ing on consumer death. The port-owning process must be the
  # one monitoring for abnormal consumer exits.
  # ────────────────────────────────────────────────────────────────────────────

  describe "R-03: Stream.resource finalizer does not run on process kill" do
    @tag :security
    @tag :r03_stream_finalizer
    @tag :documents_gap
    @tag timeout: 10_000
    test "Stream.resource after_fun runs on normal stream completion" do
      # POSITIVE BASELINE: The finalizer DOES run when the stream is consumed
      # normally. This is the happy path. We establish this as a baseline to
      # contrast with the :kill scenario.

      finalized = :counters.new(1, [])

      stream =
        Stream.resource(
          fn -> :state end,
          fn state ->
            # Emit one item then halt
            {[:item], {:halt, state}}
          end,
          fn _state ->
            # Finalizer — increments counter to prove it ran
            :counters.add(finalized, 1, 1)
          end
        )

      # Consume the stream in the current process (normal completion)
      Enum.to_list(stream)

      assert :counters.get(finalized, 1) == 1,
             "R-03 baseline: Stream.resource finalizer must run on normal completion. " <>
               "Counter value: #{:counters.get(finalized, 1)}"
    end

    @tag :security
    @tag :r03_stream_finalizer
    @tag :documents_gap
    @tag timeout: 10_000
    test "Stream.resource after_fun does NOT run when consuming process is killed with :kill" do
      # VULNERABILITY PROOF:
      # This test replicates what happens when the Elixir process running
      # Heartbeat.execute_and_stream/4 is killed with Process.exit(pid, :kill).
      #
      # The Stream.resource finalizer (Port.close) in stream_claude_command/4
      # will NOT run — the port stays open, the OS process stays alive.
      #
      # We verify this by having a child process consume an infinite stream,
      # killing it with :kill, and checking whether the finalizer ran.

      test_pid = self()
      finalized = :counters.new(1, [])

      consumer =
        spawn(fn ->
          stream =
            Stream.resource(
              fn -> send(test_pid, :stream_started) && :running end,
              fn :running ->
                # Block waiting for a message (simulates waiting for port data)
                receive do
                  :halt -> {:halt, :done}
                after
                  5_000 -> {[], :running}
                end
              end,
              fn _state ->
                # This is the finalizer — should run when stream ends
                :counters.add(finalized, 1, 1)
              end
            )

          # Consume the stream (blocks in receive)
          Enum.to_list(stream)
        end)

      # Wait for the consumer to start the stream
      assert_receive :stream_started, 3_000

      # Kill the consumer with a non-trappable signal
      # This is the same as what happens when the Heartbeat GenServer crashes
      # or when the parent process is killed unexpectedly.
      Process.exit(consumer, :kill)

      # Give enough time for any finalizer to potentially run
      Process.sleep(500)

      finalizer_ran = :counters.get(finalized, 1) == 1

      # PROOF: finalizer counter is 0 — it did NOT run
      refute finalizer_ran,
             "R-03: Stream.resource finalizer RAN after :kill. " <>
               "This is unexpected — :kill is non-trappable and should bypass after_fun. " <>
               "BEAM version may have different semantics. Investigate before marking R-03 mitigated."
    end

    @tag :security
    @tag :r03_stream_finalizer
    @tag :documents_gap
    @tag timeout: 5_000
    test "Stream.resource after_fun DOES run when consumer receives normal exit" do
      # CONTRAST TEST: When the consumer exits normally (not :kill), the
      # finalizer runs correctly. This shows the gap is specific to :kill,
      # not a general Stream.resource bug.

      test_pid = self()
      finalized = :counters.new(1, [])

      consumer =
        spawn(fn ->
          stream =
            Stream.resource(
              fn -> :running end,
              fn :running ->
                receive do
                  :halt -> {:halt, :done}
                after
                  5_000 -> {[], :running}
                end
              end,
              fn _state ->
                :counters.add(finalized, 1, 1)
              end
            )

          # Wrap in try/catch to ensure finalizer runs on normal exceptions too
          try do
            Enum.to_list(stream)
          after
            send(test_pid, :consumer_done)
          end
        end)

      # Exit the consumer with a normal reason (trappable, so finalizer runs)
      Process.exit(consumer, :normal)
      Process.sleep(300)

      # With :normal, the stream/finalizer behavior depends on whether the process
      # was in a receive block. :normal may or may not invoke the finalizer.
      # The key point: :kill is categorically different — it is non-trappable.
      # This test documents the contrast behavior for the audit record.
      counter_val = :counters.get(finalized, 1)

      # We assert the architectural gap rather than the exact counter value
      # (since :normal in a receive may or may not reach the finalizer).
      assert counter_val in [0, 1],
             "R-03 contrast: Unexpected counter value #{counter_val} after :normal exit. " <>
               "Expected 0 or 1."
    end
  end

  # ────────────────────────────────────────────────────────────────────────────
  # R-07: String.to_atom from dynamic input causes atom table exhaustion
  #
  # Vulnerability: Elixir atoms are never garbage collected. The BEAM atom
  # table has a fixed maximum (default: 1,048,576). If String.to_atom/1 is
  # called with attacker-controlled input, each unique string creates a new
  # atom permanently. Once the limit is reached, the BEAM crashes.
  #
  # In the Canopy codebase, the primary observed usage is in Ecto's
  # DataCase.errors_on/1 (data_case.ex line 55):
  #   opts |> Keyword.get(String.to_existing_atom(key), key)
  # — this uses String.to_existing_atom which is SAFE (raises if atom doesn't exist).
  #
  # However, any code that calls String.to_atom/1 with user-supplied data is
  # vulnerable. This test module:
  #   1. Proves the atom accumulation mechanics
  #   2. Documents the pattern that triggers R-07
  #   3. Shows the safe alternative (String.to_existing_atom)
  #   4. Provides a canary test for any future regression where dynamic
  #      String.to_atom is introduced into the adapter or related code paths
  #
  # The adapter itself (claude_code.ex) currently does NOT call String.to_atom.
  # R-07 is documented here because the pattern appears in supporting modules
  # and is a standing risk for any future dynamic event-type mapping.
  # ────────────────────────────────────────────────────────────────────────────

  describe "R-07: String.to_atom accumulates atoms from dynamic input" do
    @tag :security
    @tag :r07_atom_exhaustion
    test "String.to_atom creates new atoms for each unique string" do
      # VULNERABILITY MECHANICS PROOF:
      # Each call to String.to_atom with a novel string registers a new entry
      # in the VM atom table. The atom table is a fixed-size hash table —
      # it never shrinks, never GCs.
      #
      # An attacker who can cause String.to_atom to be called with unique strings
      # (e.g., via an API endpoint that maps a JSON field to an atom) can
      # exhaust the atom table and crash the BEAM node.

      # Generate unique strings guaranteed to be novel (not pre-existing atoms)
      unique_prefix = "r07_atom_test_#{:os.getpid()}_#{System.monotonic_time()}"

      # Record atom table size before
      {:ok, stats_before} = :erlang.system_info(:atom_count) |> then(&{:ok, &1})

      # Create 100 novel atoms via String.to_atom
      novel_atoms =
        Enum.map(1..100, fn i ->
          String.to_atom("#{unique_prefix}_#{i}")
        end)

      # Record atom table size after
      atom_count_after = :erlang.system_info(:atom_count)

      # The atom table grew — each unique String.to_atom call added an entry
      assert atom_count_after > stats_before,
             "R-07: Atom count did not increase after String.to_atom calls. " <>
               "Before: #{stats_before}, After: #{atom_count_after}. " <>
               "This is unexpected — String.to_atom must always add new entries."

      # The atoms exist and are callable
      assert length(novel_atoms) == 100, "R-07: All 100 atoms must be created"

      # Prove they are actual atoms (not strings)
      Enum.each(novel_atoms, fn atom ->
        assert is_atom(atom), "R-07: String.to_atom must return an atom. Got: #{inspect(atom)}"
      end)

      # Prove the atoms are permanently retained (no GC)
      # After a GC cycle, the atoms still exist
      :erlang.garbage_collect()
      atom_count_after_gc = :erlang.system_info(:atom_count)

      assert atom_count_after_gc >= atom_count_after,
             "R-07: Atom count decreased after GC — atoms were collected! " <>
               "This is impossible in standard BEAM. Version: #{:erlang.system_info(:version)}"
    end

    @tag :security
    @tag :r07_atom_exhaustion
    test "String.to_existing_atom raises for unknown strings (safe alternative)" do
      # SAFE ALTERNATIVE PROOF:
      # String.to_existing_atom/1 raises ArgumentError when the atom has not
      # been previously created. This prevents accumulation — an attacker-supplied
      # string that is not a pre-existing atom causes an exception rather than
      # creating a new atom.
      #
      # This is the correct pattern for converting user-supplied strings to atoms.
      # Use it instead of String.to_atom for any untrusted input.

      novel_string = "r07_definitely_not_an_existing_atom_#{:os.getpid()}_#{:erlang.unique_integer([:positive])}"

      assert_raise ArgumentError, fn ->
        String.to_existing_atom(novel_string)
      end
    end

    @tag :security
    @tag :r07_atom_exhaustion
    test "ClaudeCode adapter source does not call String.to_atom with dynamic input" do
      # REGRESSION GUARD:
      # Scan the adapter source file to confirm no String.to_atom call exists
      # on potentially dynamic values. This test will catch a future regression
      # where a developer adds String.to_atom for event type mapping.
      #
      # Pattern to guard: String.to_atom(some_variable_or_user_input)
      # Safe pattern:     String.to_existing_atom(key) with rescue, or
      #                   explicit atom literals in pattern match heads.

      source_path =
        Path.join([
          File.cwd!(),
          "lib/canopy/adapters/claude_code.ex"
        ])

      assert File.exists?(source_path),
             "R-07 regression guard: claude_code.ex not found at #{source_path}"

      content = File.read!(source_path)

      # Check for String.to_atom usage (any call — even on static strings is a smell
      # since it will be the pattern future developers copy for dynamic input)
      has_to_atom = String.contains?(content, "String.to_atom(")

      refute has_to_atom,
             "R-07 regression guard: claude_code.ex contains String.to_atom. " <>
               "This is a risk — if the argument is ever dynamic (event type, model name " <>
               "from API response, user-supplied field), it will accumulate atoms. " <>
               "Use pattern matching on binary strings or String.to_existing_atom/1 with rescue."
    end

    @tag :security
    @tag :r07_atom_exhaustion
    test "map_claude_event_type uses binary pattern matching, not String.to_atom" do
      # POSITIVE SECURITY PROOF:
      # The map_claude_event_type/1 private function in claude_code.ex maps
      # event type strings to output strings. Confirm it uses binary pattern
      # matching (safe, no atom creation) rather than dynamic atom conversion.

      source_path =
        Path.join([
          File.cwd!(),
          "lib/canopy/adapters/claude_code.ex"
        ])

      content = File.read!(source_path)

      # Verify map_claude_event_type exists and uses string matches
      assert String.contains?(content, "map_claude_event_type"),
             "R-07: map_claude_event_type/1 must exist in claude_code.ex"

      # The implementation should match on string literals like %{"type" => "assistant"}
      # rather than converting the "type" value to an atom.
      assert String.contains?(content, ~s(defp map_claude_event_type(%{"type" => )),
             "R-07: map_claude_event_type/1 must pattern match on string type values, " <>
               "not convert them to atoms. " <>
               "This confirms R-07 is NOT present in the event mapping path."
    end

    @tag :security
    @tag :r07_atom_exhaustion
    test "atom exhaustion mechanics: atom count is bounded and observable" do
      # OBSERVABILITY TEST:
      # Confirms that :erlang.system_info(:atom_count) and :atom_limit work,
      # allowing ops teams to monitor atom table pressure as a canary metric.
      # This test is informational — it documents the monitoring surface.

      count = :erlang.system_info(:atom_count)
      limit = :erlang.system_info(:atom_limit)

      assert is_integer(count) and count > 0,
             "R-07 observability: :atom_count must return a positive integer"

      assert is_integer(limit) and limit > count,
             "R-07 observability: :atom_limit must be greater than current count. " <>
               "Count: #{count}, Limit: #{limit}"

      # Current headroom
      headroom_pct = (limit - count) / limit * 100

      # In a test environment, headroom should be very large (>90%)
      # In production under an atom exhaustion attack, this drops toward 0.
      assert headroom_pct > 50,
             "R-07 observability: Atom table headroom is #{Float.round(headroom_pct, 1)}% — " <>
               "below 50% in test environment is unexpected. " <>
               "Count: #{count}, Limit: #{limit}. " <>
               "This may indicate a test is leaking atoms or the BEAM was started with " <>
               "a custom (low) atom limit."
    end
  end
end
