defmodule Canopy.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :runtime_type, :string, null: false
      add :model_id, :string
      add :agent_slug, :string
      add :workspace_slug, :string
      add :status, :string, null: false, default: "pending"
      add :cwd, :string, null: false
      add :prompt, :text
      add :prompt_bundle_key, :string
      add :wake_reason, :string
      add :parent_session_id, :binary_id
      add :sequence_number, :integer, default: 0, null: false
      add :external_session_id, :string
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :error_reason, :text
      add :cost_usd, :decimal, precision: 12, scale: 6, default: 0
      add :input_tokens, :integer, default: 0, null: false
      add :output_tokens, :integer, default: 0, null: false
      add :cache_read_tokens, :integer, default: 0, null: false
      add :cache_write_tokens, :integer, default: 0, null: false
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create index(:sessions, [:status])
    create index(:sessions, [:runtime_type])
    create index(:sessions, [:workspace_slug])
    create index(:sessions, [:parent_session_id])
    create index(:sessions, [:status, :inserted_at])
  end
end
