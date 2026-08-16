defmodule Canopy.Repo.Migrations.CreateHookEvents do
  use Ecto.Migration

  def change do
    create table(:hook_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent, :string, null: false
      add :event, :string, null: false
      add :session_id, :string
      add :payload, :map, default: %{}

      add :inserted_at, :utc_datetime_usec, null: false
    end

    create index(:hook_events, [:agent])
    create index(:hook_events, [:event])
    create index(:hook_events, [:session_id])
    create index(:hook_events, [:inserted_at])
  end
end
