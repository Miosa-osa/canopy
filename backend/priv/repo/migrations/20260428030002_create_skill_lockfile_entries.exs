defmodule Canopy.Repo.Migrations.CreateSkillLockfileEntries do
  @moduledoc """
  Creates the skill lockfile table.

  A lockfile entry pins a workspace's installed skill to a specific version
  and content hash so that subsequent registry-side changes cannot silently
  alter the agent's behaviour. Roberto must explicitly accept upgrades.

  Unique on `(workspace_slug, skill_slug)` — at most one pin per skill per
  workspace.
  """

  use Ecto.Migration

  def change do
    create table(:skill_lockfile_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :workspace_slug, :string, null: false, size: 128
      add :skill_slug, :string, null: false, size: 128
      add :locked_version, :string, null: false, size: 64
      add :content_hash, :string, null: false, size: 128
      add :source, :string, size: 64
      add :source_url, :string, size: 512
      add :locked_at, :utc_datetime_usec
      add :locked_by, :string, size: 128
      add :notes, :text

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:skill_lockfile_entries, [:workspace_slug, :skill_slug])
    create index(:skill_lockfile_entries, [:skill_slug])
    create index(:skill_lockfile_entries, [:locked_at])
  end
end
