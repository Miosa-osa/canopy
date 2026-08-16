defmodule Canopy.Repo.Migrations.AddConfigToWorkspaces do
  use Ecto.Migration

  def change do
    alter table(:workspaces) do
      add :config, :map, default: %{}, null: false
    end
  end
end
