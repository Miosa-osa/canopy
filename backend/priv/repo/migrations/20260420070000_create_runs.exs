defmodule Canopy.Repo.Migrations.CreateRuns do
  use Ecto.Migration

  def change do
    create table(:runs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :short_id, :string, null: false
      add :session_id, :binary_id
      add :agent_slug, :string
      add :workspace_slug, :string, null: false
      add :issue_short_id, :string
      add :task_short_id, :string
      add :project_slug, :string
      add :process_pid, :integer
      add :status, :string, null: false, default: "queued"
      add :prompt_bundle_key, :string
      add :usage_json, :map, null: false, default: %{}
      add :log_ref, :string
      add :context_snapshot, :map
      add :started_at, :utc_datetime, null: false
      add :finished_at, :utc_datetime
      add :error_reason, :text
      add :wake_reason, :string

      timestamps()
    end

    create unique_index(:runs, [:short_id])
    create index(:runs, [:session_id])
    create index(:runs, [:agent_slug])
    create index(:runs, [:workspace_slug])
    create index(:runs, [:status])
    create index(:runs, [:started_at])
  end
end
