defmodule Canopy.Repo.Migrations.CreateMissionsAndMilestones do
  @moduledoc """
  Creates the `missions` and `milestones` tables.

  A mission is a high-level objective. Milestones are ordered checkpoints within
  a mission. Milestones carry dependency IDs (array of milestone UUIDs) and an
  optional validation_spec map used by the orchestrator to gate completion.
  """

  use Ecto.Migration

  def change do
    create table(:missions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :status, :string, null: false, default: "planning"
      add :workspace_slug, :string, null: false
      add :created_by_agent_slug, :string
      add :priority, :integer, null: false, default: 3

      timestamps(type: :utc_datetime)
    end

    create index(:missions, [:workspace_slug])
    create index(:missions, [:status])
    create index(:missions, [:workspace_slug, :status])

    create table(:milestones, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :mission_id, references(:missions, type: :binary_id, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :description, :text
      add :status, :string, null: false, default: "pending"
      add :order, :integer, null: false, default: 0
      add :depends_on_ids, {:array, :binary_id}, null: false, default: []
      add :validation_spec, :map, null: false, default: %{}
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:milestones, [:mission_id])
    create index(:milestones, [:mission_id, :order])
    create index(:milestones, [:status], where: "status NOT IN ('completed', 'failed')")
  end
end
