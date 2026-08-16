defmodule Canopy.Repo.Migrations.CreateAnalyticsTelemetry do
  use Ecto.Migration

  def change do
    create table(:analytics_telemetry, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :ts, :utc_datetime_usec, null: false
      add :event, :string, null: false, size: 64
      add :run_id, :binary_id
      add :session_id, :binary_id
      add :agent_id, :binary_id
      add :workspace_slug, :string, size: 128
      add :runtime, :string, size: 32
      add :model, :string, size: 64
      add :duration_ms, :integer
      add :cost_cents, :integer
      add :status, :string, size: 16
      add :payload, :map, default: %{}, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:analytics_telemetry, [:ts])
    create index(:analytics_telemetry, [:event, :ts])
    create index(:analytics_telemetry, [:agent_id, :ts])
    create index(:analytics_telemetry, [:run_id])
    create index(:analytics_telemetry, [:session_id])
    create index(:analytics_telemetry, [:workspace_slug, :ts])
    create index(:analytics_telemetry, [:runtime, :ts])
  end
end
