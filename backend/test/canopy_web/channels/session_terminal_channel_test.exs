defmodule CanopyWeb.SessionTerminalChannelTest do
  @moduledoc """
  Integration tests for SessionTerminalChannel.

  Uses Phoenix.ChannelTest with the real Ecto sandbox.
  Pty subprocess is a deterministic system binary in each test.
  """

  use CanopyWeb.ChannelCase

  import Canopy.Factory

  alias CanopyWeb.UserSocket

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp join_channel(binary_path) do
    runtime =
      insert(:runtime,
        type: "test-shell-#{System.unique_integer([:positive])}",
        kind: "cli",
        binary_path: binary_path
      )

    session = insert(:session, runtime_type: runtime.type, cwd: "/tmp")

    {:ok, _, socket} =
      UserSocket
      |> socket("user_socket:test", %{user_id: nil})
      |> subscribe_and_join(CanopyWeb.SessionTerminalChannel, "terminal:session:#{session.id}")

    %{socket: socket, session: session}
  end

  # ---------------------------------------------------------------------------
  # Test 1: join_success
  # ---------------------------------------------------------------------------

  @tag :capture_log
  test "join succeeds for an existing session" do
    runtime =
      insert(:runtime,
        type: "test-shell-#{System.unique_integer([:positive])}",
        kind: "cli",
        binary_path: "/bin/bash"
      )

    session = insert(:session, runtime_type: runtime.type, cwd: "/tmp")

    assert {:ok, _, _socket} =
             UserSocket
             |> socket("user_socket:test", %{user_id: nil})
             |> subscribe_and_join(
               CanopyWeb.SessionTerminalChannel,
               "terminal:session:#{session.id}"
             )
  end

  # ---------------------------------------------------------------------------
  # Test 2: join_not_found
  # ---------------------------------------------------------------------------

  test "join returns error for unknown session_id" do
    fake_id = Ecto.UUID.generate()

    assert {:error, %{reason: "not_found"}} =
             UserSocket
             |> socket("user_socket:test", %{user_id: nil})
             |> subscribe_and_join(
               CanopyWeb.SessionTerminalChannel,
               "terminal:session:#{fake_id}"
             )
  end

  # ---------------------------------------------------------------------------
  # Test 3: input_echo — /bin/cat echoes stdin back as pty output
  # ---------------------------------------------------------------------------

  @tag :capture_log
  test "input is written to pty and output is pushed back" do
    # /bin/cat echoes everything written to its stdin
    %{socket: socket} = join_channel("/bin/cat")

    push(socket, "input", %{"data" => "hello\n"})

    assert_push "output", %{data: data}, 1000
    assert data =~ "hello"
  end

  # ---------------------------------------------------------------------------
  # Test 4: exit_propagates — exiting process sends "exit" frame
  # ---------------------------------------------------------------------------

  @tag :capture_log
  test "process exit is pushed as exit frame with integer code" do
    # Trigger exit after subscribe_and_join has linked the channel process.
    # An immediate /usr/bin/true exit races ChannelTest's own link setup.
    %{socket: socket} = join_channel("/bin/sh")
    push(socket, "input", %{"data" => "exit 0\n"})

    assert_push "exit", %{code: code}, 2000
    assert is_integer(code)
    assert code == 0
  end

  # ---------------------------------------------------------------------------
  # Test 5: full frontend flow — simulates the browser's join → input → output
  # round-trip so any regression to the wire protocol surfaces here (not just in
  # the live app). The same pty is reused across the flow to catch attach leaks.
  # ---------------------------------------------------------------------------

  @tag :capture_log
  test "full frontend flow: join returns ok, input is echoed, resize does not crash" do
    # /bin/cat echoes stdin — stable across machines.
    %{socket: socket} = join_channel("/bin/cat")

    # Resize before input — the frontend sends this on first phx_reply.
    push(socket, "resize", %{"cols" => 120, "rows" => 40})

    # Write some bytes and confirm they come back via "output" event.
    push(socket, "input", %{"data" => "CANOPY_WIRE_OK\n"})

    assert_push "output", %{data: data}, 1500
    assert data =~ "CANOPY_WIRE_OK"
  end

  # ---------------------------------------------------------------------------
  # Test 6: resilience — no DB sandbox ownership crash on pty output
  # Regression guard for pty_bridge.ex async_record/4 calling
  # Ecto.Adapters.SQL.Sandbox.allow/2 unconditionally, which raised on every
  # stdout chunk in dev (non-sandbox pool). We keep this green in test too.
  # ---------------------------------------------------------------------------

  @tag :capture_log
  test "pty output arrives even when heartbeat recording is async" do
    %{socket: socket} = join_channel("/bin/cat")

    push(socket, "input", %{"data" => "PING\n"})
    assert_push "output", %{data: data}, 1500
    assert data =~ "PING"

    # A second write should also round-trip cleanly — asserts the bridge GenServer
    # did not crash from an async task error.
    push(socket, "input", %{"data" => "PONG\n"})
    assert_push "output", %{data: data2}, 1500
    assert data2 =~ "PONG"
  end
end
