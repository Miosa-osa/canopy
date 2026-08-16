defmodule Canopy.Repo.Migrations.CreateScheduleAlerts do
  use Ecto.Migration

  def change do
    # Schedule alerts (a.k.a. incidents) — grouped failure records. One row
    # per outage rather than per failed run, mirroring the Cronitor "issue"
    # pattern. Closes when the underlying spec returns to a healthy state
    # (or when a human acknowledges, for circuit-breaker incidents).
    create table(:schedule_alerts, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :slug, :string, null: false, size: 128
      add :spec_id, :binary_id
      add :spec_slug, :string, size: 128

      add :category, :string, null: false, size: 32
      add :severity, :string, default: "medium", null: false, size: 16
      add :status, :string, default: "open", null: false, size: 16

      add :summary, :string, null: false, size: 512
      add :detail, :text

      add :first_seen_at, :utc_datetime_usec, null: false
      add :last_seen_at, :utc_datetime_usec, null: false
      add :closed_at, :utc_datetime_usec
      add :acknowledged_at, :utc_datetime_usec
      add :acknowledged_by, :string, size: 128

      add :failure_count, :integer, default: 1, null: false
      add :related_run_ids, {:array, :binary_id}, default: [], null: false

      add :workspace_slug, :string, size: 128
      add :resolution_note, :text

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:schedule_alerts, [:slug])
    create index(:schedule_alerts, [:status, :severity])
    create index(:schedule_alerts, [:spec_id, :status])
    create index(:schedule_alerts, [:category, :status])
    create index(:schedule_alerts, [:workspace_slug, :status])
  end
end
