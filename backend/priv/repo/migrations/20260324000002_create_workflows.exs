defmodule Canopy.Repo.Migrations.CreateWorkflows do
  use Ecto.Migration

  def change do
    create table(:workflows, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all)
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all)
      add :status, :string, default: "draft"
      add :trigger_type, :string, default: "manual"
      add :trigger_config, :map, default: %{}
      add :created_by, :string
      add :version, :integer, default: 1

      timestamps()
    end

    create unique_index(:workflows, [:workspace_id, :slug])
    create index(:workflows, [:workspace_id])
    create index(:workflows, [:organization_id])

    create table(:workflow_steps, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workflow_id, references(:workflows, type: :binary_id, on_delete: :delete_all),
        null: false

      add :agent_id, references(:agents, type: :binary_id, on_delete: :nilify_all)
      add :name, :string, null: false
      add :step_type, :string, default: "agent_task"
      add :position, :integer, null: false
      add :config, :map, default: %{}
      add :depends_on, {:array, :binary_id}, default: []
      add :timeout_seconds, :integer, default: 300
      add :retry_count, :integer, default: 0
      add :on_failure, :string, default: "stop"

      timestamps()
    end

    create index(:workflow_steps, [:workflow_id])

    create table(:workflow_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :workflow_id, references(:workflows, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, default: "pending"
      add :trigger_event, :string
      add :input, :map, default: %{}
      add :output, :map, default: %{}
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :error, :text
      add :step_results, :map, default: %{}

      timestamps()
    end

    create index(:workflow_runs, [:workflow_id])
    create index(:workflow_runs, [:status])
  end
end
