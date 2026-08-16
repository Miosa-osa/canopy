defmodule CanopyWeb.LiveRunsChannelTest do
  @moduledoc """
  Integration tests for LiveRunsChannel.

  Tests join behaviour across all three topic shapes, broadcast routing,
  and multi-subscriber delivery semantics.
  """

  use CanopyWeb.ChannelCase

  alias CanopyWeb.UserSocket
  alias Canopy.Runs.Events

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp connect_socket do
    socket(UserSocket, "user_socket:#{System.unique_integer([:positive])}", %{user_id: nil})
  end

  defp join(topic) do
    {:ok, _, socket} =
      connect_socket()
      |> subscribe_and_join(CanopyWeb.LiveRunsChannel, topic)

    socket
  end

  defp sample_run_payload(overrides \\ %{}) do
    Map.merge(
      %{
        run_id: Ecto.UUID.generate(),
        short_id: "R-TEST0001",
        session_id: Ecto.UUID.generate(),
        workspace_slug: "default",
        agent_slug: "test-agent",
        started_at: DateTime.to_iso8601(DateTime.utc_now())
      },
      overrides
    )
  end

  # ---------------------------------------------------------------------------
  # 1. Join — workspace topic
  # ---------------------------------------------------------------------------

  test "joins live_runs:workspace:<slug> successfully" do
    assert {:ok, _, _socket} =
             connect_socket()
             |> subscribe_and_join(CanopyWeb.LiveRunsChannel, "live_runs:workspace:default")
  end

  # ---------------------------------------------------------------------------
  # 2. Join — per-run topic
  # ---------------------------------------------------------------------------

  test "joins live_runs:run:<short_id> successfully" do
    assert {:ok, _, _socket} =
             connect_socket()
             |> subscribe_and_join(CanopyWeb.LiveRunsChannel, "live_runs:run:R-00000001")
  end

  # ---------------------------------------------------------------------------
  # 3. Join — admin topic
  # ---------------------------------------------------------------------------

  test "joins live_runs:all successfully" do
    assert {:ok, _, _socket} =
             connect_socket()
             |> subscribe_and_join(CanopyWeb.LiveRunsChannel, "live_runs:all")
  end

  # ---------------------------------------------------------------------------
  # 4. Invalid topic rejected
  # ---------------------------------------------------------------------------

  test "joining an invalid topic returns error" do
    assert {:error, %{reason: "invalid_topic"}} =
             connect_socket()
             |> subscribe_and_join(CanopyWeb.LiveRunsChannel, "live_runs:bogus")
  end

  # ---------------------------------------------------------------------------
  # 5. Broadcast flow: run_started reaches workspace subscriber
  # ---------------------------------------------------------------------------

  test "run_started broadcast is received by workspace subscriber" do
    _socket = join("live_runs:workspace:default")
    payload = sample_run_payload()

    Events.run_started(payload)

    assert_push "run_started", received, 500
    assert received.run_id == payload.run_id
    assert received.short_id == payload.short_id
    assert received.workspace_slug == "default"
  end

  # ---------------------------------------------------------------------------
  # 6. Broadcast flow: run_started reaches per-run subscriber
  # ---------------------------------------------------------------------------

  test "run_started broadcast is received by per-run subscriber" do
    short_id = "R-TESTPRUN"
    payload = sample_run_payload(%{short_id: short_id})

    _socket = join("live_runs:run:#{short_id}")
    Events.run_started(payload)

    assert_push "run_started", received, 500
    assert received.short_id == short_id
  end

  # ---------------------------------------------------------------------------
  # 7. Broadcast flow: run_started reaches live_runs:all subscriber
  # ---------------------------------------------------------------------------

  test "run_started broadcast is received by all subscriber" do
    _socket = join("live_runs:all")
    payload = sample_run_payload(%{short_id: "R-ALLEVT01"})

    Events.run_started(payload)

    assert_push "run_started", received, 500
    assert received.short_id == "R-ALLEVT01"
  end

  # ---------------------------------------------------------------------------
  # 8. run_finished is pushed as "run_finished" event
  # ---------------------------------------------------------------------------

  test "run_finished broadcast is received by workspace subscriber" do
    _socket = join("live_runs:workspace:default")

    finished_payload = %{
      run_id: Ecto.UUID.generate(),
      short_id: "R-FINISH01",
      workspace_slug: "default",
      status: "succeeded",
      usage_json: %{"tokens_in" => 100},
      finished_at: DateTime.to_iso8601(DateTime.utc_now())
    }

    Events.run_finished(finished_payload)

    assert_push "run_finished", received, 500
    assert received.status == "succeeded"
    assert received.short_id == "R-FINISH01"
  end

  # ---------------------------------------------------------------------------
  # 9. run_status (paused) is pushed correctly
  # ---------------------------------------------------------------------------

  test "run_status broadcast is received by workspace subscriber" do
    _socket = join("live_runs:workspace:default")

    status_payload = %{
      run_id: Ecto.UUID.generate(),
      short_id: "R-STATUS01",
      workspace_slug: "default",
      status: "paused",
      at: DateTime.to_iso8601(DateTime.utc_now())
    }

    Events.run_status(status_payload)

    assert_push "run_status", received, 500
    assert received.status == "paused"
  end

  # ---------------------------------------------------------------------------
  # 10. run_log is pushed correctly
  # ---------------------------------------------------------------------------

  test "run_log broadcast is received by per-run subscriber" do
    short_id = "R-LOG00001"
    _socket = join("live_runs:run:#{short_id}")

    log_payload = %{
      run_id: Ecto.UUID.generate(),
      short_id: short_id,
      workspace_slug: "default",
      seq: 42,
      kind: "stdout",
      data: "hello from agent\n",
      at: DateTime.to_iso8601(DateTime.utc_now())
    }

    Events.run_log(log_payload)

    assert_push "run_log", received, 500
    assert received.seq == 42
    assert received.data == "hello from agent\n"
  end

  # ---------------------------------------------------------------------------
  # 11. Multi-subscriber: two sockets on same topic both get the event
  # ---------------------------------------------------------------------------

  test "two subscribers on the same workspace topic both receive broadcasts" do
    topic = "live_runs:workspace:multi-test"

    socket_a = connect_socket()
    socket_b = connect_socket()

    {:ok, _, _} = subscribe_and_join(socket_a, CanopyWeb.LiveRunsChannel, topic)
    {:ok, _, _} = subscribe_and_join(socket_b, CanopyWeb.LiveRunsChannel, topic)

    payload = sample_run_payload(%{workspace_slug: "multi-test"})
    Events.run_started(payload)

    # Both sockets are in the same process in test; assert_push checks the
    # current process mailbox which receives all pushes from both sockets.
    assert_push "run_started", first, 500
    assert_push "run_started", second, 500

    assert first.run_id == payload.run_id
    assert second.run_id == payload.run_id
  end

  # ---------------------------------------------------------------------------
  # 12. Workspace isolation: subscriber on workspace A does not get workspace B events
  # ---------------------------------------------------------------------------

  test "workspace subscriber does not receive events from a different workspace" do
    _socket = join("live_runs:workspace:workspace-a")

    payload = sample_run_payload(%{workspace_slug: "workspace-b"})
    Events.run_started(payload)

    refute_push "run_started", _any, 200
  end

  # ---------------------------------------------------------------------------
  # 13. run_tool_call and run_tool_result are forwarded
  # ---------------------------------------------------------------------------

  test "run_tool_call and run_tool_result are pushed to workspace subscriber" do
    _socket = join("live_runs:workspace:default")

    base = %{run_id: Ecto.UUID.generate(), short_id: "R-TOOL0001", workspace_slug: "default"}

    Events.run_tool_call(Map.merge(base, %{tool_name: "canopy.create_task", params: %{}, at: "now"}))
    assert_push "run_tool_call", call_ev, 500
    assert call_ev.tool_name == "canopy.create_task"

    Events.run_tool_result(Map.merge(base, %{tool_name: "canopy.create_task", result: %{ok: true}, at: "now"}))
    assert_push "run_tool_result", result_ev, 500
    assert result_ev.tool_name == "canopy.create_task"
  end
end
