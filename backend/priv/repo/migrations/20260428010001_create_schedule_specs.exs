defmodule Canopy.Repo.Migrations.CreateScheduleSpecs do
  use Ecto.Migration

  def change do
    create table(:schedule_specs, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :slug, :string, null: false, size: 128
      add :name, :string, null: false, size: 256
      add :description, :text
      add :agent_id, :binary_id
      add :agent_slug, :string, size: 128
      add :workspace_slug, :string, size: 128

      # ScheduleSpec model — calendars ∪ intervals ∪ crons − skips
      # Stored as a single jsonb document so we can evolve the shape without
      # a migration. Shape matches Canopy.Schedule.Spec embedded schema.
      add :model, :map, default: %{}, null: false

      # Resolved policy fields surfaced from `model` for cheap querying.
      add :timezone, :string, default: "UTC", size: 64
      add :overlap_policy, :string, default: "skip", size: 16
      add :jitter_seconds, :integer, default: 0, null: false
      add :grace_seconds, :integer, default: 0, null: false
      add :failure_threshold, :integer, default: 5, null: false
      add :concurrency_key, :string, size: 128

      add :start_at, :utc_datetime_usec
      add :end_at, :utc_datetime_usec
      add :next_fire_at, :utc_datetime_usec
      add :last_fire_at, :utc_datetime_usec

      # Lifecycle state.
      add :status, :string, default: "active", null: false, size: 16
      add :paused_reason, :string, size: 256
      add :paused_at, :utc_datetime_usec

      add :consecutive_failures, :integer, default: 0, null: false
      add :run_count, :integer, default: 0, null: false
      add :error_count, :integer, default: 0, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:schedule_specs, [:slug])
    create index(:schedule_specs, [:agent_slug])
    create index(:schedule_specs, [:workspace_slug])
    create index(:schedule_specs, [:status, :next_fire_at])
    create index(:schedule_specs, [:concurrency_key])
  end
end
