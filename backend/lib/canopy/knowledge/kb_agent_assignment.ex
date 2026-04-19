defmodule Canopy.Knowledge.KbAgentAssignment do
  @moduledoc """
  Ecto schema for the many-to-many KB ↔ agent mapping.

  `priority` controls retrieval order when an agent has multiple KBs assigned;
  lower value = higher priority (0 is default). The combination of kb_id and
  agent_slug is unique.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @derive {Jason.Encoder,
           only: [
             :id,
             :kb_id,
             :agent_slug,
             :priority,
             :inserted_at
           ]}

  schema "kb_agent_assignments" do
    belongs_to :knowledge_base, Canopy.Knowledge.KnowledgeBase, foreign_key: :kb_id

    field :agent_slug, :string
    field :priority, :integer, default: 0

    timestamps(updated_at: false)
  end

  @required ~w(kb_id agent_slug)a
  @optional ~w(priority)a

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(assignment, attrs) do
    assignment
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:agent_slug, min: 1, max: 128)
    |> validate_number(:priority, greater_than_or_equal_to: 0)
    |> unique_constraint([:kb_id, :agent_slug], name: :kb_agent_assignments_kb_agent_idx)
  end
end
