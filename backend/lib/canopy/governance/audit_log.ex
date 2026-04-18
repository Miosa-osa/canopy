defmodule Canopy.Governance.AuditLog do
  @moduledoc """
  Ecto schema for the append-only governance audit log.

  Every evaluation, block, approval request, approval decision, and policy
  bypass writes a record here. Records are NEVER updated or deleted — this
  is an immutable audit trail.

  Event types:
    - "rule_evaluated"       — A rule was tested against a context (regardless of match).
    - "session_blocked"      — A rule with action "block" matched; session rejected.
    - "approval_requested"   — A rule with action "require_approval" matched.
    - "approval_granted"     — A human approved a pending approval.
    - "approval_rejected"    — A human rejected a pending approval.
    - "policy_bypassed"      — Evaluation completed with no decisive rule (pass).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_event_types ~w(
    rule_evaluated
    session_blocked
    approval_requested
    approval_granted
    approval_rejected
    policy_bypassed
  )

  @derive {Jason.Encoder,
           only: [
             :id,
             :rule_id,
             :session_id,
             :event_type,
             :payload,
             :occurred_at
           ]}

  schema "governance_audit_log" do
    field :rule_id, :binary_id
    field :session_id, :binary_id
    field :event_type, :string
    field :payload, :map, default: %{}
    field :occurred_at, :utc_datetime_usec
  end

  @required ~w(event_type occurred_at)a
  @optional ~w(rule_id session_id payload)a

  @doc "Changeset for appending a new audit log entry."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:event_type, @valid_event_types)
  end
end
