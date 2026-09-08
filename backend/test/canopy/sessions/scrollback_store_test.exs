defmodule Canopy.Sessions.ScrollbackStoreTest do
  @moduledoc """
  Unit tests for ScrollbackStore — write, read, and rotation.

  These tests drive the GenServer directly without a live PtyBridge. The store
  is owned by ExUnit's test supervisor and registered for public read calls.
  """

  use ExUnit.Case, async: true

  alias Canopy.Sessions.ScrollbackStore

  @moduletag :capture_log

  # Use a unique tmp dir per test run so parallel tests don't collide.
  setup do
    session_id = "test-#{System.unique_integer([:positive])}"

    # ExUnit stops supervised children before on_exit file cleanup.
    # A direct start_link races test-process shutdown against GenServer.stop/1.
    pid = start_supervised!({ScrollbackStore, session_id})

    # Resolve actual log path from state (using the default ~/.canopy/scrollback dir).
    log_path =
      Path.join([System.user_home!(), ".canopy", "scrollback", "#{session_id}.log"])

    on_exit(fn -> File.rm(log_path) end)

    {:ok, session_id: session_id, pid: pid, log_path: log_path}
  end

  test "the test supervisor owns shutdown before file cleanup", %{
    pid: pid,
    session_id: session_id
  } do
    monitor = Process.monitor(pid)
    assert :ok = stop_supervised({ScrollbackStore, session_id})
    assert_receive {:DOWN, ^monitor, :process, ^pid, :shutdown}
    on_exit(fn -> refute Process.alive?(pid) end)
  end

  describe "write and read" do
    test "bytes written via :pty_output are readable via read/2", %{
      pid: pid,
      log_path: log_path
    } do
      send(pid, {:pty_output, "hello"})
      send(pid, {:pty_output, " world"})

      # Give the GenServer mailbox time to process.
      :sys.get_state(pid)

      assert File.exists?(log_path)
      assert File.read!(log_path) == "hello world"
    end

    test "read/2 returns bytes and total offset", %{session_id: session_id, pid: pid} do
      send(pid, {:pty_output, "line1\nline2\n"})
      :sys.get_state(pid)

      assert {:ok, data, total} = ScrollbackStore.read(session_id)
      assert data =~ "line1"
      assert total == byte_size("line1\nline2\n")
    end

    test "read/2 from: offset returns only tail bytes", %{session_id: session_id, pid: pid} do
      send(pid, {:pty_output, "AAABBB"})
      :sys.get_state(pid)

      {:ok, data, _total} = ScrollbackStore.read(session_id, from: 3)
      assert data == "BBB"
    end

    test "read/2 returns :not_found for unknown session" do
      assert {:error, :not_found} =
               ScrollbackStore.read("does-not-exist-#{System.unique_integer()}")
    end
  end

  describe "pty_exit" do
    test "store survives pty exit and log is kept", %{
      pid: pid,
      log_path: log_path
    } do
      send(pid, {:pty_output, "output before exit\n"})
      send(pid, {:pty_exit, 0})
      :sys.get_state(pid)

      assert Process.alive?(pid)
      assert File.exists?(log_path)
      assert File.read!(log_path) =~ "output before exit"
    end
  end

  describe "rotation" do
    test "file is rotated when it exceeds 10 MB", %{pid: pid, log_path: log_path} do
      # Write 6 MB chunks twice to push past the 10 MB threshold.
      chunk = :binary.copy(<<65>>, 6_000_000)
      send(pid, {:pty_output, chunk})
      send(pid, {:pty_output, chunk})
      :sys.get_state(pid)

      # After rotation the file should be at most 5 MB (the keep_bytes sentinel).
      {:ok, %{size: size}} = File.stat(log_path)
      assert size <= 5_242_880
    end
  end
end
