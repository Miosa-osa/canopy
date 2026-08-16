defmodule Canopy.Repo.Migrations.CreateRoutines do
  use Ecto.Migration

  def change do
    create table(:routines, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      # Human-readable short ID, e.g. "R-00003721"
      add :short_id, :string, null: false
      add :name, :string, null: false
      add :description, :text
      # Cron expression, e.g. "0 9 * * 1" (every Monday 9am)
      add :cron, :string, null: false
      # Liquid-ish prompt template with {{date}}, {{workspace}} placeholders
      add :prompt_template, :text, null: false
      # issue | task | goal
      add :creates, :string, null: false, default: "task"
      add :target_agent_id, :string
      add :target_runtime_type, :string
      add :workspace_slug, :string, null: false
      add :enabled, :boolean, null: false, default: true
      add :last_run_at, :utc_datetime
      # TODO: computed from cron on write when Crontab dep is available
      add :next_run_at, :utc_datetime
      add :run_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:routines, [:short_id])
    create index(:routines, [:workspace_slug, :enabled])
    create index(:routines, [:workspace_slug])
    create index(:routines, [:enabled])
  end
end
