defmodule Canopy.Repo.Migrations.AddAgentKanbanFieldsToTasks do
  @moduledoc """
  Adds agent-kanban claim fields to the existing `tasks` table.

  - `claimed_by_agent_id` — slug of the agent that picked up the task
  - `claimed_at`          — timestamp of the most recent claim
  - `auto_assignable`     — when true, the auto-pickup loop may claim the task
  - `required_skills`     — string array of skill tags an agent must have to claim

  An agent claims a task atomically via SELECT … FOR UPDATE SKIP LOCKED inside a
  Repo.transaction (see `Canopy.Tasks.Kanban.claim_task/2`). The partial index on
  unclaimed, auto-assignable rows keeps the queue scan cheap as the table grows.
  """

  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :claimed_by_agent_id, :string, null: true
      add :claimed_at, :utc_datetime_usec, null: true
      add :auto_assignable, :boolean, null: false, default: false
      add :required_skills, {:array, :string}, null: false, default: []
    end

    create index(:tasks, [:claimed_by_agent_id], where: "claimed_by_agent_id IS NOT NULL")

    # Hot path for the auto-pickup loop: cheap scan over unclaimed,
    # auto-assignable rows ordered by priority + age.
    create index(
             :tasks,
             [:auto_assignable, :priority, :inserted_at],
             where:
               "claimed_by_agent_id IS NULL AND auto_assignable = true AND status IN ('todo','in_progress')",
             name: :tasks_kanban_unclaimed_idx
           )
  end
end
