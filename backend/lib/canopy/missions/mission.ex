defmodule Canopy.Missions.Mission do
  @moduledoc "A high-level objective decomposed into ordered milestones."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @valid_statuses ~w(planning active completed failed)
  @valid_priorities 1..5

  @derive {Jason.Encoder,
           only: [
             :id,
             :title,
             :description,
             :status,
             :workspace_slug,
             :created_by_agent_slug,
             :priority,
             :inserted_at,
             :updated_at
           ]}

  schema "missions" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "planning"
    field :workspace_slug, :string
    field :created_by_agent_slug, :string
    field :priority, :integer, default: 3

    has_many :milestones, Canopy.Missions.Milestone, preload_order: [asc: :order]

    timestamps()
  end

  @required ~w(title workspace_slug)a
  @optional ~w(description status created_by_agent_slug priority)a

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(mission, attrs) do
    mission
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:title, min: 1, max: 512)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:priority, Enum.to_list(@valid_priorities))
  end
end
