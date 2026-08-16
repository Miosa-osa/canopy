defmodule Canopy.Repo.Migrations.CreateTemplates do
  use Ecto.Migration

  def change do
    create table(:templates, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :slug, :string, null: false, size: 128
      add :name, :string, null: false, size: 256
      add :description, :text
      add :kind, :string, null: false, size: 32
      add :body, :map, default: %{}, null: false
      add :parameters, :map, default: %{}, null: false
      add :version, :string, null: false, default: "0.1.0", size: 32
      add :parent_template_id, :binary_id
      add :forked_from_slug, :string, size: 128
      add :verified, :boolean, default: false, null: false
      add :verified_by, :string, size: 128
      add :verified_at, :utc_datetime_usec
      add :published, :boolean, default: false, null: false
      add :source, :string, default: "local", size: 32
      add :source_url, :string, size: 512
      add :tags, {:array, :string}, default: [], null: false
      add :icon, :string, size: 16
      add :popularity_count, :integer, default: 0, null: false
      add :created_by_agent_id, :binary_id

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:templates, [:slug])
    create index(:templates, [:kind])
    create index(:templates, [:verified, :kind])
    create index(:templates, [:published])
    create index(:templates, [:parent_template_id])
    create index(:templates, [:popularity_count])
  end
end
