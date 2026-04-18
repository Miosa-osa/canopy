defmodule Canopy.Budgets.SnapshotterTest do
  @moduledoc """
  Tests for Canopy.Budgets.Snapshotter Oban worker.
  """

  use Canopy.DataCase, async: false

  import Canopy.Factory

  alias Canopy.Budgets
  alias Canopy.Budgets.{SpendSnapshot, Snapshotter}

  defp insert_budget!(overrides \\ %{}) do
    {:ok, budget} =
      Budgets.create(
        Map.merge(
          %{
            "scope_type" => "global",
            "scope_id" => nil,
            "period" => "monthly",
            "limit_usd" => "500.00",
            "enabled" => true
          },
          overrides
        )
      )

    budget
  end

  describe "perform/1" do
    test "returns :ok when there are no enabled budgets" do
      assert :ok = Snapshotter.perform(%Oban.Job{args: %{}})
    end

    test "returns :ok and inserts snapshots for all enabled budgets" do
      insert_budget!()
      insert_budget!(%{"scope_type" => "agent", "scope_id" => Ecto.UUID.generate()})

      assert :ok = Snapshotter.perform(%Oban.Job{args: %{}})

      count = Repo.aggregate(SpendSnapshot, :count)
      assert count == 2
    end

    test "skips disabled budgets" do
      insert_budget!(%{"enabled" => false})

      assert :ok = Snapshotter.perform(%Oban.Job{args: %{}})

      assert Repo.aggregate(SpendSnapshot, :count) == 0
    end

    test "records actual spend in snapshots" do
      insert_budget!()

      insert(:session,
        status: "completed",
        completed_at: DateTime.utc_now(),
        cost_usd: Decimal.new("33.00")
      )

      assert :ok = Snapshotter.perform(%Oban.Job{args: %{}})

      [snap] = Repo.all(SpendSnapshot)
      assert Decimal.equal?(snap.actual_spend_usd, Decimal.new("33.00"))
    end

    test "is idempotent — multiple calls append multiple snapshots (append-only)" do
      insert_budget!()

      assert :ok = Snapshotter.perform(%Oban.Job{args: %{}})
      assert :ok = Snapshotter.perform(%Oban.Job{args: %{}})

      assert Repo.aggregate(SpendSnapshot, :count) == 2
    end
  end
end
