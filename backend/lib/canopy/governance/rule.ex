defmodule Canopy.Governance.Rule do
  @moduledoc """
  Ecto schema for a governance rule.

  A rule defines conditions and the action to take when those conditions are
  met during session evaluation. Rules are evaluated in descending priority
  order — highest priority number wins.

  Actions:
    - "block"            — Reject session execution outright.
    - "require_approval" — Pause execution until a human approves.
    - "warn"             — Log a warning and continue.
    - "log"              — Record to audit log and continue silently.
    - "require_review"   — Queue artifact or tool-call for human review before it lands.

  Conditions (jsonb keys evaluated by `Canopy.Governance.Evaluator`):
    - "runtime"        — Exact match on session runtime_type.
    - "agent_slug"     — Exact match on session agent_slug.
    - "workspace_slug" — Exact match on session workspace_slug.
    - "prompt_regex"   — Regex match on session prompt.
    - "cost_over"      — True when session cost_usd exceeds this number.

  `:requires_review` rule conditions (evaluated by `Canopy.Governance.Reviewer`):
    - "match"           — "artifact" or "tool_call".
    - "artifact_types"  — Optional list of artifact types to match (null = all).
    - "tool_names"      — Optional list of tool names to match (null = all).
    - "agent_ids"       — Optional list of agent IDs to match (null = all).
    - "workspace_slugs" — Optional list of workspace slugs to match (null = all).
    - "min_risk"        — Future-proof numeric threshold (currently unused).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime_usec]

  @valid_actions ~w(block require_approval warn log require_review)

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :description,
             :enabled,
             :priority,
             :conditions,
             :action,
             :audit_context,
             :inserted_at,
             :updated_at
           ]}

  schema "governance_rules" do
    field :name, :string
    field :description, :string
    field :enabled, :boolean, default: true
    field :priority, :integer, default: 0
    field :conditions, :map, default: %{}
    field :action, :string
    field :audit_context, :map, default: %{}

    has_many :approvals, Canopy.Governance.Approval, foreign_key: :rule_id

    timestamps()
  end

  @required ~w(name action)a
  @optional ~w(description enabled priority conditions audit_context)a

  @doc "Changeset for creating or updating a governance rule."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(rule, attrs) do
    rule
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_inclusion(:action, @valid_actions)
    |> unique_constraint(:name)
  end

  @doc "Changeset for toggling the enabled flag only."
  @spec enabled_changeset(%__MODULE__{}, boolean()) :: Ecto.Changeset.t()
  def enabled_changeset(rule, enabled) do
    cast(rule, %{enabled: enabled}, [:enabled])
  end
end
