defmodule Canopy.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def up do
    # A previous agent left a stale `projects` table with a different schema.
    # Drop it before recreating with the canonical Projects module schema.
    execute "DROP TABLE IF EXISTS projects CASCADE"

    create table(:projects, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      # Human-readable slug, e.g. "canopy-launch", "miosa-v2"
      add :slug, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :workspace_slug, :string, null: false
      # active | paused | archived
      add :status, :string, null: false, default: "active"
      # User-picked hex colour, e.g. "#7bd88f"
      add :color, :string
      # Lucide icon name, e.g. "FolderKanban"
      add :icon, :string
      # agent | human
      add :owner_type, :string
      add :owner_id, :string
      add :target_date, :utc_datetime
      add :archived_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:projects, [:slug])
    create index(:projects, [:workspace_slug])
    create index(:projects, [:workspace_slug, :status])
  end

  def down do
    drop table(:projects)
  end
end
