defmodule Canopy.Repo.Migrations.FixMissingCascades do
  use Ecto.Migration

  def change do
    # workspaces.owner_id → users
    drop constraint(:workspaces, "workspaces_owner_id_fkey")

    alter table(:workspaces) do
      modify :owner_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end

    # agents.reports_to → agents (self-referential)
    drop constraint(:agents, "agents_reports_to_fkey")

    alter table(:agents) do
      modify :reports_to, references(:agents, type: :binary_id, on_delete: :nilify_all)
    end

    # goals.project_id → projects
    drop constraint(:goals, "goals_project_id_fkey")

    alter table(:goals) do
      modify :project_id, references(:projects, type: :binary_id, on_delete: :nilify_all)
    end

    # goals.parent_id → goals (self-referential)
    drop constraint(:goals, "goals_parent_id_fkey")

    alter table(:goals) do
      modify :parent_id, references(:goals, type: :binary_id, on_delete: :nilify_all)
    end

    # issues.project_id → projects
    drop constraint(:issues, "issues_project_id_fkey")

    alter table(:issues) do
      modify :project_id, references(:projects, type: :binary_id, on_delete: :nilify_all)
    end

    # issues.goal_id → goals
    drop constraint(:issues, "issues_goal_id_fkey")

    alter table(:issues) do
      modify :goal_id, references(:goals, type: :binary_id, on_delete: :nilify_all)
    end

    # budget_incidents.policy_id — must drop NOT NULL before nilify_all
    execute(
      "ALTER TABLE budget_incidents ALTER COLUMN policy_id DROP NOT NULL",
      "ALTER TABLE budget_incidents ALTER COLUMN policy_id SET NOT NULL"
    )

    drop constraint(:budget_incidents, "budget_incidents_policy_id_fkey")

    alter table(:budget_incidents) do
      modify :policy_id,
             references(:budget_policies, type: :binary_id, on_delete: :nilify_all)
    end

    # budget_incidents.agent_id — must drop NOT NULL before nilify_all
    execute(
      "ALTER TABLE budget_incidents ALTER COLUMN agent_id DROP NOT NULL",
      "ALTER TABLE budget_incidents ALTER COLUMN agent_id SET NOT NULL"
    )

    drop constraint(:budget_incidents, "budget_incidents_agent_id_fkey")

    alter table(:budget_incidents) do
      modify :agent_id,
             references(:agents, type: :binary_id, on_delete: :nilify_all)
    end

    # activity_events.agent_id → agents
    drop constraint(:activity_events, "activity_events_agent_id_fkey")

    alter table(:activity_events) do
      modify :agent_id, references(:agents, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
