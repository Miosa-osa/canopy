defmodule Canopy.Repo.Migrations.AddKindToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :kind, :string, null: false, default: "terminal", size: 32
    end

    create index(:sessions, [:kind])
    create index(:sessions, [:kind, :workspace_slug, :inserted_at])
  end
end
