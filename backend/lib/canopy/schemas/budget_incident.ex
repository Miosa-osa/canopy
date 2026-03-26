defmodule Canopy.Schemas.BudgetIncident do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "budget_incidents" do
    field :incident_type, :string
    field :threshold_pct, :integer
    field :actual_pct, :integer
    field :resolved, :boolean, default: false
    field :resolved_at, :utc_datetime
    field :scope_type, :string
    field :scope_id, :binary_id
    field :inserted_at, :utc_datetime

    belongs_to :policy, Canopy.Schemas.BudgetPolicy
    belongs_to :agent, Canopy.Schemas.Agent
    belongs_to :resolved_by_user, Canopy.Schemas.User, foreign_key: :resolved_by
  end

  def changeset(incident, attrs) do
    incident
    |> cast(attrs, [
      :incident_type,
      :threshold_pct,
      :actual_pct,
      :resolved,
      :resolved_at,
      :policy_id,
      :agent_id,
      :resolved_by,
      :scope_type,
      :scope_id,
      :inserted_at
    ])
    |> validate_required([:incident_type, :threshold_pct, :actual_pct, :policy_id])
    |> validate_inclusion(:incident_type, ~w(warning hard_stop))
  end
end
