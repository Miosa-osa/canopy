defmodule Canopy.Repo.Migrations.CreateScheduleOverlaps do
  use Ecto.Migration

  def change do
    create table(:schedule_overlaps, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :spec_id, :binary_id, null: false
      add :spec_slug, :string, size: 128

      # Detection: two scheduled runs collided. The "incoming" tick is the one
      # arriving while `running_run_id` is still in flight. The applied policy
      # records what the dispatcher decided to do.
      add :incoming_run_id, :binary_id
      add :running_run_id, :binary_id
      add :detected_at, :utc_datetime_usec, null: false

      add :applied_policy, :string, null: false, size: 24
      add :outcome, :string, size: 24
      add :detail, :map, default: %{}, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:schedule_overlaps, [:spec_id, :detected_at])
    create index(:schedule_overlaps, [:applied_policy])
  end
end
