defmodule Canopy.Sessions.BlocksTest do
  @moduledoc """
  Tests for the `Canopy.Sessions.Blocks` context — CRUD, filtering,
  aggregation, sequence monotonicity, and parent_block_id integrity.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Sessions.{Block, Blocks, Session}

  defp create_session! do
    {:ok, session} =
      Canopy.Repo.insert(
        Session.changeset(%Session{}, %{runtime_type: "claude-local", cwd: "/tmp"})
      )

    session
  end

  defp create_block!(session, attrs \\ %{}) do
    base = %{session_id: session.id, kind: "command"}
    {:ok, block} = Blocks.create(Map.merge(base, attrs))
    block
  end

  # ---------------------------------------------------------------------------
  # create/1 — happy path + sequence assignment
  # ---------------------------------------------------------------------------

  describe "create/1" do
    test "creates a block with auto-assigned sequence 0" do
      session = create_session!()

      assert {:ok, %Block{} = b} =
               Blocks.create(%{session_id: session.id, kind: "command", input_text: "ls"})

      assert b.sequence == 0
      assert b.kind == "command"
      assert b.status == "running"
      assert b.started_at != nil
    end

    test "auto-fills started_at when missing" do
      session = create_session!()
      {:ok, b} = Blocks.create(%{session_id: session.id, kind: "agent_message"})
      assert b.started_at != nil
      assert DateTime.diff(DateTime.utc_now(), b.started_at, :second) < 5
    end

    test "rejects invalid kind" do
      session = create_session!()
      assert {:error, cs} = Blocks.create(%{session_id: session.id, kind: "nonsense"})
      assert "is invalid" in errors_on(cs).kind
    end

    test "rejects invalid status" do
      session = create_session!()

      assert {:error, cs} =
               Blocks.create(%{session_id: session.id, kind: "command", status: "weird"})

      assert "is invalid" in errors_on(cs).status
    end

    test "rejects negative cost_cents" do
      session = create_session!()

      assert {:error, cs} =
               Blocks.create(%{session_id: session.id, kind: "command", cost_cents: -1})

      refute Enum.empty?(errors_on(cs).cost_cents)
    end
  end

  # ---------------------------------------------------------------------------
  # Sequence monotonicity
  # ---------------------------------------------------------------------------

  describe "sequence monotonicity" do
    test "sequences increment monotonically per session" do
      session = create_session!()

      blocks =
        for _ <- 1..5 do
          {:ok, b} = Blocks.create(%{session_id: session.id, kind: "command"})
          b
        end

      assert Enum.map(blocks, & &1.sequence) == [0, 1, 2, 3, 4]
    end

    test "sequences are independent per session" do
      a = create_session!()
      b = create_session!()

      {:ok, a1} = Blocks.create(%{session_id: a.id, kind: "command"})
      {:ok, b1} = Blocks.create(%{session_id: b.id, kind: "command"})
      {:ok, a2} = Blocks.create(%{session_id: a.id, kind: "command"})

      assert a1.sequence == 0
      assert a2.sequence == 1
      assert b1.sequence == 0
    end

    test "explicit sequence is honoured when provided" do
      session = create_session!()
      {:ok, b} = Blocks.create(%{session_id: session.id, kind: "command", sequence: 42})
      assert b.sequence == 42
    end

    test "duplicate (session_id, sequence) is rejected" do
      session = create_session!()
      {:ok, _} = Blocks.create(%{session_id: session.id, kind: "command", sequence: 5})

      assert {:error, _cs} =
               Blocks.create(%{session_id: session.id, kind: "command", sequence: 5})
    end
  end

  # ---------------------------------------------------------------------------
  # parent_block_id integrity
  # ---------------------------------------------------------------------------

  describe "parent_block_id integrity" do
    test "tool_call can nest under an agent_message" do
      session = create_session!()
      parent = create_block!(session, %{kind: "agent_message"})

      assert {:ok, child} =
               Blocks.create(%{
                 session_id: session.id,
                 kind: "tool_call",
                 parent_block_id: parent.id
               })

      assert child.parent_block_id == parent.id
    end

    test "list with parent_block_id filter returns only children" do
      session = create_session!()
      parent = create_block!(session, %{kind: "agent_message"})
      _sibling = create_block!(session, %{kind: "agent_message"})

      {:ok, child1} =
        Blocks.create(%{session_id: session.id, kind: "tool_call", parent_block_id: parent.id})

      {:ok, child2} =
        Blocks.create(%{session_id: session.id, kind: "tool_result", parent_block_id: parent.id})

      children = Blocks.list(session_id: session.id, parent_block_id: parent.id)
      ids = Enum.map(children, & &1.id) |> Enum.sort()
      assert ids == Enum.sort([child1.id, child2.id])
    end
  end

  # ---------------------------------------------------------------------------
  # list/1 + filtering
  # ---------------------------------------------------------------------------

  describe "list/1" do
    setup do
      session = create_session!()
      _b0 = create_block!(session, %{kind: "command"})
      _b1 = create_block!(session, %{kind: "agent_message"})
      _b2 = create_block!(session, %{kind: "tool_call", status: "failed"})
      {:ok, session: session}
    end

    test "returns blocks ordered by sequence asc", %{session: session} do
      blocks = Blocks.list(session_id: session.id)
      assert Enum.map(blocks, & &1.sequence) == [0, 1, 2]
    end

    test "filters by kind", %{session: session} do
      [b] = Blocks.list(session_id: session.id, kind: "agent_message")
      assert b.kind == "agent_message"
    end

    test "filters by status", %{session: session} do
      [b] = Blocks.list(session_id: session.id, status: "failed")
      assert b.status == "failed"
    end

    test "respects limit", %{session: session} do
      blocks = Blocks.list(session_id: session.id, limit: 2)
      assert length(blocks) == 2
    end

    test "since filter", %{session: session} do
      future = DateTime.add(DateTime.utc_now(), 60, :second)
      assert Blocks.list(session_id: session.id, since: future) == []
    end
  end

  # ---------------------------------------------------------------------------
  # get/1
  # ---------------------------------------------------------------------------

  describe "get/1" do
    test "returns the block when found" do
      session = create_session!()
      b = create_block!(session)
      assert %Block{id: id} = Blocks.get(b.id)
      assert id == b.id
    end

    test "returns nil for unknown id" do
      assert Blocks.get(Ecto.UUID.generate()) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # update_status / mark_finished
  # ---------------------------------------------------------------------------

  describe "update_status/2 and mark_finished/2" do
    test "update_status changes status only" do
      session = create_session!()
      b = create_block!(session)

      assert {:ok, updated} = Blocks.update_status(b, %{status: "completed"})
      assert updated.status == "completed"
    end

    test "mark_finished sets ended_at + duration_ms + status=completed" do
      session = create_session!()
      b = create_block!(session)
      Process.sleep(10)

      assert {:ok, finished} = Blocks.mark_finished(b)
      assert finished.status == "completed"
      assert finished.ended_at != nil
      assert is_integer(finished.duration_ms) and finished.duration_ms >= 0
    end

    test "mark_finished accepts override status + exit_code + cost_cents" do
      session = create_session!()
      b = create_block!(session)

      assert {:ok, finished} =
               Blocks.mark_finished(b, %{
                 status: "failed",
                 exit_code: 1,
                 cost_cents: 25,
                 output_text: "oops"
               })

      assert finished.status == "failed"
      assert finished.exit_code == 1
      assert finished.cost_cents == 25
      assert finished.output_text == "oops"
    end
  end

  # ---------------------------------------------------------------------------
  # aggregate_by_kind / count
  # ---------------------------------------------------------------------------

  describe "aggregate_by_kind/1 and count/1" do
    test "buckets counts by kind" do
      session = create_session!()
      create_block!(session, %{kind: "command"})
      create_block!(session, %{kind: "command"})
      create_block!(session, %{kind: "agent_message"})

      agg = Blocks.aggregate_by_kind(session.id)
      assert agg["command"] == 2
      assert agg["agent_message"] == 1
    end

    test "count with filters" do
      session = create_session!()
      create_block!(session, %{kind: "command", status: "failed"})
      create_block!(session, %{kind: "command", status: "completed"})

      assert Blocks.count(session_id: session.id) == 2
      assert Blocks.count(session_id: session.id, status: "failed") == 1
    end
  end

  # ---------------------------------------------------------------------------
  # find_pending_approval
  # ---------------------------------------------------------------------------

  describe "find_pending_approval/1" do
    test "returns the pending block, or nil" do
      session = create_session!()
      assert Blocks.find_pending_approval(session.id) == nil

      {:ok, b} =
        Blocks.create(%{session_id: session.id, kind: "approval", status: "pending_approval"})

      assert %Block{id: id} = Blocks.find_pending_approval(session.id)
      assert id == b.id
    end
  end

  # ---------------------------------------------------------------------------
  # search/1
  # ---------------------------------------------------------------------------

  describe "search/1" do
    test "filters by tag" do
      session = create_session!()
      create_block!(session, %{tags: ["pinned"]})
      create_block!(session, %{tags: []})

      [b] = Blocks.search(session_id: session.id, tag: "pinned")
      assert b.tags == ["pinned"]
    end

    test "free-text query searches input + output" do
      session = create_session!()
      create_block!(session, %{input_text: "ls -la"})
      create_block!(session, %{output_text: "deployment failed"})
      create_block!(session, %{input_text: "echo hi"})

      results = Blocks.search(session_id: session.id, q: "deploy")
      assert length(results) == 1
    end

    test "combines kind + status + tag" do
      session = create_session!()

      create_block!(session, %{
        kind: "command",
        status: "completed",
        tags: ["important"]
      })

      create_block!(session, %{kind: "command", status: "failed", tags: ["important"]})

      results =
        Blocks.search(
          session_id: session.id,
          kind: "command",
          status: "completed",
          tag: "important"
        )

      assert length(results) == 1
    end
  end
end
