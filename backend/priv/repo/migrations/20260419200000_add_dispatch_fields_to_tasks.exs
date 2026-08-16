defmodule Canopy.Repo.Migrations.AddDispatchFieldsToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      # UUID of the session this task was most recently dispatched to.
      # Not a FK — sessions live in a separate table and tasks may outlive sessions.
      add :session_id, :binary_id, null: true
      # Timestamp of the most recent dispatch action.
      add :dispatched_at, :utc_datetime, null: true
    end

    create index(:tasks, [:session_id], where: "session_id IS NOT NULL")
  end
end
