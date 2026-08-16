defmodule Canopy.Repo.Migrations.CreateSkillVersions do
  @moduledoc """
  Records version history for each skill.

  Every time a skill's content changes (manual edit or upstream sync), the
  Skill Curator records a new row here with the new content hash, semver,
  optional changelog, and timestamp. This gives us:

  - Diff between any two versions for the curator's upgrade flow
  - Rollback target if a new version misbehaves
  - "What changed and when" audit trail
  """

  use Ecto.Migration

  def change do
    create table(:skill_versions, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :skill_id, references(:skills, type: :binary_id, on_delete: :delete_all), null: false
      add :skill_slug, :string, null: false, size: 128
      add :version, :string, null: false, size: 64
      add :content_hash, :string, null: false, size: 128
      add :changelog, :text
      add :published_at, :utc_datetime_usec, null: false
      add :published_by, :string, size: 128
      add :source, :string, size: 64

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:skill_versions, [:skill_id, :version])
    create index(:skill_versions, [:skill_slug])
    create index(:skill_versions, [:published_at])
  end
end
