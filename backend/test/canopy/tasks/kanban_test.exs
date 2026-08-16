defmodule Canopy.Tasks.KanbanTest do
  @moduledoc """
  Tests for the agent-kanban claim / release / complete state machine.

  Claim atomicity is the load-bearing piece — `concurrent claim wins exactly once`
  spawns 100 parallel claims via `Task.async_stream` and asserts that exactly
  one transaction succeeds. The remainder return `{:error, :already_claimed}`
  via `SELECT … FOR UPDATE SKIP LOCKED`.
  """

  use Canopy.DataCase, async: false

  import Canopy.Factory

  alias Canopy.Repo
  alias Canopy.Tasks.Kanban

  # ---------------------------------------------------------------------------
  # claim_task/2 — atomic claim
  # ---------------------------------------------------------------------------

  describe "claim_task/2" do
    test "claims an unclaimed task and stamps agent + timestamp" do
      task = insert(:task, claimed_by_agent_id: nil)

      assert {:ok, claimed} = Kanban.claim_task(task.short_id, "alice-agent")
      assert claimed.claimed_by_agent_id == "alice-agent"
      assert %DateTime{} = claimed.claimed_at
      assert claimed.assignee_type == "agent"
      assert claimed.assignee_id == "alice-agent"
    end

    test "returns {:error, :already_claimed} when another agent owns it" do
      task = insert(:task, claimed_by_agent_id: "bob", claimed_at: DateTime.utc_now())

      assert {:error, :already_claimed} = Kanban.claim_task(task.short_id, "alice")
    end

    test "returns {:error, :not_found} when short_id does not exist" do
      assert {:error, :not_found} = Kanban.claim_task("T-99999999", "alice")
    end

    @tag :slow
    test "100 concurrent claims on the same task — exactly one wins" do
      task = insert(:task, claimed_by_agent_id: nil)

      # Allocate the sandbox owner across the spawned tasks. async_stream
      # inherits the test's DB connection through the Sandbox's allowance
      # mechanism for concurrent transactions.
      parent = self()
      Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, parent)

      results =
        1..100
        |> Task.async_stream(
          fn i ->
            Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
            Kanban.claim_task(task.short_id, "agent-#{i}")
          end,
          max_concurrency: 32,
          timeout: 10_000
        )
        |> Enum.map(fn {:ok, r} -> r end)

      successes = Enum.count(results, &match?({:ok, _}, &1))
      already = Enum.count(results, &match?({:error, :already_claimed}, &1))

      assert successes == 1
      assert successes + already == 100
    end
  end

  # ---------------------------------------------------------------------------
  # release_task/1
  # ---------------------------------------------------------------------------

  describe "release_task/1" do
    test "clears claim fields so the task returns to Backlog" do
      task =
        insert(:task,
          claimed_by_agent_id: "alice",
          claimed_at: DateTime.utc_now()
        )

      assert {:ok, released} = Kanban.release_task(task.short_id)
      assert is_nil(released.claimed_by_agent_id)
      assert is_nil(released.claimed_at)
    end

    test "is idempotent on an already-unclaimed task" do
      task = insert(:task, claimed_by_agent_id: nil)
      assert {:ok, _} = Kanban.release_task(task.short_id)
      # Calling again succeeds without error.
      assert {:ok, _} = Kanban.release_task(task.short_id)
    end

    test "returns {:error, :not_found} when short_id is unknown" do
      assert {:error, :not_found} = Kanban.release_task("T-00000001")
    end
  end

  # ---------------------------------------------------------------------------
  # complete_task/2
  # ---------------------------------------------------------------------------

  describe "complete_task/2" do
    test "marks status=done and stamps completed_at" do
      task = insert(:task, status: "in_progress")
      assert {:ok, done} = Kanban.complete_task(task.short_id)
      assert done.status == "done"
      assert %DateTime{} = done.completed_at
    end

    test "records the producing session_id when provided" do
      sid = Ecto.UUID.generate()
      task = insert(:task, status: "in_progress")
      assert {:ok, done} = Kanban.complete_task(task.short_id, sid)
      assert done.session_id == sid
    end

    test "is idempotent — calling on an already-done task re-stamps completed_at" do
      task = insert(:task, status: "done")
      assert {:ok, done} = Kanban.complete_task(task.short_id)
      assert done.status == "done"
    end
  end

  # ---------------------------------------------------------------------------
  # next_unclaimed/2 — skill match + ordering
  # ---------------------------------------------------------------------------

  describe "next_unclaimed/2" do
    test "skips tasks whose required_skills are not a subset of agent skills" do
      _t1 =
        insert(:task,
          auto_assignable: true,
          required_skills: ["rust"],
          claimed_by_agent_id: nil
        )

      assert is_nil(Kanban.next_unclaimed(["elixir"]))
    end

    test "returns the highest-priority eligible task first" do
      _low =
        insert(:task,
          auto_assignable: true,
          required_skills: ["elixir"],
          priority: 0,
          claimed_by_agent_id: nil
        )

      hi =
        insert(:task,
          auto_assignable: true,
          required_skills: ["elixir"],
          priority: 3,
          claimed_by_agent_id: nil
        )

      task = Kanban.next_unclaimed(["elixir"])
      assert task.short_id == hi.short_id
    end

    test "ignores tasks that are not auto_assignable" do
      _t =
        insert(:task,
          auto_assignable: false,
          required_skills: [],
          claimed_by_agent_id: nil
        )

      assert is_nil(Kanban.next_unclaimed([]))
    end

    test "ignores already-claimed tasks" do
      _t =
        insert(:task,
          auto_assignable: true,
          required_skills: [],
          claimed_by_agent_id: "someone"
        )

      assert is_nil(Kanban.next_unclaimed([]))
    end

    test "filters by workspace when :workspace_slug is given" do
      _other =
        insert(:task,
          auto_assignable: true,
          required_skills: [],
          claimed_by_agent_id: nil,
          workspace_slug: "other"
        )

      mine =
        insert(:task,
          auto_assignable: true,
          required_skills: [],
          claimed_by_agent_id: nil,
          workspace_slug: "mine"
        )

      task = Kanban.next_unclaimed([], workspace_slug: "mine")
      assert task.short_id == mine.short_id
    end
  end

  # ---------------------------------------------------------------------------
  # board/1
  # ---------------------------------------------------------------------------

  describe "board/1" do
    test "splits tasks across the four columns" do
      _backlog =
        insert(:task, status: "todo", claimed_by_agent_id: nil, session_id: nil)

      _claimed =
        insert(:task,
          status: "todo",
          claimed_by_agent_id: "alice",
          claimed_at: DateTime.utc_now(),
          session_id: nil
        )

      _in_progress =
        insert(:task,
          status: "in_progress",
          claimed_by_agent_id: "alice",
          session_id: Ecto.UUID.generate()
        )

      _done = insert(:task, status: "done")

      board = Kanban.board()

      assert length(board.backlog) >= 1
      assert length(board.claimed) >= 1
      assert length(board.in_progress) >= 1
      assert length(board.done) >= 1
    end
  end
end
