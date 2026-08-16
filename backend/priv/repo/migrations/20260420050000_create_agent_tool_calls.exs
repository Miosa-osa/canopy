defmodule Canopy.Repo.Migrations.CreateAgentToolCalls do
  use Ecto.Migration

  def change do
    create table(:agent_tool_calls, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, :binary_id, null: false
      add :agent_id, :string, null: false
      add :tool_name, :string, null: false
      add :params, :map, default: %{}
      add :result, :map
      add :status, :string, null: false, default: "ok"
      add :error, :text
      add :review_id, :binary_id

      add :inserted_at, :utc_datetime, null: false
    end

    create index(:agent_tool_calls, [:session_id])
    create index(:agent_tool_calls, [:agent_id])
    create index(:agent_tool_calls, [:tool_name])
    create index(:agent_tool_calls, [:review_id])
    create index(:agent_tool_calls, [:inserted_at])
  end
end
