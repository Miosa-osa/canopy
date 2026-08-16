defmodule Canopy.Repo.Migrations.AddRunIdToAgentToolCalls do
  use Ecto.Migration

  def change do
    alter table(:agent_tool_calls) do
      add :run_id, :binary_id
    end

    create index(:agent_tool_calls, [:run_id])

    # Add created_by_run_id to tasks
    alter table(:tasks) do
      add :created_by_run_id, :binary_id
    end

    create index(:tasks, [:created_by_run_id])

    # Add created_by_run_id to issues
    alter table(:issues) do
      add :created_by_run_id, :binary_id
    end

    create index(:issues, [:created_by_run_id])

    # Add created_by_run_id to reviews
    alter table(:reviews) do
      add :created_by_run_id, :binary_id
    end

    create index(:reviews, [:created_by_run_id])

    # Add latest_run_id to sessions
    alter table(:sessions) do
      add :latest_run_id, :binary_id
    end
  end
end
