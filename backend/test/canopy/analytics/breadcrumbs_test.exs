defmodule Canopy.Analytics.BreadcrumbsTest do
  @moduledoc """
  Stress and correctness tests for the Breadcrumbs in-memory ring buffer.

  Targets:
  - Sequence monotonicity under concurrent writers (race we fixed)
  - Ring trim behaviour at the cap
  - flush_run persistence + buffer cleanup
  - Isolation between run_ids
  - count/list/drop semantics
  """

  use Canopy.DataCase, async: false

  alias Canopy.Analytics
  alias Canopy.Analytics.Breadcrumbs

  setup do
    # Tables are owned by the application's Breadcrumbs GenServer; we just
    # ensure each test starts with an empty buffer for the test run_id.
    :ok
  end

  describe "add/3" do
    test "adds a single breadcrumb with sequence 0" do
      run_id = Ecto.UUID.generate()

      :ok =
        Breadcrumbs.add(run_id, %{
          type: "tool_call",
          category: "read",
          level: "info"
        })

      [crumb] = Breadcrumbs.list(run_id)
      assert crumb.sequence == 0
      assert crumb.run_id == run_id
      assert crumb.type == "tool_call"

      Breadcrumbs.drop(run_id)
    end

    test "assigns monotonic sequence numbers" do
      run_id = Ecto.UUID.generate()

      for _ <- 1..5 do
        :ok = Breadcrumbs.add(run_id, %{type: "system"})
      end

      crumbs = Breadcrumbs.list(run_id)
      sequences = Enum.map(crumbs, & &1.sequence)
      assert sequences == [0, 1, 2, 3, 4]

      Breadcrumbs.drop(run_id)
    end

    test "auto-fills ts and level when omitted" do
      run_id = Ecto.UUID.generate()

      :ok = Breadcrumbs.add(run_id, %{type: "system"})

      [crumb] = Breadcrumbs.list(run_id)
      assert crumb.ts != nil
      assert crumb.level == "info"
      assert crumb.data == %{}

      Breadcrumbs.drop(run_id)
    end
  end

  describe "ring trim" do
    test "drops oldest when cap exceeded" do
      run_id = Ecto.UUID.generate()
      cap = 5

      for i <- 0..9 do
        :ok = Breadcrumbs.add(run_id, %{type: "system", message: "msg-#{i}"}, cap)
      end

      crumbs = Breadcrumbs.list(run_id)
      assert length(crumbs) == cap

      sequences = Enum.map(crumbs, & &1.sequence)
      assert sequences == [5, 6, 7, 8, 9]

      Breadcrumbs.drop(run_id)
    end

    test "respects hard_max cap (1000)" do
      run_id = Ecto.UUID.generate()
      huge = 100_000

      for _ <- 1..1005 do
        :ok = Breadcrumbs.add(run_id, %{type: "system"}, huge)
      end

      assert Breadcrumbs.count(run_id) == 1000

      Breadcrumbs.drop(run_id)
    end

    test "respects min cap of 1" do
      run_id = Ecto.UUID.generate()

      for _ <- 1..5 do
        :ok = Breadcrumbs.add(run_id, %{type: "system"}, 0)
      end

      assert Breadcrumbs.count(run_id) == 1

      Breadcrumbs.drop(run_id)
    end
  end

  describe "concurrency stress test" do
    test "10 concurrent writers, 100 adds each — no sequence collisions" do
      run_id = Ecto.UUID.generate()
      writers = 10
      per_writer = 100
      cap = 5000

      tasks =
        for _ <- 1..writers do
          Task.async(fn ->
            for _ <- 1..per_writer do
              :ok = Breadcrumbs.add(run_id, %{type: "system"}, cap)
            end
          end)
        end

      Enum.each(tasks, &Task.await(&1, 10_000))

      crumbs = Breadcrumbs.list(run_id)
      total = writers * per_writer

      # Without atomic counter we'd have collisions and end up with < total.
      assert length(crumbs) == total

      sequences = crumbs |> Enum.map(& &1.sequence) |> Enum.sort()

      # Sequences must be unique (no race-induced overwrites).
      assert sequences == Enum.uniq(sequences)
      assert length(sequences) == total

      # Sequences must be a contiguous monotonic range starting at 0.
      assert Enum.min(sequences) == 0
      assert Enum.max(sequences) == total - 1

      Breadcrumbs.drop(run_id)
    end

    test "concurrent writers across different run_ids do not interfere" do
      run_a = Ecto.UUID.generate()
      run_b = Ecto.UUID.generate()
      cap = 1000

      task_a =
        Task.async(fn ->
          for _ <- 1..50 do
            :ok = Breadcrumbs.add(run_a, %{type: "system"}, cap)
          end
        end)

      task_b =
        Task.async(fn ->
          for _ <- 1..70 do
            :ok = Breadcrumbs.add(run_b, %{type: "system"}, cap)
          end
        end)

      Task.await(task_a, 10_000)
      Task.await(task_b, 10_000)

      assert Breadcrumbs.count(run_a) == 50
      assert Breadcrumbs.count(run_b) == 70

      Breadcrumbs.drop(run_a)
      Breadcrumbs.drop(run_b)
    end
  end

  describe "flush_run/1" do
    test "persists buffered entries to DB and drops the buffer" do
      run_id = Ecto.UUID.generate()

      for _ <- 1..3 do
        :ok = Breadcrumbs.add(run_id, %{type: "tool_call", level: "info"})
      end

      assert {3, nil} = Breadcrumbs.flush_run(run_id)
      assert Breadcrumbs.count(run_id) == 0

      persisted = Analytics.list_breadcrumbs(run_id)
      assert length(persisted) == 3
    end

    test "returns :empty when buffer is empty" do
      run_id = Ecto.UUID.generate()
      assert :empty = Breadcrumbs.flush_run(run_id)
    end
  end

  describe "drop/1" do
    test "removes the buffer for a run_id without persisting" do
      run_id = Ecto.UUID.generate()

      for _ <- 1..3 do
        :ok = Breadcrumbs.add(run_id, %{type: "system"})
      end

      assert :ok = Breadcrumbs.drop(run_id)
      assert Breadcrumbs.count(run_id) == 0
      assert Analytics.list_breadcrumbs(run_id) == []
    end

    test "does not affect other runs" do
      run_a = Ecto.UUID.generate()
      run_b = Ecto.UUID.generate()

      :ok = Breadcrumbs.add(run_a, %{type: "system"})
      :ok = Breadcrumbs.add(run_b, %{type: "system"})

      Breadcrumbs.drop(run_a)

      assert Breadcrumbs.count(run_a) == 0
      assert Breadcrumbs.count(run_b) == 1

      Breadcrumbs.drop(run_b)
    end

    test "is idempotent" do
      run_id = Ecto.UUID.generate()
      assert :ok = Breadcrumbs.drop(run_id)
      assert :ok = Breadcrumbs.drop(run_id)
    end
  end

  describe "count/1" do
    test "returns 0 for an empty run" do
      assert Breadcrumbs.count(Ecto.UUID.generate()) == 0
    end

    test "matches list/1 length" do
      run_id = Ecto.UUID.generate()

      for _ <- 1..7 do
        :ok = Breadcrumbs.add(run_id, %{type: "system"})
      end

      assert Breadcrumbs.count(run_id) == length(Breadcrumbs.list(run_id))
      assert Breadcrumbs.count(run_id) == 7

      Breadcrumbs.drop(run_id)
    end
  end
end
