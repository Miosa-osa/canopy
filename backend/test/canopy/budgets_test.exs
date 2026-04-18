defmodule Canopy.BudgetsTest do
  @moduledoc """
  Integration tests for Canopy.Budgets — CRUD, current_spend, and 3-tier check enforcement.
  """

  use Canopy.DataCase, async: false

  import Canopy.Factory

  alias Canopy.Budgets
  alias Canopy.Budgets.Budget

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp budget_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        "scope_type" => "global",
        "scope_id" => nil,
        "period" => "monthly",
        "limit_usd" => "100.00",
        "soft_alert_pct" => 80,
        "hard_ceiling" => true,
        "enabled" => true
      },
      overrides
    )
  end

  defp insert_budget!(overrides \\ %{}) do
    {:ok, budget} = Budgets.create(budget_attrs(overrides))
    budget
  end

  # Insert a completed session with known cost
  defp insert_completed_session!(cost_usd, attrs \\ %{}) do
    session =
      insert(
        :session,
        Map.merge(
          %{
            status: "completed",
            completed_at: DateTime.utc_now(),
            cost_usd: Decimal.new(cost_usd)
          },
          attrs
        )
      )

    session
  end

  # ---------------------------------------------------------------------------
  # CRUD
  # ---------------------------------------------------------------------------

  describe "list/1" do
    test "returns empty list when no budgets exist" do
      assert {:ok, []} = Budgets.list()
    end

    test "returns all budgets" do
      insert_budget!()
      insert_budget!(%{"scope_type" => "agent", "scope_id" => Ecto.UUID.generate()})

      assert {:ok, budgets} = Budgets.list()
      assert length(budgets) == 2
    end

    test "filters by scope_type" do
      insert_budget!(%{"scope_type" => "agent", "scope_id" => Ecto.UUID.generate()})
      insert_budget!(%{"scope_type" => "workspace", "scope_id" => Ecto.UUID.generate()})

      assert {:ok, agent_budgets} = Budgets.list(scope_type: "agent")
      assert Enum.all?(agent_budgets, &(&1.scope_type == "agent"))
    end

    test "filters by enabled status" do
      insert_budget!(%{"enabled" => true})

      insert_budget!(%{
        "scope_type" => "agent",
        "scope_id" => Ecto.UUID.generate(),
        "enabled" => false
      })

      assert {:ok, enabled} = Budgets.list(enabled: true)
      assert Enum.all?(enabled, & &1.enabled)

      assert {:ok, disabled} = Budgets.list(enabled: false)
      assert Enum.all?(disabled, &(not &1.enabled))
    end
  end

  describe "get!/1" do
    test "returns budget by ID" do
      budget = insert_budget!()
      found = Budgets.get!(budget.id)
      assert found.id == budget.id
    end

    test "raises Ecto.NoResultsError for unknown ID" do
      assert_raise Ecto.NoResultsError, fn ->
        Budgets.get!(Ecto.UUID.generate())
      end
    end
  end

  describe "create/1" do
    test "creates a budget with required fields" do
      assert {:ok, %Budget{} = budget} = Budgets.create(budget_attrs())
      assert budget.scope_type == "global"
      assert budget.period == "monthly"
      assert Decimal.equal?(budget.limit_usd, Decimal.new("100.00"))
      assert budget.soft_alert_pct == 80
      assert budget.hard_ceiling == true
      assert budget.enabled == true
    end

    test "rejects invalid scope_type" do
      assert {:error, cs} = Budgets.create(budget_attrs(%{"scope_type" => "company"}))
      assert %{scope_type: [_ | _]} = errors_on(cs)
    end

    test "rejects invalid period" do
      assert {:error, cs} = Budgets.create(budget_attrs(%{"period" => "quarterly"}))
      assert %{period: [_ | _]} = errors_on(cs)
    end

    test "rejects zero limit_usd" do
      assert {:error, cs} = Budgets.create(budget_attrs(%{"limit_usd" => "0"}))
      assert %{limit_usd: [_ | _]} = errors_on(cs)
    end

    test "enforces unique (scope_type, scope_id, period)" do
      {:ok, _} = Budgets.create(budget_attrs())
      assert {:error, cs} = Budgets.create(budget_attrs())
      errors = errors_on(cs)
      # unique constraint fires on scope_type (global, nil scope_id) or period field
      assert Map.has_key?(errors, :scope_type) or Map.has_key?(errors, :period)
    end
  end

  describe "update/2" do
    test "updates limit_usd" do
      budget = insert_budget!()
      assert {:ok, updated} = Budgets.update(budget, %{"limit_usd" => "200.00"})
      assert Decimal.equal?(updated.limit_usd, Decimal.new("200.00"))
    end

    test "rejects invalid soft_alert_pct" do
      budget = insert_budget!()
      assert {:error, cs} = Budgets.update(budget, %{"soft_alert_pct" => 0})
      assert %{soft_alert_pct: [_ | _]} = errors_on(cs)
    end
  end

  describe "delete/1" do
    test "removes the budget" do
      budget = insert_budget!()
      assert {:ok, _} = Budgets.delete(budget)
      assert_raise Ecto.NoResultsError, fn -> Budgets.get!(budget.id) end
    end
  end

  describe "enable/1 and disable/1" do
    test "enable sets enabled: true" do
      budget = insert_budget!(%{"enabled" => false})
      assert {:ok, enabled} = Budgets.enable(budget)
      assert enabled.enabled == true
    end

    test "disable sets enabled: false" do
      budget = insert_budget!()
      assert {:ok, disabled} = Budgets.disable(budget)
      assert disabled.enabled == false
    end
  end

  # ---------------------------------------------------------------------------
  # current_spend/3
  # ---------------------------------------------------------------------------

  describe "current_spend/3" do
    test "returns 0 when no completed sessions exist" do
      assert {:ok, spend} = Budgets.current_spend("global", nil, "monthly")
      assert Decimal.equal?(spend, Decimal.new(0))
    end

    test "sums cost_usd for completed sessions in the period" do
      insert_completed_session!("30.00")
      insert_completed_session!("45.00")

      assert {:ok, spend} = Budgets.current_spend("global", nil, "monthly")
      assert Decimal.equal?(spend, Decimal.new("75.00"))
    end

    test "excludes sessions in non-completed status" do
      insert(:session, status: "running", cost_usd: Decimal.new("50.00"))
      insert_completed_session!("10.00")

      assert {:ok, spend} = Budgets.current_spend("global", nil, "monthly")
      assert Decimal.equal?(spend, Decimal.new("10.00"))
    end

    test "filters by agent scope (agent_slug)" do
      insert_completed_session!("20.00", %{agent_slug: "agent-x"})
      insert_completed_session!("30.00", %{agent_slug: "agent-y"})

      assert {:ok, spend} = Budgets.current_spend("agent", "agent-x", "monthly")
      assert Decimal.equal?(spend, Decimal.new("20.00"))
    end

    test "filters by workspace scope (workspace_slug)" do
      insert_completed_session!("15.00", %{workspace_slug: "ws-alpha"})
      insert_completed_session!("10.00", %{workspace_slug: "ws-beta"})

      assert {:ok, spend} = Budgets.current_spend("workspace", "ws-alpha", "monthly")
      assert Decimal.equal?(spend, Decimal.new("15.00"))
    end

    test "period total returns all completed sessions" do
      insert_completed_session!("50.00")
      assert {:ok, spend} = Budgets.current_spend("global", nil, "total")
      assert Decimal.compare(spend, Decimal.new("50.00")) == :eq
    end
  end

  # ---------------------------------------------------------------------------
  # check/3 — 3-tier enforcement
  # ---------------------------------------------------------------------------

  describe "check/3 — :ok tier" do
    test "returns :ok when no budgets exist" do
      assert :ok = Budgets.check("global", nil)
    end

    test "returns :ok when spent 75 of 100 limit (75% < 80% soft)" do
      insert_budget!(%{"limit_usd" => "100.00", "soft_alert_pct" => 80})
      insert_completed_session!("75.00")

      assert :ok = Budgets.check("global", nil)
    end

    test "returns :ok when spend is zero" do
      insert_budget!(%{"limit_usd" => "100.00"})
      assert :ok = Budgets.check("global", nil)
    end
  end

  describe "check/3 — :warn tier" do
    test "returns {:warn, ...} when spent 85 of 100 (85% >= 80%)" do
      insert_budget!(%{"limit_usd" => "100.00", "soft_alert_pct" => 80})
      insert_completed_session!("85.00")

      assert {:warn, budget, spent} = Budgets.check("global", nil)
      assert Decimal.equal?(spent, Decimal.new("85.00"))
      assert Decimal.equal?(budget.limit_usd, Decimal.new("100.00"))
    end

    test "returns {:warn, ...} when spent == soft threshold exactly" do
      insert_budget!(%{"limit_usd" => "100.00", "soft_alert_pct" => 80})
      insert_completed_session!("80.00")

      assert {:warn, _budget, _spent} = Budgets.check("global", nil)
    end

    test "returns {:warn, ...} when hard_ceiling false and spent 110 of 100" do
      insert_budget!(%{"limit_usd" => "100.00", "hard_ceiling" => false})
      insert_completed_session!("110.00")

      assert {:warn, budget, spent} = Budgets.check("global", nil)
      assert Decimal.compare(spent, Decimal.new("110.00")) == :eq
      assert Decimal.equal?(budget.limit_usd, Decimal.new("100.00"))
    end

    test "projected_cost pushes result into warn tier" do
      insert_budget!(%{"limit_usd" => "100.00", "soft_alert_pct" => 80})
      insert_completed_session!("70.00")

      # 70 + 15 = 85 >= 80%
      assert {:warn, _budget, spent} = Budgets.check("global", nil, Decimal.new("15.00"))
      assert Decimal.equal?(spent, Decimal.new("85.00"))
    end
  end

  describe "check/3 — :block tier" do
    test "returns {:block, ...} when spent 110 of 100 with hard_ceiling: true" do
      insert_budget!(%{"limit_usd" => "100.00", "hard_ceiling" => true})
      insert_completed_session!("110.00")

      assert {:block, budget, spent} = Budgets.check("global", nil)
      assert Decimal.compare(spent, Decimal.new("110.00")) == :eq
      assert Decimal.equal?(budget.limit_usd, Decimal.new("100.00"))
    end

    test "returns {:block, ...} when spend equals limit exactly with hard_ceiling: true" do
      insert_budget!(%{"limit_usd" => "100.00", "hard_ceiling" => true})
      insert_completed_session!("100.00")

      assert {:block, _budget, _spent} = Budgets.check("global", nil)
    end

    test "projected_cost pushes result into block tier" do
      insert_budget!(%{"limit_usd" => "100.00", "hard_ceiling" => true})
      insert_completed_session!("95.00")

      # 95 + 10 = 105 >= 100 -> block
      assert {:block, _budget, spent} = Budgets.check("global", nil, Decimal.new("10.00"))
      assert Decimal.equal?(spent, Decimal.new("105.00"))
    end
  end

  describe "check/3 — disabled budgets" do
    test "ignores disabled budgets" do
      insert_budget!(%{"limit_usd" => "10.00", "enabled" => false})
      insert_completed_session!("100.00")

      # Disabled budget should not trigger block
      assert :ok = Budgets.check("global", nil)
    end
  end

  # ---------------------------------------------------------------------------
  # snapshot_all/0
  # ---------------------------------------------------------------------------

  describe "snapshot_all/0" do
    test "inserts one snapshot per enabled budget" do
      insert_budget!()
      insert_budget!(%{"scope_type" => "agent", "scope_id" => Ecto.UUID.generate()})

      assert {:ok, 2} = Budgets.snapshot_all()
    end

    test "returns 0 when no enabled budgets exist" do
      insert_budget!(%{"enabled" => false})
      assert {:ok, 0} = Budgets.snapshot_all()
    end

    test "snapshot records the current spend" do
      insert_budget!()
      insert_completed_session!("42.00")

      {:ok, 1} = Budgets.snapshot_all()

      [snap] = Repo.all(Canopy.Budgets.SpendSnapshot)
      assert Decimal.equal?(snap.actual_spend_usd, Decimal.new("42.00"))
    end
  end
end
