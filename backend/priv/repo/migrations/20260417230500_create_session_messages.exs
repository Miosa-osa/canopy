defmodule Canopy.Repo.Migrations.CreateSessionMessages do
  use Ecto.Migration

  def change do
    create table(:session_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all),
        null: false

      add :sequence, :integer, null: false
      add :kind, :string, null: false
      add :content, :map, null: false
      add :tool_call_id, :string
      add :emitted_at, :utc_datetime_usec, null: false

      # Intentionally no updated_at — messages are append-only
      add :inserted_at, :utc_datetime_usec, null: false
    end

    create unique_index(:session_messages, [:session_id, :sequence])
    create index(:session_messages, [:session_id])
  end
end
