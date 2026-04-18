defmodule Canopy.DashboardTest do
  @moduledoc """
  Integration tests for Canopy.Dashboard.

  Tests the three aggregate functions: active_agents, spend_this_month, recent_sessions.
  Tests must tolerate an empty database — every function returns its zero/empty shape.
  """

  use Canopy.DataCase, async: false

  import Canopy.Factory

  alias Canopy.Dashboard

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp running_session!(overrides \\ %{}) do
    insert(:session, Map.merge(%{status: "running", started_at: DateTime.utc_now()}, overrides))
  end

  defp completed_session!(cost_usd, overrides \\ %{}) do
    insert(
      :session,
      Map.merge(
        %{
          status: "completed",
          started_at: DateTime.add(DateTime.utc_now(), -60),
          completed_at: DateTime.utc_now(),
          cost_usd: Decimal.new(cost_usd)
        },
        overrides
      )
    )
  end

  # ---------------------------------------------------------------------------
  # Dashboard.active_agents/0
  # ---------------------------------------------------------------------------

  describe "active_agents/0" do
    test "returns empty list when no sessions exist" do
      assert [] = Dashboard.active_agents()
    end

    test "returns only running sessions" do
      running_session!(%{agent_slug: "builder"})
      completed_session!("0.01", %{agent_slug: "builder"})

      rows = Dashboard.active_agents()
      assert length(rows) == 1
      assert hd(rows).agent_slug == "builder"
    end

    test "caps at 50 rows" do
      Enum.each(1..55, fn _ -> running_session!() end)
      rows = Dashboard.active_agents()
      assert length(rows) == 50
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard.spend_this_month/0
  # ---------------------------------------------------------------------------

  describe "spend_this_month/0" do
    test "returns zero totals when no completed sessions" do
      result = Dashboard.spend_this_month()
      assert result.total_usd == "0"
      assert result.by_agent == []
    end

    test "sums cost_usd from completed sessions this month" do
      completed_session!("1.50", %{agent_slug: "builder"})
      completed_session!("2.50", %{agent_slug: "builder"})
      completed_session!("1.00", %{agent_slug: "analyzer"})

      result = Dashboard.spend_this_month()

      assert Decimal.equal?(Decimal.new(result.total_usd), Decimal.new("5.00"))
      assert length(result.by_agent) == 2

      builder = Enum.find(result.by_agent, &(&1.agent_slug == "builder"))
      assert Decimal.equal?(Decimal.new(builder.cost_usd), Decimal.new("4.00"))
    end

    test "excludes running sessions from spend total" do
      running_session!(%{cost_usd: Decimal.new("99.99")})
      result = Dashboard.spend_this_month()
      assert Decimal.equal?(Decimal.new(result.total_usd), Decimal.new("0"))
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard.recent_sessions/1
  # ---------------------------------------------------------------------------

  describe "recent_sessions/1" do
    test "returns empty list when no sessions" do
      assert [] = Dashboard.recent_sessions(10)
    end

    test "returns n most recent sessions ordered by inserted_at desc" do
      s1 = running_session!()
      s2 = completed_session!("1.00")

      rows = Dashboard.recent_sessions(10)
      ids = Enum.map(rows, & &1.id)

      assert s1.id in ids
      assert s2.id in ids
    end

    test "caps at 50 even if n > 50 requested" do
      Enum.each(1..55, fn _ -> running_session!() end)
      rows = Dashboard.recent_sessions(60)
      assert length(rows) == 50
    end

    test "returned rows have required fields" do
      running_session!(%{agent_slug: "tester"})
      [row | _] = Dashboard.recent_sessions(1)

      assert Map.has_key?(row, :id)
      assert Map.has_key?(row, :agent_slug)
      assert Map.has_key?(row, :status)
      assert Map.has_key?(row, :runtime_type)
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard.summary/0
  # ---------------------------------------------------------------------------

  describe "summary/0" do
    test "returns map with required keys on empty database" do
      result = Dashboard.summary()

      assert is_map(result)
      assert Map.has_key?(result, :active_agents)
      assert Map.has_key?(result, :spend_this_month)
      assert Map.has_key?(result, :recent_sessions)
    end

    test "summary shapes are valid" do
      result = Dashboard.summary()

      assert is_list(result.active_agents)
      assert is_map(result.spend_this_month)
      assert Map.has_key?(result.spend_this_month, :total_usd)
      assert is_list(result.recent_sessions)
    end

    test "summary reflects inserted data" do
      running_session!(%{agent_slug: "testbot"})
      completed_session!("3.00")

      result = Dashboard.summary()

      assert length(result.active_agents) == 1
      assert length(result.recent_sessions) >= 2

      assert Decimal.compare(Decimal.new(result.spend_this_month.total_usd), Decimal.new("3.00")) ==
               :eq
    end
  end
end
