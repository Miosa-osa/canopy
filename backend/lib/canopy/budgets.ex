defmodule Canopy.Budgets do
  @moduledoc """
  Public API for Canopy budget enforcement.

  Budget enforcement runs at three tiers (ported from canopy-legacy):
  1. Visibility — show cost meter; no blocking.
  2. Soft alert at 80% — warn the user; session continues.
  3. Hard ceiling — block the session; require user acknowledgment to continue.

  Spend is tracked per-agent, per-project, per-workspace, and per-goal.
  Oban jobs handle async enforcement checks on a configurable schedule.

  All functions currently return `{:error, :not_implemented}`. Full implementation
  is Week 3 scope.
  """

  @doc "Checks whether a session is within budget limits before executing."
  @spec check_budget(map()) ::
          {:ok, :within_budget}
          | {:ok, :soft_alert, float()}
          | {:error, :ceiling_exceeded}
          | {:error, :not_implemented}
  def check_budget(_session_context) do
    {:error, :not_implemented}
  end

  @doc "Records a spend event for a completed session."
  @spec record_spend(String.t(), Decimal.t()) ::
          {:ok, map()} | {:error, :not_implemented}
  def record_spend(_session_id, _cost_usd) do
    {:error, :not_implemented}
  end
end
