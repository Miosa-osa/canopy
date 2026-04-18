defmodule Canopy.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id, null: true
      add :agent_slug, :string, null: true
      add :type, :string, null: false
      add :title, :string, null: false
      add :body, :text, null: false
      add :icon, :string, null: true
      add :link_path, :string, null: true
      add :payload, :map, default: %{}
      add :read_at, :utc_datetime, null: true
      add :delivered_channels, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    # Partial index: unread rows for a user ordered by recency.
    # Ecto does not support DESC column ordering in the index DSL, so we use raw SQL.
    execute(
      "CREATE INDEX notifications_user_unread_idx ON notifications (user_id, inserted_at DESC) WHERE read_at IS NULL",
      "DROP INDEX IF EXISTS notifications_user_unread_idx"
    )

    # Type + recency filtering
    create index(:notifications, [:type, :inserted_at], name: :notifications_type_inserted_idx)

    # General user_id lookup
    create index(:notifications, [:user_id], name: :notifications_user_id_idx)
  end
end
