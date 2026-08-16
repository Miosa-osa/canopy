defmodule Canopy.Tasks.AutoPickupTest do
  @moduledoc """
  Pure-decision tests for `Canopy.Tasks.AutoPickup.Dispatch.should_pickup?/3`.

  No database, no IO — just struct-in / decision-out. Side-effecting tests
  for the Oban worker live alongside the dispatcher integration tests; this
  file pins the gate logic that protects every pickup.
  """

  use ExUnit.Case, async: true

  alias Canopy.Agents.Agent
  alias Canopy.Tasks.AutoPickup.Dispatch
  alias Canopy.Tasks.Task

  defp build_agent(overrides \\ %{}) do
    base = %Agent{
      slug: "alice",
      category: "engineering",
      name: "Alice",
      persona_path: "engineering/alice.md",
      hired: true,
      config: %{"auto_pickup" => true, "capabilities" => ["elixir", "phoenix"]}
    }

    Map.merge(base, overrides)
  end

  defp build_task(overrides \\ %{}) do
    base = %Task{
      short_id: "T-00000001",
      title: "Build it",
      status: "todo",
      priority: 0,
      auto_assignable: true,
      required_skills: ["elixir"],
      claimed_by_agent_id: nil
    }

    Map.merge(base, overrides)
  end

  defp ctx(overrides \\ %{}) do
    Map.merge(%{active_session_count: 0}, overrides)
  end

  describe "should_pickup?/3 — pass" do
    test "passes when agent is hired, enabled, skills match, no active session" do
      assert Dispatch.should_pickup?(build_agent(), build_task(), ctx()) == :pickup
    end

    test "passes when task has no required_skills regardless of agent capabilities" do
      agent = build_agent(%{config: %{"auto_pickup" => true, "capabilities" => []}})
      task = build_task(%{required_skills: []})
      assert Dispatch.should_pickup?(agent, task, ctx()) == :pickup
    end

    test "passes when budget_remaining_usd is nil (treated as unlimited)" do
      assert Dispatch.should_pickup?(
               build_agent(),
               build_task(),
               ctx(%{budget_remaining_usd: nil})
             ) == :pickup
    end
  end

  describe "should_pickup?/3 — skip" do
    test "skips when agent is not hired" do
      agent = build_agent(%{hired: false})
      assert {:skip, :agent_not_hired} = Dispatch.should_pickup?(agent, build_task(), ctx())
    end

    test "skips when auto_pickup is disabled" do
      agent = build_agent(%{config: %{"auto_pickup" => false, "capabilities" => ["elixir"]}})
      assert {:skip, :auto_pickup_disabled} = Dispatch.should_pickup?(agent, build_task(), ctx())
    end

    test "skips when required_skills is not a subset of capabilities" do
      task = build_task(%{required_skills: ["rust"]})
      assert {:skip, :skill_mismatch} = Dispatch.should_pickup?(build_agent(), task, ctx())
    end

    test "skips when budget is exhausted" do
      assert {:skip, :budget_exhausted} =
               Dispatch.should_pickup?(
                 build_agent(),
                 build_task(),
                 ctx(%{budget_remaining_usd: Decimal.new("0")})
               )
    end

    test "skips when agent already has an active session" do
      assert {:skip, :agent_busy} =
               Dispatch.should_pickup?(
                 build_agent(),
                 build_task(),
                 ctx(%{active_session_count: 1})
               )
    end

    test "skips when the candidate task is already claimed" do
      task = build_task(%{claimed_by_agent_id: "bob"})
      assert {:skip, :already_claimed} = Dispatch.should_pickup?(build_agent(), task, ctx())
    end
  end
end
