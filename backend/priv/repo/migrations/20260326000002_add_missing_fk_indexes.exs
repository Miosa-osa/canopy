defmodule Canopy.Repo.Migrations.AddMissingFkIndexes do
  use Ecto.Migration

  def change do
    create_if_not_exists index(:workspaces, [:owner_id])
    create_if_not_exists index(:goals, [:parent_id])
    create_if_not_exists index(:goals, [:project_id])
    create_if_not_exists index(:issues, [:project_id])
    create_if_not_exists index(:issues, [:goal_id])
    create_if_not_exists index(:issues, [:assignee_id])
    create_if_not_exists index(:comments, [:author_id])
    create_if_not_exists index(:budget_incidents, [:agent_id])
    create_if_not_exists index(:budget_incidents, [:policy_id])
  end
end
