defmodule Canopy.Repo.Migrations.AddDeletedAtToWorkspaces do
  use Ecto.Migration

  def change do
    alter table(:workspaces) do
      add :deleted_at, :utc_datetime, null: true
    end

    create index(:workspaces, [:deleted_at])
  end
end
