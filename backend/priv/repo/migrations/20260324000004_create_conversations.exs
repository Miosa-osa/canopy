defmodule Canopy.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    create table(:conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string
      add :agent_id, references(:agents, type: :binary_id, on_delete: :delete_all), null: false
      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all)
      add :user_id, :string
      add :status, :string, default: "active"
      add :last_message_at, :utc_datetime_usec
      add :message_count, :integer, default: 0
      add :metadata, :map, default: %{}
      timestamps()
    end

    create index(:conversations, [:agent_id])
    create index(:conversations, [:workspace_id])
    create index(:conversations, [:status])

    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :role, :string, null: false
      add :content, :text, null: false
      add :content_type, :string, default: "text"
      add :metadata, :map, default: %{}
      add :token_count, :integer
      add :cost_cents, :integer
      timestamps()
    end

    create index(:messages, [:conversation_id])
    create index(:messages, [:inserted_at])
  end
end
