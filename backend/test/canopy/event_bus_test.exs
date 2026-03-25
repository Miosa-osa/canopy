defmodule Canopy.EventBusTest do
  @moduledoc """
  Tests for Canopy.EventBus PubSub wrapper.

  Verifies:
  - subscribe/broadcast round-trip
  - broadcast!/1 raises on failure (indirectly)
  - Topic builder functions produce correct strings
  - Multiple subscribers receive the same event
  - Unsubscribe stops delivery
  """
  use ExUnit.Case, async: true

  alias Canopy.EventBus

  setup do
    # Each test gets a unique topic suffix to avoid cross-test interference
    suffix = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    {:ok, suffix: suffix}
  end

  # ── Topic builders ──

  describe "topic builders" do
    test "workspace_topic/1" do
      assert EventBus.workspace_topic("ws-1") == "workspace:ws-1"
    end

    test "agent_topic/1" do
      assert EventBus.agent_topic("agent-42") == "agent:agent-42"
    end

    test "session_topic/1" do
      assert EventBus.session_topic("sess-abc") == "session:sess-abc"
    end

    test "organization_topic/1" do
      assert EventBus.organization_topic("org-1") == "organization:org-1"
    end

    test "division_topic/1" do
      assert EventBus.division_topic("div-1") == "division:div-1"
    end

    test "department_topic/1" do
      assert EventBus.department_topic("dept-1") == "department:dept-1"
    end

    test "team_topic/1" do
      assert EventBus.team_topic("team-1") == "team:team-1"
    end

    test "activity_topic/0" do
      assert EventBus.activity_topic() == "activity:global"
    end

    test "logs_topic/0" do
      assert EventBus.logs_topic() == "logs:global"
    end

    test "notifications_topic/1" do
      assert EventBus.notifications_topic("ws-1") == "notifications:ws-1"
    end

    test "workflow_topic/1" do
      assert EventBus.workflow_topic("wf-1") == "workflow:wf-1"
    end

    test "workflow_run_topic/1" do
      assert EventBus.workflow_run_topic("run-1") == "workflow_run:run-1"
    end
  end

  # ── PubSub round-trip ──

  describe "subscribe + broadcast round-trip" do
    test "subscriber receives broadcast message", %{suffix: suffix} do
      topic = "test:#{suffix}"
      :ok = EventBus.subscribe(topic)

      payload = {:test_event, %{data: "hello"}}
      :ok = EventBus.broadcast(topic, payload)

      assert_receive ^payload, 1_000
    end

    test "broadcast! also delivers to subscriber", %{suffix: suffix} do
      topic = "test_bang:#{suffix}"
      :ok = EventBus.subscribe(topic)

      payload = {:bang_event, %{value: 42}}
      :ok = EventBus.broadcast!(topic, payload)

      assert_receive ^payload, 1_000
    end

    test "subscriber receives multiple messages in order", %{suffix: suffix} do
      topic = "test_multi:#{suffix}"
      :ok = EventBus.subscribe(topic)

      :ok = EventBus.broadcast(topic, {:msg, 1})
      :ok = EventBus.broadcast(topic, {:msg, 2})
      :ok = EventBus.broadcast(topic, {:msg, 3})

      assert_receive {:msg, 1}, 1_000
      assert_receive {:msg, 2}, 1_000
      assert_receive {:msg, 3}, 1_000
    end

    test "messages on different topics don't cross", %{suffix: suffix} do
      topic_a = "test_a:#{suffix}"
      topic_b = "test_b:#{suffix}"

      :ok = EventBus.subscribe(topic_a)

      :ok = EventBus.broadcast(topic_b, {:wrong_topic, true})
      :ok = EventBus.broadcast(topic_a, {:right_topic, true})

      assert_receive {:right_topic, true}, 1_000
      refute_receive {:wrong_topic, true}, 200
    end
  end

  # ── Multiple subscribers ──

  describe "multiple subscribers" do
    test "all subscribers receive the same broadcast", %{suffix: suffix} do
      topic = "test_fanout:#{suffix}"
      parent = self()

      # Spawn 3 subscriber processes
      pids =
        for i <- 1..3 do
          spawn(fn ->
            :ok = EventBus.subscribe(topic)
            send(parent, {:subscribed, i})

            receive do
              msg -> send(parent, {:received, i, msg})
            after
              5_000 -> send(parent, {:timeout, i})
            end
          end)
        end

      # Wait for all to subscribe
      for i <- 1..3 do
        assert_receive {:subscribed, ^i}, 1_000
      end

      # Small delay to ensure subscriptions are registered
      Process.sleep(50)

      payload = {:fanout_event, %{data: "broadcast"}}
      :ok = EventBus.broadcast(topic, payload)

      # All 3 should receive
      for i <- 1..3 do
        assert_receive {:received, ^i, ^payload}, 1_000
      end

      # Cleanup
      Enum.each(pids, fn pid ->
        if Process.alive?(pid), do: Process.exit(pid, :normal)
      end)
    end
  end

  # ── Unsubscribe ──

  describe "unsubscribe/1" do
    test "stops delivery after unsubscribe", %{suffix: suffix} do
      topic = "test_unsub:#{suffix}"
      :ok = EventBus.subscribe(topic)

      # First message should arrive
      :ok = EventBus.broadcast(topic, {:before_unsub, true})
      assert_receive {:before_unsub, true}, 1_000

      # Unsubscribe
      :ok = EventBus.unsubscribe(topic)

      # Message after unsub should not arrive
      :ok = EventBus.broadcast(topic, {:after_unsub, true})
      refute_receive {:after_unsub, true}, 200
    end
  end

  # ── Integration: topic builders with broadcast ──

  describe "topic builders integration" do
    test "agent topic broadcasts reach subscribers", %{suffix: suffix} do
      agent_id = "agent-#{suffix}"
      topic = EventBus.agent_topic(agent_id)

      :ok = EventBus.subscribe(topic)
      :ok = EventBus.broadcast(topic, {:agent_heartbeat, %{agent_id: agent_id}})

      assert_receive {:agent_heartbeat, %{agent_id: ^agent_id}}, 1_000
    end

    test "session topic broadcasts reach subscribers", %{suffix: suffix} do
      session_id = "sess-#{suffix}"
      topic = EventBus.session_topic(session_id)

      :ok = EventBus.subscribe(topic)
      :ok = EventBus.broadcast(topic, {:session_event, %{type: "run.output"}})

      assert_receive {:session_event, %{type: "run.output"}}, 1_000
    end

    test "activity topic delivers stale_cleanup events", %{suffix: _suffix} do
      topic = EventBus.activity_topic()
      :ok = EventBus.subscribe(topic)

      event = {:stale_cleanup, %{issues_reclaimed: 2, sessions_failed: 1}}
      :ok = EventBus.broadcast(topic, event)

      assert_receive {:stale_cleanup, %{issues_reclaimed: 2, sessions_failed: 1}}, 1_000
    end

    test "workflow_run topic delivers step events", %{suffix: suffix} do
      run_id = "run-#{suffix}"
      topic = EventBus.workflow_run_topic(run_id)

      :ok = EventBus.subscribe(topic)
      :ok = EventBus.broadcast(topic, {:step_completed, %{step: 1, status: "ok"}})

      assert_receive {:step_completed, %{step: 1, status: "ok"}}, 1_000
    end
  end
end
