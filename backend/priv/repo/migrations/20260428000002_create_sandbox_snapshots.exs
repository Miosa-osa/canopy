defmodule Canopy.Repo.Migrations.CreateSandboxSnapshots do
  use Ecto.Migration

  def change do
    create table(:sandbox_snapshots, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :slug, :string, null: false, size: 128
      add :sandbox_id, :string, null: false, size: 128
      add :kind, :string, null: false, size: 16
      add :name, :string, size: 256
      add :image_uri, :string, size: 1024
      add :path, :string, size: 1024
      add :size_bytes, :bigint
      add :parent_snapshot_id, :binary_id
      add :created_by_agent_id, :binary_id
      add :workspace_slug, :string, size: 128
      add :retention_until, :utc_datetime_usec
      add :reaped_at, :utc_datetime_usec
      add :metadata, :map, default: %{}, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:sandbox_snapshots, [:slug])
    create index(:sandbox_snapshots, [:sandbox_id])
    create index(:sandbox_snapshots, [:kind, :retention_until])
    create index(:sandbox_snapshots, [:parent_snapshot_id])
    create index(:sandbox_snapshots, [:workspace_slug])
    create index(:sandbox_snapshots, [:retention_until])
    create index(:sandbox_snapshots, [:created_by_agent_id])
  end
end
