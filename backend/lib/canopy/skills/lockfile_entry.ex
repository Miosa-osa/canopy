defmodule Canopy.Skills.LockfileEntry do
  @moduledoc """
  Ecto schema for a single entry in the skill lockfile.

  A lockfile entry pins a `(workspace_slug, skill_slug)` pair to a specific
  `locked_version` and `content_hash`. The Skill Curator writes this row at
  install time and refuses to apply an upstream change unless Roberto
  explicitly accepts a diff.

  This is the "no silent upgrades" guarantee for skills.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @derive {Jason.Encoder,
           only: [
             :id,
             :workspace_slug,
             :skill_slug,
             :locked_version,
             :content_hash,
             :source,
             :source_url,
             :locked_at,
             :locked_by,
             :notes,
             :inserted_at,
             :updated_at
           ]}

  schema "skill_lockfile_entries" do
    field :workspace_slug, :string
    field :skill_slug, :string
    field :locked_version, :string
    field :content_hash, :string
    field :source, :string
    field :source_url, :string
    field :locked_at, :utc_datetime_usec
    field :locked_by, :string
    field :notes, :string

    timestamps()
  end

  @required ~w(workspace_slug skill_slug locked_version content_hash)a
  @optional ~w(source source_url locked_at locked_by notes)a

  @doc "Changeset for creating or updating a lockfile entry."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:workspace_slug, min: 1, max: 128)
    |> validate_length(:skill_slug, min: 1, max: 128)
    |> validate_length(:locked_version, min: 1, max: 64)
    |> validate_length(:content_hash, min: 1, max: 128)
    |> unique_constraint([:workspace_slug, :skill_slug],
      name: :skill_lockfile_entries_workspace_slug_skill_slug_index,
      message: "skill already locked for this workspace"
    )
  end
end
