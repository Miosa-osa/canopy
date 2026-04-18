defmodule Canopy.Repo.Migrations.CreateDocsSchema do
  use Ecto.Migration

  def up do
    # citext — idempotent.
    execute "CREATE EXTENSION IF NOT EXISTS citext"

    # -------------------------------------------------------------------------
    # doc_folders — hierarchical folder tree via self-referential FK
    # -------------------------------------------------------------------------
    create table(:doc_folders, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :string, null: false

      add :parent_id,
          references(:doc_folders, type: :binary_id, on_delete: :nilify_all)

      add :workspace_slug, :string, null: false
      add :owner_user_id, :binary_id
      add :owner_agent_slug, :string
      add :color, :string
      add :sort_order, :integer, null: false, default: 0
      add :archived_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:doc_folders, [:workspace_slug])
    create index(:doc_folders, [:parent_id])

    # -------------------------------------------------------------------------
    # documents
    # -------------------------------------------------------------------------
    create table(:documents, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :slug, :citext, null: false
      add :folder_id, references(:doc_folders, type: :binary_id, on_delete: :nilify_all)
      add :workspace_slug, :string, null: false
      add :title, :string, null: false
      add :body_json, :map, null: false, default: %{}
      add :body_text, :text, null: false, default: ""
      add :summary, :string
      add :author_type, :string, null: false
      add :author_id, :string, null: false
      add :last_editor_type, :string, null: false
      add :last_editor_id, :string, null: false
      add :published, :boolean, null: false, default: false
      add :published_at, :utc_datetime
      add :tags, {:array, :string}, null: false, default: []
      add :version, :integer, null: false, default: 1
      add :archived_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:documents, [:slug, :workspace_slug])
    create index(:documents, [:workspace_slug, :updated_at])

    create index(:documents, [:folder_id, :archived_at],
             where: "archived_at IS NULL",
             name: :documents_active_folder_idx
           )

    execute """
    CREATE INDEX documents_body_text_fts_idx
      ON documents
      USING GIN (to_tsvector('english', body_text))
    """
  end

  def down do
    execute "DROP INDEX IF EXISTS documents_body_text_fts_idx"
    drop table(:documents)
    drop table(:doc_folders)
  end
end
