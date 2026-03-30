defmodule Canopy.Repo.Migrations.CreateAgentRuntimeStates do
  use Ecto.Migration

  def change do
    create table(:agent_runtime_states, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent_id, references(:agents, type: :binary_id, on_delete: :delete_all), null: false
      add :session_id, :string
      add :workspace_path, :string
      add :last_run_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:agent_runtime_states, [:agent_id])
  end
end
