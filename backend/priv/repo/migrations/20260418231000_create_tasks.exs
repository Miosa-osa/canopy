defmodule Canopy.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      # Human-readable short ID, e.g. "T-00003721"
      add :short_id, :string, null: false
      # Self-referential parent for sub-tasks
      add :parent_id, references(:tasks, type: :binary_id, on_delete: :nilify_all)
      add :project_slug, :string
      add :title, :string, null: false
      add :description, :text
      # todo | in_progress | done | cancelled
      add :status, :string, null: false, default: "todo"
      # 0 = none, 1 = low, 2 = medium, 3 = high
      add :priority, :integer, null: false, default: 0
      # user | agent
      add :assignee_type, :string
      add :assignee_id, :string
      add :workspace_slug, :string
      add :due_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :labels, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tasks, [:short_id])
    create index(:tasks, [:status, :updated_at])
    create index(:tasks, [:parent_id])
    create index(:tasks, [:project_slug])

    create index(:tasks, [:assignee_type, :assignee_id],
             where: "completed_at IS NULL",
             name: :tasks_assignee_open_idx
           )
  end
end
