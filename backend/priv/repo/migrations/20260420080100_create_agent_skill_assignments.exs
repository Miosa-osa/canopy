defmodule Canopy.Repo.Migrations.CreateAgentSkillAssignments do
  use Ecto.Migration

  def change do
    create table(:agent_skill_assignments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent_slug, :string, null: false
      add :skill_slug, :string, null: false
      add :priority, :integer, null: false, default: 0
      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:agent_skill_assignments, [:agent_slug, :skill_slug])
    create index(:agent_skill_assignments, [:agent_slug, :enabled])
    create index(:agent_skill_assignments, [:skill_slug])
  end
end
