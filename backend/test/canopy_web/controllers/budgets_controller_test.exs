defmodule CanopyWeb.BudgetsControllerTest do
  @moduledoc """
  Tests for BudgetsController endpoints:
    GET    /api/v1/budgets
    POST   /api/v1/budgets
    GET    /api/v1/budgets/:id
    PUT    /api/v1/budgets/:id
    DELETE /api/v1/budgets/:id
    GET    /api/v1/budgets/:id/spend
    POST   /api/v1/budgets/:id/check
  """

  use CanopyWeb.ConnCase, async: false

  import Canopy.Factory

  alias Canopy.Budgets

  defp create_budget!(overrides \\ %{}) do
    {:ok, budget} =
      Budgets.create(
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
      )

    budget
  end

  defp insert_completed_session!(cost_usd, attrs \\ %{}) do
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
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/budgets
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/budgets" do
    test "returns 200 with empty list when no budgets exist", %{conn: conn} do
      conn = get(conn, "/api/v1/budgets")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns all budgets", %{conn: conn} do
      create_budget!()
      create_budget!(%{"scope_type" => "agent", "scope_id" => Ecto.UUID.generate()})
      conn = get(conn, "/api/v1/budgets")
      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) == 2
    end

    test "filters by scope_type query param", %{conn: conn} do
      create_budget!(%{"scope_type" => "agent", "scope_id" => Ecto.UUID.generate()})
      create_budget!(%{"scope_type" => "workspace", "scope_id" => Ecto.UUID.generate()})

      conn = get(conn, "/api/v1/budgets?scope_type=agent")
      assert %{"data" => data} = json_response(conn, 200)
      assert Enum.all?(data, &(&1["scope_type"] == "agent"))
    end

    test "filters by enabled query param", %{conn: conn} do
      create_budget!(%{"enabled" => true})

      create_budget!(%{
        "scope_type" => "agent",
        "scope_id" => Ecto.UUID.generate(),
        "enabled" => false
      })

      conn = get(conn, "/api/v1/budgets?enabled=true")
      assert %{"data" => data} = json_response(conn, 200)
      assert Enum.all?(data, & &1["enabled"])
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/budgets
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/budgets" do
    test "creates a budget and returns 201", %{conn: conn} do
      params = %{
        scope_type: "global",
        period: "monthly",
        limit_usd: "250.00"
      }

      conn = post(conn, "/api/v1/budgets", params)
      assert body = json_response(conn, 201)
      assert body["scope_type"] == "global"
      assert body["period"] == "monthly"
      assert body["hard_ceiling"] == true
      assert body["enabled"] == true
    end

    test "returns 422 for invalid scope_type", %{conn: conn} do
      params = %{scope_type: "company", period: "monthly", limit_usd: "100.00"}
      conn = post(conn, "/api/v1/budgets", params)
      assert json_response(conn, 422)
    end

    test "returns 422 for missing required fields", %{conn: conn} do
      conn = post(conn, "/api/v1/budgets", %{})
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/budgets/:id
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/budgets/:id" do
    test "returns 200 with budget detail", %{conn: conn} do
      budget = create_budget!()
      conn = get(conn, "/api/v1/budgets/#{budget.id}")
      body = json_response(conn, 200)
      assert body["id"] == budget.id
      assert body["scope_type"] == "global"
    end

    test "returns 404 for unknown ID", %{conn: conn} do
      conn = get(conn, "/api/v1/budgets/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /api/v1/budgets/:id
  # ---------------------------------------------------------------------------

  describe "PUT /api/v1/budgets/:id" do
    test "updates limit_usd", %{conn: conn} do
      budget = create_budget!()
      conn = put(conn, "/api/v1/budgets/#{budget.id}", %{limit_usd: "500.00"})
      body = json_response(conn, 200)
      # JSON-encoded Decimal may vary in trailing zeros; compare as Decimal
      assert Decimal.equal?(Decimal.new(body["limit_usd"]), Decimal.new("500.00"))
    end

    test "returns 404 for unknown ID", %{conn: conn} do
      conn = put(conn, "/api/v1/budgets/#{Ecto.UUID.generate()}", %{limit_usd: "500.00"})
      assert json_response(conn, 404)
    end

    test "returns 422 for invalid update", %{conn: conn} do
      budget = create_budget!()
      conn = put(conn, "/api/v1/budgets/#{budget.id}", %{limit_usd: "-1"})
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/budgets/:id
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/budgets/:id" do
    test "deletes the budget and returns it", %{conn: conn} do
      budget = create_budget!()
      conn = delete(conn, "/api/v1/budgets/#{budget.id}")
      body = json_response(conn, 200)
      assert body["id"] == budget.id
    end

    test "returns 404 for unknown ID", %{conn: conn} do
      conn = delete(conn, "/api/v1/budgets/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/budgets/:id/spend
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/budgets/:id/spend" do
    test "returns current_spend_usd and empty snapshots list", %{conn: conn} do
      budget = create_budget!()
      conn = get(conn, "/api/v1/budgets/#{budget.id}/spend")
      body = json_response(conn, 200)
      assert Map.has_key?(body, "current_spend_usd")
      assert body["snapshots"] == []
    end

    test "returns 404 for unknown budget", %{conn: conn} do
      conn = get(conn, "/api/v1/budgets/#{Ecto.UUID.generate()}/spend")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/budgets/:id/check
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/budgets/:id/check — ok tier" do
    test "returns ok when spend is 75 of 100 limit", %{conn: conn} do
      budget = create_budget!(%{"limit_usd" => "100.00", "soft_alert_pct" => 80})
      insert_completed_session!("75.00")

      conn = post(conn, "/api/v1/budgets/#{budget.id}/check", %{projected_cost: "0.00"})
      body = json_response(conn, 200)
      assert body["result"] == "ok"
    end
  end

  describe "POST /api/v1/budgets/:id/check — warn tier" do
    test "returns warn when spend is 85 of 100", %{conn: conn} do
      budget = create_budget!(%{"limit_usd" => "100.00", "soft_alert_pct" => 80})
      insert_completed_session!("85.00")

      conn = post(conn, "/api/v1/budgets/#{budget.id}/check", %{projected_cost: "0"})
      body = json_response(conn, 200)
      assert body["result"] == "warn"
      assert body["budget_id"] == budget.id
    end

    test "returns warn when hard_ceiling false and spend is 110 of 100", %{conn: conn} do
      budget = create_budget!(%{"limit_usd" => "100.00", "hard_ceiling" => false})
      insert_completed_session!("110.00")

      conn = post(conn, "/api/v1/budgets/#{budget.id}/check", %{projected_cost: "0"})
      body = json_response(conn, 200)
      assert body["result"] == "warn"
    end
  end

  describe "POST /api/v1/budgets/:id/check — block tier" do
    test "returns block when spend is 110 of 100 with hard_ceiling true", %{conn: conn} do
      budget = create_budget!(%{"limit_usd" => "100.00", "hard_ceiling" => true})
      insert_completed_session!("110.00")

      conn = post(conn, "/api/v1/budgets/#{budget.id}/check", %{projected_cost: "0"})
      body = json_response(conn, 200)
      assert body["result"] == "block"
      assert body["budget_id"] == budget.id
    end

    test "returns block when projected_cost pushes over limit", %{conn: conn} do
      budget = create_budget!(%{"limit_usd" => "100.00", "hard_ceiling" => true})
      insert_completed_session!("95.00")

      conn = post(conn, "/api/v1/budgets/#{budget.id}/check", %{projected_cost: "10.00"})
      body = json_response(conn, 200)
      assert body["result"] == "block"
    end

    test "returns 404 for unknown budget", %{conn: conn} do
      conn = post(conn, "/api/v1/budgets/#{Ecto.UUID.generate()}/check", %{projected_cost: "0"})
      assert json_response(conn, 404)
    end
  end
end
