defmodule Canopy.Repo.Migrations.CreateAgents do
  use Ecto.Migration

  def change do
    create table(:agents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :slug, :string, null: false
      add :category, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :persona_path, :string, null: false
      add :default_runtime, :string
      add :default_model, :string
      add :heartbeat_cron, :string
      add :budget_monthly_usd, :decimal, precision: 12, scale: 2
      add :hired, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:agents, [:slug])
    create index(:agents, [:category, :hired])
  end
end
