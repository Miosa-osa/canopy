defmodule Canopy.Repo.Migrations.CreateScheduleRuns do
  use Ecto.Migration

  def change do
    create table(:schedule_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :spec_id, :binary_id, null: false
      add :spec_slug, :string, size: 128
      add :agent_slug, :string, size: 128
      add :workspace_slug, :string, size: 128

      add :scheduled_at, :utc_datetime_usec, null: false
      add :fired_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec

      # Lifecycle status:
      #   enqueued | running | completed | failed | skipped_overlap |
      #   late | missed | cancelled
      add :status, :string, null: false, default: "enqueued", size: 24

      # Late/miss accounting (Healthchecks-style grace window).
      add :lateness_ms, :integer
      add :duration_ms, :integer
      add :attempt, :integer, default: 1, null: false

      # Free-form context — adapter, oban_job_id, error, payload echo.
      add :session_id, :binary_id
      add :run_id, :binary_id
      add :payload, :map, default: %{}, null: false
      add :error_class, :string, size: 64
      add :error_message, :text

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:schedule_runs, [:spec_id, :scheduled_at])
    create index(:schedule_runs, [:status, :scheduled_at])
    create index(:schedule_runs, [:agent_slug, :scheduled_at])
    create index(:schedule_runs, [:workspace_slug, :scheduled_at])
    create index(:schedule_runs, [:fired_at])
  end
end
