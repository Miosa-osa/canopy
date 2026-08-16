defmodule Canopy.Missions.Milestone do
  @moduledoc """
  A checkpoint within a mission, gated by dependency resolution and validation.

  `validation_spec` is a map of testable assertions:
    %{"type" => "shell", "command" => "mix test", "expected" => "0 failures"}
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @valid_statuses ~w(pending active completed failed blocked)

  @derive {Jason.Encoder,
           only: [
             :id,
             :mission_id,
             :title,
             :description,
             :status,
             :order,
             :depends_on_ids,
             :validation_spec,
             :completed_at,
             :inserted_at,
             :updated_at
           ]}

  schema "milestones" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "pending"
    field :order, :integer, default: 0
    field :depends_on_ids, {:array, :binary_id}, default: []
    field :validation_spec, :map, default: %{}
    field :completed_at, :utc_datetime

    belongs_to :mission, Canopy.Missions.Mission

    timestamps()
  end

  @required ~w(title mission_id)a
  @optional ~w(description status order depends_on_ids validation_spec completed_at)a

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(milestone, attrs) do
    milestone
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:title, min: 1, max: 512)
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:mission_id)
  end
end
