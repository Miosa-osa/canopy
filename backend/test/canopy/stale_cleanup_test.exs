defmodule Canopy.StaleCleanupTest do
  @moduledoc """
  Tests for Canopy.StaleCleanup GenServer.

  Verifies:
  - GenServer starts and schedules periodic cleanup
  - run_now/0 triggers immediate cleanup
  - Stuck issues get reclaimed after timeout
  - Stale active sessions get marked as failed
  - EventBus broadcasts are emitted on cleanup
  - Configurable intervals and timeouts
  """
  use Canopy.DataCase, async: false

  alias Canopy.StaleCleanup
  alias Canopy.Schemas.{Issue, Session, Agent, Organization, Workspace}
  alias Canopy.EventBus

  # ── Helpers ──

  defp create_workspace do
    uid = System.unique_integer([:positive])

    org =
      %Organization{}
      |> Organization.changeset(%{
        name: "Test Org #{uid}",
        slug: "test-org-#{uid}"
      })
      |> Repo.insert!()

    %Workspace{}
    |> Workspace.changeset(%{
      name: "Test WS #{uid}",
      path: "/tmp/canopy-test-#{uid}",
      organization_id: org.id
    })
    |> Repo.insert!()
  end

  defp create_agent(workspace) do
    uid = System.unique_integer([:positive])

    %Agent{}
    |> Agent.changeset(%{
      name: "Test Agent #{uid}",
      slug: "test-agent-#{uid}",
      workspace_id: workspace.id,
      adapter: "bash",
      role: "developer",
      model: "test",
      status: "active"
    })
    |> Repo.insert!()
  end

  defp create_stuck_issue(workspace, agent, minutes_ago) do
    past = DateTime.add(DateTime.utc_now(), -minutes_ago * 60, :second)

    %Issue{}
    |> Issue.changeset(%{
      title: "Stuck Issue #{System.unique_integer([:positive])}",
      workspace_id: workspace.id,
      status: "in_progress",
      checked_out_by: agent.id,
      priority: "medium"
    })
    |> Repo.insert!()
    |> then(fn issue ->
      # Force the updated_at to be in the past
      Repo.update_all(
        from(i in Issue, where: i.id == ^issue.id),
        set: [updated_at: past |> DateTime.truncate(:second)]
      )

      Repo.get!(Issue, issue.id)
    end)
  end

  defp create_stale_session(agent, minutes_ago) do
    past = DateTime.add(DateTime.utc_now(), -minutes_ago * 60, :second)

    %Session{}
    |> Session.changeset(%{
      agent_id: agent.id,
      model: "test",
      status: "active",
      started_at: past |> DateTime.truncate(:second)
    })
    |> Repo.insert!()
  end

  # ── Tests ──

  describe "start_link/1" do
    test "starts the GenServer with default name" do
      # Stop the global instance if running (started by Application)
      case GenServer.whereis(StaleCleanup) do
        nil -> :ok
        pid -> GenServer.stop(pid, :normal)
      end

      assert {:ok, pid} = StaleCleanup.start_link(name: :"test_cleanup_#{System.unique_integer()}")
      assert Process.alive?(pid)
      GenServer.stop(pid, :normal)
    end

    test "accepts custom options" do
      name = :"test_cleanup_custom_#{System.unique_integer()}"

      assert {:ok, pid} =
               StaleCleanup.start_link(
                 name: name,
                 cleanup_interval: 60_000,
                 issue_timeout_minutes: 10,
                 session_timeout_minutes: 15
               )

      assert Process.alive?(pid)
      GenServer.stop(pid, :normal)
    end
  end

  describe "run_now/1" do
    setup do
      name = :"test_cleanup_run_now_#{System.unique_integer()}"

      {:ok, pid} =
        StaleCleanup.start_link(
          name: name,
          cleanup_interval: :timer.hours(24),
          issue_timeout_minutes: 30,
          session_timeout_minutes: 30
        )

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      end)

      {:ok, server: name}
    end

    test "returns ok with counts when no stale data", %{server: server} do
      assert {:ok, %{issues: 0, sessions: 0}} = StaleCleanup.run_now(server)
    end

    test "reclaims stuck issues older than timeout", %{server: server} do
      workspace = create_workspace()
      agent = create_agent(workspace)

      # Issue stuck for 60 minutes (> 30 min timeout)
      issue = create_stuck_issue(workspace, agent, 60)
      assert issue.status == "in_progress"

      {:ok, %{issues: count}} = StaleCleanup.run_now(server)
      assert count >= 1

      updated = Repo.get!(Issue, issue.id)
      assert updated.status == "backlog"
      assert is_nil(updated.checked_out_by)
    end

    test "does NOT reclaim recent issues", %{server: server} do
      workspace = create_workspace()
      agent = create_agent(workspace)

      # Issue only 5 minutes old (< 30 min timeout)
      issue = create_stuck_issue(workspace, agent, 5)

      {:ok, %{issues: count}} = StaleCleanup.run_now(server)
      assert count == 0

      updated = Repo.get!(Issue, issue.id)
      assert updated.status == "in_progress"
    end

    test "fails stale active sessions older than timeout", %{server: server} do
      workspace = create_workspace()
      agent = create_agent(workspace)

      # Session active for 60 minutes (> 30 min timeout)
      session = create_stale_session(agent, 60)
      assert session.status == "active"

      {:ok, %{sessions: count}} = StaleCleanup.run_now(server)
      assert count >= 1

      updated = Repo.get!(Session, session.id)
      assert updated.status == "failed"
      assert not is_nil(updated.completed_at)
    end

    test "does NOT fail recent active sessions", %{server: server} do
      workspace = create_workspace()
      agent = create_agent(workspace)

      # Session only 5 minutes old (< 30 min timeout)
      session = create_stale_session(agent, 5)

      {:ok, %{sessions: count}} = StaleCleanup.run_now(server)
      assert count == 0

      updated = Repo.get!(Session, session.id)
      assert updated.status == "active"
    end
  end

  describe "EventBus broadcast on cleanup" do
    setup do
      name = :"test_cleanup_broadcast_#{System.unique_integer()}"

      {:ok, pid} =
        StaleCleanup.start_link(
          name: name,
          cleanup_interval: :timer.hours(24),
          issue_timeout_minutes: 30,
          session_timeout_minutes: 30
        )

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      end)

      {:ok, server: name}
    end

    test "broadcasts cleanup event when issues are reclaimed", %{server: server} do
      workspace = create_workspace()
      agent = create_agent(workspace)
      _issue = create_stuck_issue(workspace, agent, 60)

      # Subscribe to activity topic
      :ok = EventBus.subscribe(EventBus.activity_topic())

      {:ok, _} = StaleCleanup.run_now(server)

      assert_receive {:stale_cleanup, %{issues_reclaimed: n, sessions_failed: _}} when n >= 1,
                     1_000
    end

    test "does NOT broadcast when nothing was cleaned", %{server: server} do
      :ok = EventBus.subscribe(EventBus.activity_topic())

      {:ok, %{issues: 0, sessions: 0}} = StaleCleanup.run_now(server)

      refute_receive {:stale_cleanup, _}, 200
    end
  end

  describe "periodic :cleanup message" do
    test "handle_info(:cleanup, state) triggers cleanup cycle" do
      name = :"test_cleanup_periodic_#{System.unique_integer()}"

      {:ok, pid} =
        StaleCleanup.start_link(
          name: name,
          # Very long interval so auto-schedule doesn't interfere
          cleanup_interval: :timer.hours(24),
          issue_timeout_minutes: 30,
          session_timeout_minutes: 30
        )

      # Manually send :cleanup message
      send(pid, :cleanup)

      # Give it time to process
      Process.sleep(100)

      # Server should still be alive (didn't crash)
      assert Process.alive?(pid)

      GenServer.stop(pid, :normal)
    end
  end
end
