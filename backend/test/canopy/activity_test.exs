defmodule Canopy.ActivityTest do
  @moduledoc "Tests for Canopy.Activity feed."

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Activity

  describe "feed/1" do
    test "returns session_started events" do
      _session = insert(:session, workspace_slug: "ws-act", agent_slug: "my-agent")

      feed = Activity.feed(workspace_slug: "ws-act")

      started = Enum.filter(feed, &(&1.type == "session_started"))
      assert length(started) >= 1
    end

    test "returns session_ended events when exit heartbeat exists" do
      session = insert(:session, workspace_slug: "ws-act2")
      insert(:heartbeat, session_id: session.id, kind: :exit, meta: %{"exit_code" => 0})

      feed = Activity.feed(workspace_slug: "ws-act2")

      ended = Enum.filter(feed, &(&1.type == "session_ended"))
      assert length(ended) == 1
      assert hd(ended).session_id == session.id
    end

    test "returns task events for done/cancelled/in_progress tasks" do
      _task =
        insert(:task,
          workspace_slug: "ws-tasks",
          status: "done",
          title: "Ship it"
        )

      feed = Activity.feed(workspace_slug: "ws-tasks")

      completed = Enum.filter(feed, &(&1.type == "task_completed"))
      assert length(completed) >= 1
      assert hd(completed).title == "Ship it"
    end

    test "returns issue events for closed issues" do
      _issue =
        insert(:issue,
          workspace_slug: "ws-issues",
          status: "closed",
          title: "Fix the bug"
        )

      feed = Activity.feed(workspace_slug: "ws-issues")

      closed = Enum.filter(feed, &(&1.type == "issue_closed"))
      assert length(closed) >= 1
      assert hd(closed).title == "Fix the bug"
    end

    test "filters by type" do
      session = insert(:session, workspace_slug: "ws-filter")
      insert(:heartbeat, session_id: session.id, kind: :exit)

      feed = Activity.feed(workspace_slug: "ws-filter", type: "session_ended")

      assert Enum.all?(feed, &(&1.type == "session_ended"))
    end

    test "respects limit" do
      for _ <- 1..10, do: insert(:session, workspace_slug: "ws-limit")

      feed = Activity.feed(workspace_slug: "ws-limit", limit: 3)
      assert length(feed) <= 3
    end

    test "is sorted by at desc" do
      _s = insert(:session, workspace_slug: "ws-sort")

      feed = Activity.feed(workspace_slug: "ws-sort")

      timestamps = Enum.map(feed, & &1.at)

      pairs = Enum.zip(timestamps, tl(timestamps))
      assert Enum.all?(pairs, fn {a, b} -> DateTime.compare(a, b) in [:gt, :eq] end)
    end

    test "returns empty list when no workspace matches" do
      assert Activity.feed(workspace_slug: "nonexistent-ws-xyz") == []
    end

    test "activity items have required keys" do
      insert(:session, workspace_slug: "ws-keys")

      [item | _] = Activity.feed(workspace_slug: "ws-keys")

      assert Map.has_key?(item, :id)
      assert Map.has_key?(item, :type)
      assert Map.has_key?(item, :workspace_slug)
      assert Map.has_key?(item, :actor_type)
      assert Map.has_key?(item, :actor_id)
      assert Map.has_key?(item, :title)
      assert Map.has_key?(item, :at)
    end
  end
end
