defmodule Canopy.Goals.Goal do
  @moduledoc "Ecto schema for an orchestrator-level goal."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @valid_statuses ~w(proposed active blocked achieved cancelled)
  @valid_priorities 0..4

  @derive {Jason.Encoder,
           only: [
             :id,
             :short_id,
             :title,
             :description,
             :status,
             :priority,
             :owner_type,
             :owner_id,
             :workspace_slug,
             :project_slug,
             :target_date,
             :achieved_at,
             :progress_pct,
             :success_criteria,
             :inserted_at,
             :updated_at
           ]}

  schema "goals" do
    field :short_id, :string
    field :title, :string
    field :description, :string
    field :status, :string, default: "proposed"
    field :priority, :integer, default: 0
    field :owner_type, :string
    field :owner_id, :string
    field :workspace_slug, :string
    field :project_slug, :string
    field :target_date, :utc_datetime
    field :achieved_at, :utc_datetime
    field :progress_pct, :integer, default: 0
    field :success_criteria, :string

    timestamps()
  end

  @required ~w(title workspace_slug)a
  @optional ~w(short_id description status priority owner_type owner_id
               project_slug target_date achieved_at progress_pct success_criteria)a

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(goal, attrs) do
    goal
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:title, min: 1, max: 512)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:priority, Enum.to_list(@valid_priorities))
    |> validate_number(:progress_pct,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    )
    |> unique_constraint(:short_id)
  end
end
