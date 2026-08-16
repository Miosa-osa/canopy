defmodule Canopy.Skills.Version do
  @moduledoc """
  Ecto schema for a single version row in a skill's history.

  Every meaningful change to a skill's content produces a new row here:
  the version string (typically semver), the SHA256 of the content at that
  point, an optional changelog, and metadata about when and how it was
  published. The Skill Curator's diff and rollback flows read from this
  table.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @derive {Jason.Encoder,
           only: [
             :id,
             :skill_id,
             :skill_slug,
             :version,
             :content_hash,
             :changelog,
             :published_at,
             :published_by,
             :source,
             :inserted_at,
             :updated_at
           ]}

  schema "skill_versions" do
    field :skill_id, Ecto.UUID
    field :skill_slug, :string
    field :version, :string
    field :content_hash, :string
    field :changelog, :string
    field :published_at, :utc_datetime_usec
    field :published_by, :string
    field :source, :string

    timestamps()
  end

  @required ~w(skill_id skill_slug version content_hash published_at)a
  @optional ~w(changelog published_by source)a

  @doc "Changeset for creating a version row."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(version, attrs) do
    version
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:version, min: 1, max: 64)
    |> validate_length(:skill_slug, min: 1, max: 128)
    |> validate_length(:content_hash, min: 1, max: 128)
    |> unique_constraint([:skill_id, :version],
      name: :skill_versions_skill_id_version_index,
      message: "version already recorded for this skill"
    )
  end
end
