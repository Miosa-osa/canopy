defmodule Canopy.Governance.RuleCacheTest do
  @moduledoc """
  Tests for the ETS-backed governance rule cache.

  The RuleCache GenServer is started by the application supervisor. In the test
  environment the process is already running (test env starts the full app).
  We call invalidate/0 to force a reload from the test sandbox DB after
  inserting/updating/deleting rules.

  All tests use async: false because they share the global ETS table and the
  live RuleCache GenServer process.
  """

  use Canopy.DataCase, async: false

  alias Canopy.Governance
  alias Canopy.Governance.{Rule, RuleCache}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_enabled_rule!(overrides \\ %{}) do
    base = %{
      "name" => "cache-test-rule-#{System.unique_integer([:positive])}",
      "action" => "log",
      "enabled" => true,
      "priority" => 0,
      "conditions" => %{}
    }

    {:ok, rule} = Governance.create_rule(Map.merge(base, overrides))
    rule
  end

  defp flush_cache do
    # invalidate() is a cast — give the GenServer time to process it.
    RuleCache.invalidate()
    Process.sleep(50)
  end

  # ---------------------------------------------------------------------------
  # list_enabled/0
  # ---------------------------------------------------------------------------

  describe "list_enabled/0" do
    test "returns empty list when no enabled rules exist" do
      flush_cache()
      assert [] = RuleCache.list_enabled()
    end

    test "returns enabled rules after load" do
      rule = create_enabled_rule!()
      flush_cache()

      rules = RuleCache.list_enabled()
      ids = Enum.map(rules, & &1.id)
      assert rule.id in ids
    end

    test "excludes disabled rules" do
      enabled_rule = create_enabled_rule!(%{"enabled" => "true"})

      {:ok, disabled_rule} =
        Governance.create_rule(%{
          "name" => "disabled-rule-#{System.unique_integer([:positive])}",
          "action" => "log",
          "enabled" => false
        })

      flush_cache()

      ids = RuleCache.list_enabled() |> Enum.map(& &1.id)
      assert enabled_rule.id in ids
      refute disabled_rule.id in ids
    end

    test "returns rules ordered by priority descending" do
      create_enabled_rule!(%{
        "name" => "prio-low-#{System.unique_integer([:positive])}",
        "priority" => "1"
      })

      create_enabled_rule!(%{
        "name" => "prio-high-#{System.unique_integer([:positive])}",
        "priority" => "100"
      })

      create_enabled_rule!(%{
        "name" => "prio-mid-#{System.unique_integer([:positive])}",
        "priority" => "50"
      })

      flush_cache()

      priorities = RuleCache.list_enabled() |> Enum.map(& &1.priority)
      assert priorities == Enum.sort(priorities, :desc)
    end
  end

  # ---------------------------------------------------------------------------
  # get/1
  # ---------------------------------------------------------------------------

  describe "get/1" do
    test "returns {:ok, rule} for a known enabled rule" do
      rule = create_enabled_rule!()
      flush_cache()

      assert {:ok, %Rule{id: id}} = RuleCache.get(rule.id)
      assert id == rule.id
    end

    test "returns {:error, :not_found} for an unknown id" do
      flush_cache()
      assert {:error, :not_found} = RuleCache.get(Ecto.UUID.generate())
    end

    test "returns {:error, :not_found} for a disabled rule (not in ETS)" do
      {:ok, rule} =
        Governance.create_rule(%{
          "name" => "disabled-get-test-#{System.unique_integer([:positive])}",
          "action" => "log",
          "enabled" => false
        })

      flush_cache()
      assert {:error, :not_found} = RuleCache.get(rule.id)
    end
  end

  # ---------------------------------------------------------------------------
  # Cache invalidation on create / update / delete
  # ---------------------------------------------------------------------------

  describe "invalidation on create_rule/1" do
    test "new enabled rule appears in cache after create" do
      ids_before = RuleCache.list_enabled() |> Enum.map(& &1.id)

      rule = create_enabled_rule!()
      # create_rule/1 calls invalidate() internally; wait for async reload
      Process.sleep(50)

      ids_after = RuleCache.list_enabled() |> Enum.map(& &1.id)
      refute rule.id in ids_before
      assert rule.id in ids_after
    end
  end

  describe "invalidation on update_rule/2" do
    test "disabling a rule removes it from cache" do
      rule = create_enabled_rule!()
      Process.sleep(50)

      assert rule.id in (RuleCache.list_enabled() |> Enum.map(& &1.id))

      {:ok, _} = Governance.disable_rule(rule)
      Process.sleep(50)

      refute rule.id in (RuleCache.list_enabled() |> Enum.map(& &1.id))
    end

    test "updating priority re-sorts the cache" do
      rule = create_enabled_rule!(%{"priority" => "1"})
      Process.sleep(50)

      {:ok, _} = Governance.update_rule(rule, %{"priority" => 999})
      Process.sleep(50)

      [first | _] = RuleCache.list_enabled()
      assert first.id == rule.id
    end
  end

  describe "invalidation on delete_rule/1" do
    test "deleted rule is removed from cache" do
      rule = create_enabled_rule!()
      Process.sleep(50)

      assert rule.id in (RuleCache.list_enabled() |> Enum.map(& &1.id))

      {:ok, _} = Governance.delete_rule(rule)
      Process.sleep(50)

      refute rule.id in (RuleCache.list_enabled() |> Enum.map(& &1.id))
    end
  end
end
