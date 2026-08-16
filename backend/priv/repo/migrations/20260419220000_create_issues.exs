defmodule Canopy.Repo.Migrations.CreateIssues do
  use Ecto.Migration

  def up do
    # Drop the legacy issues table from the prior schema (empty, different columns).
    execute("DROP TABLE IF EXISTS issues CASCADE")

    create table(:issues, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      # Human-readable short ID, e.g. "I-00003721"
      add :short_id, :string, null: false
      add :title, :string, null: false
      add :description, :text
      # backlog | open | in_progress | in_review | closed
      add :status, :string, null: false, default: "open"
      # 0 = none, 1 = low, 2 = medium, 3 = high, 4 = urgent
      add :priority, :integer, null: false, default: 0
      # agent | human
      add :assignee_type, :string
      add :assignee_id, :string
      add :workspace_slug, :string, null: false
      add :project_slug, :string
      # Self-referential parent for sub-issues
      add :parent_id, :binary_id
      add :session_id, :binary_id
      add :dispatched_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :branch, :string
      add :pr_url, :string
      add :labels, {:array, :string}, null: false, default: []
      add :estimate_minutes, :integer
      add :due_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:issues, [:short_id])
    create index(:issues, [:workspace_slug, :status])
    create index(:issues, [:workspace_slug, :updated_at])

    create index(:issues, [:assignee_id],
             where: "completed_at IS NULL",
             name: :issues_assignee_open_idx
           )

    create index(:issues, [:project_slug])
    create index(:issues, [:parent_id])
    create index(:issues, [:status])
  end

  def down do
    execute("DROP TABLE IF EXISTS issues CASCADE")
  end
end
