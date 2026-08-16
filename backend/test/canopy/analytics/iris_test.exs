defmodule Canopy.Analytics.IrisTest do
  @moduledoc """
  Tests for the Iris boot bootstrap surface.

  Covers:
    * `hire_if_missing/0` creates an agent row with the correct slug, role,
      and persona fields.
    * `hire_if_missing/0` is idempotent — calling it twice does not error or
      duplicate.
    * `register_tools/0` makes all 6 analytics tools resolvable via
      `Canopy.Tools.Registry.lookup/1`.
  """

  use Canopy.DataCase, async: false

  alias Canopy.Agents
  alias Canopy.Analytics.Iris
  alias Canopy.Tools.Registry, as: ToolRegistry

  @slug "analytics-agent"
  @analytics_tool_names [
    "analytics.query_telemetry",
    "analytics.aggregate_costs",
    "analytics.compare_periods",
    "analytics.list_agents_by_metric",
    "analytics.investigate_breadcrumbs",
    "analytics.summarize_session"
  ]

  describe "hire_if_missing/0" do
    test "creates an agent row with the right slug, role, and persona fields" do
      assert {:ok, agent} = Iris.hire_if_missing()

      assert agent.slug == @slug
      assert agent.name == "Iris"
      assert agent.category == "specialized"
      assert agent.persona_path == "analytics-agent/persona.md"
      assert agent.default_runtime == "claude-local"
      assert agent.default_model == "claude-sonnet-4-7"
      assert agent.heartbeat_cron == "0 */4 * * *"
      assert agent.hired == true
      assert Decimal.equal?(agent.budget_monthly_usd, Decimal.new(5000))

      # The DB row is reachable via the public Agents API.
      assert {:ok, fetched} = Agents.get_by_slug(@slug)
      assert fetched.id == agent.id
    end

    test "is idempotent — calling twice does not error or duplicate" do
      {:ok, first} = Iris.hire_if_missing()
      {:ok, second} = Iris.hire_if_missing()

      assert first.id == second.id
      assert second.hired == true

      {:ok, all} = Agents.list()
      assert Enum.count(all, &(&1.slug == @slug)) == 1
    end

    test "re-hires an agent that was previously fired" do
      {:ok, _first} = Iris.hire_if_missing()
      {:ok, _fired} = Agents.fire(@slug)

      {:ok, fetched} = Agents.get_by_slug(@slug)
      assert fetched.hired == false

      {:ok, rehired} = Iris.hire_if_missing()
      assert rehired.hired == true
    end
  end

  describe "register_tools/0" do
    test "makes all 6 analytics tools resolvable via Registry.lookup/1" do
      assert :ok = Iris.register_tools()

      for name <- @analytics_tool_names do
        assert {:ok, tool} = ToolRegistry.lookup(name),
               "expected #{name} to be registered after Iris.register_tools/0"

        assert tool.name == name
      end
    end

    test "is idempotent — re-registering does not raise" do
      assert :ok = Iris.register_tools()
      assert :ok = Iris.register_tools()

      # All 6 still resolvable.
      for name <- @analytics_tool_names do
        assert {:ok, _tool} = ToolRegistry.lookup(name)
      end
    end
  end
end
