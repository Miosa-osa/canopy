defmodule Canopy.Repo.Migrations.CreateLibraryItems do
  use Ecto.Migration

  def change do
    create table(:library_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all)
      add :created_by_id, :binary_id
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :category, :string, null: false
      add :subcategory, :string
      add :version, :string, default: "1.0.0"
      add :status, :string, default: "published"
      add :visibility, :string, default: "organization"
      add :icon, :string
      add :config, :map, null: false, default: %{}
      add :tags, {:array, :string}, default: []
      add :install_count, :integer, default: 0
      add :rating_sum, :integer, default: 0
      add :rating_count, :integer, default: 0
      add :dependencies, {:array, :string}, default: []
      add :changelog, :text
      add :readme, :text

      timestamps()
    end

    create unique_index(:library_items, [:organization_id, :slug, :category])
    create index(:library_items, [:organization_id])
    create index(:library_items, [:category])
    create index(:library_items, [:status])
    create index(:library_items, [:tags], using: :gin)
  end
end
