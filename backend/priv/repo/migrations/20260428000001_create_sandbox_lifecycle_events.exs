defmodule Canopy.Repo.Migrations.CreateSandboxLifecycleEvents do
  use Ecto.Migration

  def change do
    create table(:sandbox_lifecycle_events, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :sandbox_id, :string, null: false, size: 128
      add :run_id, :binary_id
      add :session_id, :binary_id
      add :workspace_slug, :string, size: 128
      add :owner_agent_id, :binary_id
      add :state, :string, null: false, size: 32
      add :prior_state, :string, size: 32
      add :reason, :string, size: 256
      add :ts, :utc_datetime_usec, null: false
      add :payload, :map, default: %{}, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:sandbox_lifecycle_events, [:sandbox_id, :ts])
    create index(:sandbox_lifecycle_events, [:state, :ts])
    create index(:sandbox_lifecycle_events, [:owner_agent_id, :ts])
    create index(:sandbox_lifecycle_events, [:workspace_slug, :ts])
    create index(:sandbox_lifecycle_events, [:run_id])
    create index(:sandbox_lifecycle_events, [:session_id])
    create index(:sandbox_lifecycle_events, [:ts])
  end
end
