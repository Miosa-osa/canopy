defmodule Canopy.Repo.Migrations.CreateSkills do
  use Ecto.Migration

  def change do
    create table(:skills, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :slug, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :provider_format, :string, null: false, default: "generic"
      add :content, :text, null: false
      add :content_hash, :string, null: false
      add :source, :string, null: false, default: "local"
      add :source_url, :string
      add :imported_at, :utc_datetime_usec
      add :tags, {:array, :string}, default: []
      add :enabled, :boolean, default: true, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:skills, [:slug])
    create index(:skills, [:source, :enabled])

    execute(
      "CREATE INDEX skills_tags_gin ON skills USING GIN (tags)",
      "DROP INDEX IF EXISTS skills_tags_gin"
    )
  end
end
