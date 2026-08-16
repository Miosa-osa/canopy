defmodule Canopy.HeartbeatsTest do
  @moduledoc "Context tests for Canopy.Heartbeats."

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Heartbeats
  alias Canopy.Heartbeats.Heartbeat

  # ---------------------------------------------------------------------------
  # Changeset
  # ---------------------------------------------------------------------------

  describe "Heartbeat.changeset/2" do
    test "valid with required fields" do
      session_id = Ecto.UUID.generate()
      cs = Heartbeat.changeset(%Heartbeat{}, %{session_id: session_id, kind: :output})
      assert cs.valid?
    end

    test "invalid without session_id" do
      cs = Heartbeat.changeset(%Heartbeat{}, %{kind: :output})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).session_id
    end

    test "invalid without kind" do
      cs = Heartbeat.changeset(%Heartbeat{}, %{session_id: Ecto.UUID.generate()})
      refute cs.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # record/4 — basic insert
  # ---------------------------------------------------------------------------

  describe "record/4 insert" do
    test "inserts a new output heartbeat" do
      session_id = Ecto.UUID.generate()
      assert {:ok, hb} = Heartbeats.record(session_id, :output, "hello world")
      assert hb.session_id == session_id
      assert hb.kind == :output
      assert hb.byte_count == byte_size("hello world")
      assert hb.preview == "hello world"
    end

    test "inserts input heartbeat" do
      session_id = Ecto.UUID.generate()
      assert {:ok, hb} = Heartbeats.record(session_id, :input, "ls -la\n")
      assert hb.kind == :input
    end

    test "inserts exit heartbeat with meta" do
      session_id = Ecto.UUID.generate()
      assert {:ok, hb} = Heartbeats.record(session_id, :exit, "", %{"exit_code" => 0})
      assert hb.kind == :exit
      assert hb.meta["exit_code"] == 0
    end

    test "inserts pause and resume heartbeats" do
      session_id = Ecto.UUID.generate()
      assert {:ok, p} = Heartbeats.record(session_id, :pause, "")
      assert {:ok, r} = Heartbeats.record(session_id, :resume, "")
      assert p.kind == :pause
      assert r.kind == :resume
    end

    test "truncates preview to 200 bytes" do
      session_id = Ecto.UUID.generate()
      big = String.duplicate("x", 500)
      assert {:ok, hb} = Heartbeats.record(session_id, :output, big)
      assert byte_size(hb.preview) == 200
    end

    test "byte_count equals full payload size even when preview is truncated" do
      session_id = Ecto.UUID.generate()
      big = String.duplicate("y", 500)
      assert {:ok, hb} = Heartbeats.record(session_id, :output, big)
      assert hb.byte_count == 500
    end
  end

  # ---------------------------------------------------------------------------
  # record/4 — coalescence
  # ---------------------------------------------------------------------------

  describe "record/4 coalescence (output within 500ms)" do
    test "second output in same window updates byte_count, not inserts" do
      session_id = Ecto.UUID.generate()

      assert {:ok, first} = Heartbeats.record(session_id, :output, "aaa")
      assert {:ok, second} = Heartbeats.record(session_id, :output, "bb")

      # second should be the same row (updated), not a new insert
      assert second.id == first.id
      # byte_count should be additive
      assert second.byte_count == byte_size("aaa") + byte_size("bb")
    end

    test "input kind is never coalesced — always inserts new row" do
      session_id = Ecto.UUID.generate()

      assert {:ok, first} = Heartbeats.record(session_id, :input, "cmd1\n")
      assert {:ok, second} = Heartbeats.record(session_id, :input, "cmd2\n")

      assert first.id != second.id
    end

    test "exit kind always inserts new row" do
      session_id = Ecto.UUID.generate()

      assert {:ok, first} = Heartbeats.record(session_id, :exit, "")
      assert {:ok, second} = Heartbeats.record(session_id, :exit, "")

      assert first.id != second.id
    end

    test "different sessions do not coalesce" do
      s1 = Ecto.UUID.generate()
      s2 = Ecto.UUID.generate()

      assert {:ok, hb1} = Heartbeats.record(s1, :output, "aaa")
      assert {:ok, hb2} = Heartbeats.record(s2, :output, "bbb")

      assert hb1.id != hb2.id
      assert hb1.byte_count == byte_size("aaa")
      assert hb2.byte_count == byte_size("bbb")
    end
  end

  # ---------------------------------------------------------------------------
  # list_for_session/2
  # ---------------------------------------------------------------------------

  describe "list_for_session/2" do
    test "returns heartbeats most-recent-first" do
      session_id = Ecto.UUID.generate()

      insert(:heartbeat, session_id: session_id, kind: :output, inserted_at: ago(10, :second))
      insert(:heartbeat, session_id: session_id, kind: :input, inserted_at: ago(5, :second))
      insert(:heartbeat, session_id: session_id, kind: :exit, inserted_at: ago(1, :second))

      results = Heartbeats.list_for_session(session_id)
      kinds = Enum.map(results, & &1.kind)

      assert kinds == [:exit, :input, :output]
    end

    test "respects limit" do
      session_id = Ecto.UUID.generate()
      for _ <- 1..5, do: insert(:heartbeat, session_id: session_id)

      assert length(Heartbeats.list_for_session(session_id, limit: 2)) == 2
    end

    test "excludes other sessions" do
      s1 = Ecto.UUID.generate()
      s2 = Ecto.UUID.generate()

      insert(:heartbeat, session_id: s1)
      insert(:heartbeat, session_id: s2)

      result = Heartbeats.list_for_session(s1)
      assert length(result) == 1
      assert hd(result).session_id == s1
    end
  end

  # ---------------------------------------------------------------------------
  # stats/1
  # ---------------------------------------------------------------------------

  describe "stats/1" do
    test "returns correct byte sums and timing" do
      session_id = Ecto.UUID.generate()
      t1 = DateTime.add(DateTime.utc_now(), -60, :second)
      t2 = DateTime.utc_now()

      insert(:heartbeat, session_id: session_id, kind: :output, byte_count: 100, inserted_at: t1)
      insert(:heartbeat, session_id: session_id, kind: :output, byte_count: 200, inserted_at: t2)
      insert(:heartbeat, session_id: session_id, kind: :input, byte_count: 10, inserted_at: t2)

      stats = Heartbeats.stats(session_id)

      assert stats.total_output_bytes == 300
      assert stats.total_input_bytes == 10
      assert stats.heartbeat_count == 3
      assert stats.started_at != nil
      assert stats.last_activity_at != nil
    end

    test "returns zeros for session with no heartbeats" do
      stats = Heartbeats.stats(Ecto.UUID.generate())
      assert stats.total_output_bytes == 0
      assert stats.total_input_bytes == 0
      assert stats.heartbeat_count == 0
      assert stats.started_at == nil
      assert stats.last_activity_at == nil
    end
  end

  # ---------------------------------------------------------------------------
  # list_for_workspace/2
  # ---------------------------------------------------------------------------

  describe "list_for_workspace/2" do
    test "returns heartbeats for sessions in the workspace" do
      session = insert(:session, workspace_slug: "test-ws")

      insert(:heartbeat, session_id: session.id)
      insert(:heartbeat, session_id: session.id)

      # Different workspace
      other_session = insert(:session, workspace_slug: "other-ws")
      insert(:heartbeat, session_id: other_session.id)

      results = Heartbeats.list_for_workspace("test-ws")
      assert length(results) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp ago(n, unit) do
    DateTime.add(DateTime.utc_now(), -n, unit)
  end
end
