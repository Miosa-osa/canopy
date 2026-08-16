defmodule Canopy.Routines.Routine do
  @moduledoc "Ecto schema for a recurring automation routine."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @valid_creates ~w(issue task goal)

  @derive {Jason.Encoder,
           only: [
             :id,
             :short_id,
             :name,
             :description,
             :cron,
             :prompt_template,
             :creates,
             :target_agent_id,
             :target_runtime_type,
             :workspace_slug,
             :enabled,
             :last_run_at,
             :next_run_at,
             :run_count,
             :error_count,
             :in_flight,
             :inserted_at,
             :updated_at
           ]}

  schema "routines" do
    field :short_id, :string
    field :name, :string
    field :description, :string
    field :cron, :string
    field :prompt_template, :string
    field :creates, :string, default: "task"
    field :target_agent_id, :string
    field :target_runtime_type, :string
    field :workspace_slug, :string
    field :enabled, :boolean, default: true
    field :last_run_at, :utc_datetime
    field :next_run_at, :utc_datetime
    field :run_count, :integer, default: 0
    field :error_count, :integer, default: 0
    field :in_flight, :boolean, default: false

    timestamps()
  end

  @required ~w(name cron prompt_template workspace_slug)a
  @optional ~w(short_id description creates target_agent_id target_runtime_type
               enabled last_run_at next_run_at run_count error_count in_flight)a

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(routine, attrs) do
    routine
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:name, min: 1, max: 256)
    |> validate_length(:cron, min: 1, max: 128)
    |> validate_inclusion(:creates, @valid_creates)
    |> unique_constraint(:short_id)
  end
end
