defmodule Canopy.Repo.Migrations.CreateWorkspaceInitJobs do
  use Ecto.Migration

  def change do
    create table(:workspace_init_jobs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :workspace_slug, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :current_step, :string
      add :progress_pct, :integer, null: false, default: 0
      add :output, :text, null: false, default: ""
      add :error, :text
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime

      timestamps(type: :utc_datetime_usec)
    end

    create index(:workspace_init_jobs, [:workspace_slug])
    create index(:workspace_init_jobs, [:status])
    create index(:workspace_init_jobs, [:workspace_slug, :status])
  end
end
