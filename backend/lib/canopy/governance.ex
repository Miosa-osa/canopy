defmodule Canopy.Governance do
  @moduledoc """
  Public API for Canopy governance gates.

  Governance gates block agent execution until a human approves the requested
  action. This pattern is ported from canopy-legacy (`governance/gate.ex`) and
  aligned with Paperclip's approval model.

  A governance check is inserted at key decision points in the heartbeat cycle
  (e.g., before an agent deletes files, deploys code, or sends an external message).
  The gate returns either `{:ok, :approved}` or blocks until the frontend surfaces
  the approval prompt to the user.

  All functions currently return `{:error, :not_implemented}`. Full implementation
  is Week 3 scope.
  """

  @doc "Checks whether a proposed action is pre-approved by policy."
  @spec check_approval(map()) ::
          {:ok, :approved} | {:ok, :pending} | {:error, :not_implemented}
  def check_approval(_action_context) do
    {:error, :not_implemented}
  end

  @doc "Creates a pending approval request and notifies the frontend via PubSub."
  @spec request_approval(map()) :: {:ok, map()} | {:error, :not_implemented}
  def request_approval(_action_context) do
    {:error, :not_implemented}
  end
end
