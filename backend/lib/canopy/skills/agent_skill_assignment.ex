defmodule Canopy.Skills.AgentSkillAssignment do
  @moduledoc """
  Ecto schema for the agent ↔ skill assignment join table.

  An assignment records that a specific skill is assigned to a specific agent,
  with a priority (lower = injected first) and an enabled toggle.

  Both `agent_slug` and `skill_slug` are string references — no FK constraint
  is enforced at the DB level so assignments can survive re-seeds.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime_usec]

  @derive {Jason.Encoder,
           only: [:id, :agent_slug, :skill_slug, :priority, :enabled, :inserted_at, :updated_at]}

  schema "agent_skill_assignments" do
    field :agent_slug, :string
    field :skill_slug, :string
    field :priority, :integer, default: 0
    field :enabled, :boolean, default: true

    timestamps()
  end

  @required ~w(agent_slug skill_slug)a
  @optional ~w(priority enabled)a

  @doc "Changeset for creating or updating an assignment."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(assignment, attrs) do
    assignment
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:agent_slug, min: 1, max: 128)
    |> validate_length(:skill_slug, min: 1, max: 128)
    |> validate_number(:priority, greater_than_or_equal_to: 0)
    |> unique_constraint([:agent_slug, :skill_slug],
      name: :agent_skill_assignments_agent_slug_skill_slug_index,
      message: "skill already assigned to this agent"
    )
  end
end
