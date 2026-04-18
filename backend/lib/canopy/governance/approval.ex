defmodule Canopy.Governance.Approval do
  @moduledoc """
  Ecto schema for a governance approval request.

  An approval is created when a rule with action "require_approval" matches
  during session evaluation. The approval starts in "pending" status and
  transitions to "approved" or "rejected" via human decision.

  Status lifecycle: pending → approved | rejected | expired
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @valid_statuses ~w(pending approved rejected expired)

  @derive {Jason.Encoder,
           only: [
             :id,
             :rule_id,
             :session_id,
             :status,
             :requested_at,
             :decided_at,
             :expires_at,
             :decided_by,
             :decision_reason,
             :inserted_at,
             :updated_at
           ]}

  schema "governance_approvals" do
    belongs_to :rule, Canopy.Governance.Rule
    field :session_id, :binary_id

    field :status, :string, default: "pending"
    field :requested_at, :utc_datetime_usec
    field :decided_at, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec
    field :decided_by, :string
    field :decision_reason, :string

    timestamps()
  end

  @required ~w(rule_id session_id requested_at)a
  @optional ~w(status decided_at expires_at decided_by decision_reason)a

  @doc "Changeset for creating a new approval request."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(approval, attrs) do
    approval
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:rule_id)
  end

  @doc "Changeset for recording a human decision (approve or reject)."
  @spec decision_changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def decision_changeset(approval, attrs) do
    approval
    |> cast(attrs, [:status, :decided_at, :decided_by, :decision_reason])
    |> validate_required([:status, :decided_at, :decided_by])
    |> validate_inclusion(:status, ~w(approved rejected))
  end
end
