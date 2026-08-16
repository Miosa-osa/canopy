defmodule Canopy.Repo.Migrations.CreateHeartbeats do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TYPE heartbeat_kind AS ENUM ('output', 'input', 'error', 'exit', 'pause', 'resume')
    """)

    create table(:heartbeats, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :session_id, :binary_id, null: false
      add :kind, :heartbeat_kind, null: false, default: "output"
      add :byte_count, :integer, null: false, default: 0
      add :preview, :text
      add :meta, :map, null: false, default: %{}

      # Immutable log — no updated_at
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create index(:heartbeats, [:session_id, :inserted_at])
    create index(:heartbeats, [:session_id, :kind, :inserted_at])
  end

  def down do
    drop table(:heartbeats)
    execute("DROP TYPE IF EXISTS heartbeat_kind")
  end
end
