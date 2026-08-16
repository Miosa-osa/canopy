defmodule Canopy.Repo.Migrations.CreateRelayTables do
  use Ecto.Migration

  def change do
    # --- relay_participants ---------------------------------------------------
    create table(:relay_participants, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :agent_slug, :string, null: false
      add :status, :string, null: false, default: "online"
      add :work_context, :map, null: false, default: %{}
      add :last_seen_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:relay_participants, [:agent_slug])
    create index(:relay_participants, [:status])

    # --- relay_messages -------------------------------------------------------
    create table(:relay_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :thread_id, :string, null: false
      add :from_agent_slug, :string, null: false
      # nullable → broadcast
      add :to_agent_slug, :string
      add :scope, :string, null: false, default: "direct"
      add :priority, :string, null: false, default: "normal"
      add :content, :text, null: false
      add :metadata, :map, null: false, default: %{}
      add :read_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:relay_messages, [:to_agent_slug, :read_at])
    create index(:relay_messages, [:thread_id])
    create index(:relay_messages, [:from_agent_slug])
    create index(:relay_messages, [:priority])

    # --- relay_channels -------------------------------------------------------
    create table(:relay_channels, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :name, :string, null: false
      add :description, :string
      add :member_slugs, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:relay_channels, [:name])
  end
end
