defmodule Canopy.Repo.Migrations.AddVerifiedToSkills do
  @moduledoc """
  Adds verification metadata to existing skills.

  The Skill Curator agent (and only the Skill Curator) flips the `verified`
  flag on a skill once it has passed the curator's quality rubric. The flag
  gates installs from external sources: an unverified source can be installed
  only with explicit user approval.

  Columns are added at the DB level so existing schema reads stay backward
  compatible — the curator queries them via parametric Ecto fragments, not
  through the base `Skill` schema.
  """

  use Ecto.Migration

  def change do
    alter table(:skills) do
      add :verified, :boolean, default: false, null: false
      add :verified_at, :utc_datetime_usec
      add :verified_by, :string, size: 128
    end

    create index(:skills, [:verified])
  end
end
