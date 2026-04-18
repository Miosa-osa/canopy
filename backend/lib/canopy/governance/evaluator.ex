defmodule Canopy.Governance.Evaluator do
  @moduledoc """
  Rule evaluation logic for governance gates.

  Turns a rule's `conditions` map into a predicate evaluated against the
  session context. All conditions in a rule must match for the rule to fire
  (implicit AND semantics).

  Supported condition keys:
    - "runtime"        — Exact match on context.runtime_type.
    - "agent_slug"     — Exact match on context.agent_slug.
    - "workspace_slug" — Exact match on context.workspace_slug.
    - "prompt_regex"   — Regex match on context.prompt.
    - "cost_over"      — context.cost_usd (as float) exceeds this threshold.

  Unknown condition keys are ignored (forward-compatible).
  """

  alias Canopy.Governance.Rule

  @doc """
  Returns true if ALL conditions in the rule match against the given context.

  Context is a plain map with string or atom keys. Missing context keys are
  treated as non-matching for exact-match conditions and 0.0 for cost_over.
  """
  @spec matches?(Rule.t(), map()) :: boolean()
  def matches?(%Rule{conditions: conditions}, context) when is_map(conditions) do
    Enum.all?(conditions, fn {key, value} ->
      evaluate_condition(key, value, context)
    end)
  end

  def matches?(_rule, _context), do: false

  # ---------------------------------------------------------------------------
  # Private — individual condition evaluators
  # ---------------------------------------------------------------------------

  @spec evaluate_condition(String.t(), term(), map()) :: boolean()

  defp evaluate_condition("runtime", expected, context) do
    fetch_string(context, "runtime_type") == expected
  end

  defp evaluate_condition("agent_slug", expected, context) do
    fetch_string(context, "agent_slug") == expected
  end

  defp evaluate_condition("workspace_slug", expected, context) do
    fetch_string(context, "workspace_slug") == expected
  end

  defp evaluate_condition("prompt_regex", pattern, context) do
    prompt = fetch_string(context, "prompt") || ""

    case Regex.compile(pattern) do
      {:ok, regex} -> Regex.match?(regex, prompt)
      {:error, _reason} -> false
    end
  end

  defp evaluate_condition("cost_over", threshold, context) when is_number(threshold) do
    cost = fetch_cost(context)
    cost > threshold
  end

  # Unknown condition keys are ignored — forward-compatible.
  defp evaluate_condition(_key, _value, _context), do: true

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  @spec fetch_string(map(), String.t()) :: String.t() | nil
  defp fetch_string(context, key) do
    Map.get(context, key) || Map.get(context, String.to_existing_atom(key))
  rescue
    ArgumentError -> Map.get(context, key)
  end

  @spec fetch_cost(map()) :: float()
  defp fetch_cost(context) do
    raw = Map.get(context, "cost_usd") || Map.get(context, :cost_usd) || 0

    cond do
      is_struct(raw, Decimal) -> Decimal.to_float(raw)
      is_float(raw) -> raw
      is_integer(raw) -> raw * 1.0
      is_binary(raw) -> parse_float(raw)
      true -> 0.0
    end
  end

  @spec parse_float(String.t()) :: float()
  defp parse_float(str) do
    case Float.parse(str) do
      {f, _remainder} -> f
      :error -> 0.0
    end
  end
end
