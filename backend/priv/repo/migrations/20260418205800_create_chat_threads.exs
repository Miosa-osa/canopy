defmodule Canopy.Repo.Migrations.CreateChatThreads do
  use Ecto.Migration

  def change do
    create table(:chat_threads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string
      add :user_id, :binary_id
      add :agent_slug, :string
      add :runtime_type, :string, null: false
      add :model_id, :string
      add :workspace_slug, :string
      add :last_session_id, references(:sessions, type: :binary_id, on_delete: :nilify_all)
      add :last_message_at, :utc_datetime
      add :pinned, :boolean, default: false, null: false
      add :archived_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:chat_threads, [:user_id, :last_message_at],
             name: :chat_threads_user_id_last_message_at_desc_index
           )

    create index(:chat_threads, [:agent_slug, :last_message_at],
             name: :chat_threads_agent_slug_last_message_at_desc_index
           )

    create index(:chat_threads, [:user_id],
             where: "pinned = true",
             name: :chat_threads_pinned_partial_index
           )

    create index(:chat_threads, [:archived_at],
             where: "archived_at IS NULL",
             name: :chat_threads_active_partial_index
           )
  end
end
