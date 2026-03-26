defmodule Canopy.Repo.Migrations.CreateLibraryInstalls do
  use Ecto.Migration

  def change do
    create table(:library_installs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :library_item_id,
          references(:library_items, type: :binary_id, on_delete: :delete_all),
          null: false

      add :workspace_id,
          references(:workspaces, type: :binary_id, on_delete: :delete_all),
          null: false

      add :installed_by_id, :binary_id
      add :installed_version, :string
      add :config_overrides, :map, default: %{}
      add :status, :string, default: "active"

      timestamps()
    end

    create unique_index(:library_installs, [:library_item_id, :workspace_id])
    create index(:library_installs, [:workspace_id])
  end
end
