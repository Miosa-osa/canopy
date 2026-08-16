defmodule Canopy.Repo.Migrations.AddConfigToAgents do
  use Ecto.Migration

  def change do
    alter table(:agents) do
      add :config, :map, default: %{}
    end
  end
end
