defmodule Canopy.Repo.Migrations.CreateSandboxAlerts do
  use Ecto.Migration

  def change do
    create table(:sandbox_alerts, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :slug, :string, null: false, size: 128
      add :name, :string, null: false, size: 256
      add :description, :text
      add :metric, :string, null: false, size: 128
      add :type, :string, null: false, default: "threshold", size: 32
      add :config, :map, default: %{}, null: false
      add :routing, :map, default: %{}, null: false
      add :enabled, :boolean, default: true, null: false
      add :severity, :string, default: "medium", size: 16
      add :workspace_slug, :string, size: 128
      add :created_by_agent_id, :binary_id
      add :last_evaluated_at, :utc_datetime_usec
      add :last_fired_at, :utc_datetime_usec
      add :fire_count, :integer, default: 0, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:sandbox_alerts, [:slug])
    create index(:sandbox_alerts, [:enabled, :metric])
    create index(:sandbox_alerts, [:workspace_slug])
    create index(:sandbox_alerts, [:last_fired_at])
  end
end
