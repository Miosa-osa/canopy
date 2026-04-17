defmodule Canopy.Repo.Migrations.CreateWorkspaces do
  use Ecto.Migration

  def change do
    create table(:workspaces, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :slug, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :root_path, :string, null: false
      add :template, :string

      timestamps()
    end

    create unique_index(:workspaces, [:slug])
  end
end
