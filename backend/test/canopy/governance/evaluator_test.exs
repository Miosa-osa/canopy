defmodule Canopy.Governance.EvaluatorTest do
  @moduledoc """
  Tests for the Canopy.Governance.Evaluator condition engine.

  Covers all supported condition keys, combined conditions, priority ordering
  semantics (ordering is Governance responsibility — Evaluator tests single rules),
  and unknown-key forward-compatibility.
  """

  use ExUnit.Case, async: true

  alias Canopy.Governance.Evaluator
  alias Canopy.Governance.Rule

  defp build_rule(conditions) do
    %Rule{
      id: Ecto.UUID.generate(),
      name: "test-rule",
      action: "block",
      enabled: true,
      priority: 0,
      conditions: conditions,
      audit_context: %{}
    }
  end

  # ---------------------------------------------------------------------------
  # runtime condition
  # ---------------------------------------------------------------------------

  describe "runtime condition" do
    test "matches when runtime_type equals the expected value" do
      rule = build_rule(%{"runtime" => "claude-local"})
      assert Evaluator.matches?(rule, %{"runtime_type" => "claude-local"})
    end

    test "does not match when runtime_type differs" do
      rule = build_rule(%{"runtime" => "claude-local"})
      refute Evaluator.matches?(rule, %{"runtime_type" => "codex"})
    end

    test "does not match when runtime_type is absent" do
      rule = build_rule(%{"runtime" => "claude-local"})
      refute Evaluator.matches?(rule, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # agent_slug condition
  # ---------------------------------------------------------------------------

  describe "agent_slug condition" do
    test "matches on exact agent_slug" do
      rule = build_rule(%{"agent_slug" => "senior-dev"})
      assert Evaluator.matches?(rule, %{"agent_slug" => "senior-dev"})
    end

    test "does not match on different agent_slug" do
      rule = build_rule(%{"agent_slug" => "senior-dev"})
      refute Evaluator.matches?(rule, %{"agent_slug" => "junior-dev"})
    end

    test "does not match when agent_slug is absent" do
      rule = build_rule(%{"agent_slug" => "senior-dev"})
      refute Evaluator.matches?(rule, %{"runtime_type" => "claude-local"})
    end
  end

  # ---------------------------------------------------------------------------
  # workspace_slug condition
  # ---------------------------------------------------------------------------

  describe "workspace_slug condition" do
    test "matches on exact workspace_slug" do
      rule = build_rule(%{"workspace_slug" => "production"})
      assert Evaluator.matches?(rule, %{"workspace_slug" => "production"})
    end

    test "does not match on different workspace_slug" do
      rule = build_rule(%{"workspace_slug" => "production"})
      refute Evaluator.matches?(rule, %{"workspace_slug" => "staging"})
    end
  end

  # ---------------------------------------------------------------------------
  # prompt_regex condition
  # ---------------------------------------------------------------------------

  describe "prompt_regex condition" do
    test "matches when prompt contains the pattern" do
      rule = build_rule(%{"prompt_regex" => "deploy"})
      assert Evaluator.matches?(rule, %{"prompt" => "please deploy the app"})
    end

    test "matches with anchored pattern" do
      rule = build_rule(%{"prompt_regex" => "^deploy"})
      assert Evaluator.matches?(rule, %{"prompt" => "deploy now"})
    end

    test "does not match when prompt does not contain the pattern" do
      rule = build_rule(%{"prompt_regex" => "deploy"})
      refute Evaluator.matches?(rule, %{"prompt" => "just run the tests"})
    end

    test "does not match when prompt is absent" do
      rule = build_rule(%{"prompt_regex" => "deploy"})
      refute Evaluator.matches?(rule, %{"runtime_type" => "claude-local"})
    end

    test "treats empty prompt as non-matching for non-empty pattern" do
      rule = build_rule(%{"prompt_regex" => "deploy"})
      refute Evaluator.matches?(rule, %{"prompt" => ""})
    end

    test "invalid regex returns false (does not raise)" do
      rule = build_rule(%{"prompt_regex" => "["})
      refute Evaluator.matches?(rule, %{"prompt" => "deploy"})
    end

    test "case-sensitive by default" do
      rule = build_rule(%{"prompt_regex" => "Deploy"})
      refute Evaluator.matches?(rule, %{"prompt" => "deploy"})
    end

    test "supports case-insensitive flag in pattern" do
      rule = build_rule(%{"prompt_regex" => "(?i)deploy"})
      assert Evaluator.matches?(rule, %{"prompt" => "DEPLOY the app"})
    end
  end

  # ---------------------------------------------------------------------------
  # cost_over condition
  # ---------------------------------------------------------------------------

  describe "cost_over condition" do
    test "matches when cost_usd float exceeds threshold" do
      rule = build_rule(%{"cost_over" => 1.0})
      assert Evaluator.matches?(rule, %{"cost_usd" => 1.5})
    end

    test "does not match when cost_usd equals threshold (strict greater-than)" do
      rule = build_rule(%{"cost_over" => 1.0})
      refute Evaluator.matches?(rule, %{"cost_usd" => 1.0})
    end

    test "does not match when cost_usd is below threshold" do
      rule = build_rule(%{"cost_over" => 5.0})
      refute Evaluator.matches?(rule, %{"cost_usd" => 3.0})
    end

    test "handles Decimal cost_usd" do
      rule = build_rule(%{"cost_over" => 1.0})
      assert Evaluator.matches?(rule, %{"cost_usd" => Decimal.new("2.50")})
    end

    test "handles integer cost_usd" do
      rule = build_rule(%{"cost_over" => 1})
      assert Evaluator.matches?(rule, %{"cost_usd" => 2})
    end

    test "handles string cost_usd" do
      rule = build_rule(%{"cost_over" => 1.0})
      assert Evaluator.matches?(rule, %{"cost_usd" => "1.50"})
    end

    test "treats missing cost_usd as 0 (does not match positive threshold)" do
      rule = build_rule(%{"cost_over" => 0.5})
      refute Evaluator.matches?(rule, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # Combined conditions (AND semantics)
  # ---------------------------------------------------------------------------

  describe "combined conditions" do
    test "all conditions must match for the rule to fire" do
      rule = build_rule(%{"runtime" => "claude-local", "prompt_regex" => "deploy"})

      assert Evaluator.matches?(rule, %{
               "runtime_type" => "claude-local",
               "prompt" => "please deploy the app"
             })
    end

    test "fails if any condition does not match" do
      rule = build_rule(%{"runtime" => "claude-local", "prompt_regex" => "deploy"})

      refute Evaluator.matches?(rule, %{
               "runtime_type" => "codex",
               "prompt" => "please deploy the app"
             })
    end

    test "fails if second condition does not match" do
      rule = build_rule(%{"runtime" => "claude-local", "prompt_regex" => "deploy"})

      refute Evaluator.matches?(rule, %{
               "runtime_type" => "claude-local",
               "prompt" => "just run tests"
             })
    end

    test "empty conditions map always matches" do
      rule = build_rule(%{})
      assert Evaluator.matches?(rule, %{"runtime_type" => "anything"})
    end
  end

  # ---------------------------------------------------------------------------
  # Unknown condition keys — forward compatibility
  # ---------------------------------------------------------------------------

  describe "unknown condition keys" do
    test "unknown keys are treated as truthy (ignored, does not fail match)" do
      rule = build_rule(%{"unknown_future_key" => "value", "runtime" => "claude-local"})
      assert Evaluator.matches?(rule, %{"runtime_type" => "claude-local"})
    end
  end

  # ---------------------------------------------------------------------------
  # Nil / bad conditions
  # ---------------------------------------------------------------------------

  describe "nil or bad conditions field" do
    test "nil conditions returns false" do
      rule = %Rule{
        id: Ecto.UUID.generate(),
        name: "bad",
        action: "block",
        enabled: true,
        priority: 0,
        conditions: nil,
        audit_context: %{}
      }

      refute Evaluator.matches?(rule, %{"runtime_type" => "claude-local"})
    end
  end
end
