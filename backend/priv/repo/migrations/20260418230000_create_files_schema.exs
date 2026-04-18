defmodule Canopy.Repo.Migrations.CreateFilesSchema do
  use Ecto.Migration

  def up do
    # pg_trgm — used for ILIKE-based name search acceleration.
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"

    # -------------------------------------------------------------------------
    # files — metadata index (no binary content)
    # -------------------------------------------------------------------------
    create table(:files, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")

      add :workspace_id,
          references(:workspaces, type: :binary_id, on_delete: :delete_all),
          null: false

      add :path, :string, null: false
      add :name, :string, null: false
      add :extension, :string
      add :mime_type, :string, null: false, default: "application/octet-stream"
      add :size_bytes, :bigint, null: false, default: 0
      add :sha256, :string
      add :owner_type, :string, null: false, default: "system"
      add :owner_id, :string
      add :tags, {:array, :string}, null: false, default: []
      add :last_indexed_at, :utc_datetime
      add :archived_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:files, [:workspace_id, :path])
    create index(:files, [:workspace_id, :extension])

    create index(:files, [:workspace_id, :archived_at],
             where: "archived_at IS NULL",
             name: :files_workspace_active_idx
           )

    execute "CREATE INDEX files_tags_gin_idx ON files USING GIN (tags)"

    # -------------------------------------------------------------------------
    # file_activity — append-only event log per file
    # -------------------------------------------------------------------------
    create table(:file_activity, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")

      add :file_id,
          references(:files, type: :binary_id, on_delete: :delete_all),
          null: false

      add :actor_type, :string, null: false
      add :actor_id, :string, null: false
      add :action, :string, null: false
      add :metadata, :map, null: false, default: %{}
      add :occurred_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:file_activity, [:file_id, :occurred_at], name: :file_activity_file_occurred_idx)

    create index(:file_activity, [:actor_type, :actor_id, :occurred_at],
             name: :file_activity_actor_occurred_idx
           )
  end

  def down do
    execute "DROP INDEX IF EXISTS files_tags_gin_idx"
    drop table(:file_activity)
    drop table(:files)
  end
end
