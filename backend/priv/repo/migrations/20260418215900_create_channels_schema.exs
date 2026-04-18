defmodule Canopy.Repo.Migrations.CreateChannelsSchema do
  @moduledoc """
  Creates the channels schema:
    channels, channel_members, channel_messages, channel_reactions, channel_pins.

  Key design decisions:
  - `citext` is idempotent — already enabled by Track #71/Tasks migrations.
  - `actor_type` + `actor_id` pattern mirrors tasks assignee convention.
    actor_id stores UUID (user) or slug string (agent) in the same column.
  - `channel_messages.mentions` is an array of handle strings extracted from
    body markdown at write time by the application layer.
  - `channel_messages.attachments` is JSONB for flexible attachment metadata.
  - `deleted_at` soft-delete: body is cleared to "[deleted]" at the app layer.
  - `thread_count` is denormalized on the parent message and incremented in
    the same transaction as the reply INSERT.
  - GIN index on mentions enables "show me messages mentioning @me" queries.
  """

  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS citext"

    # -------------------------------------------------------------------------
    # channels
    # -------------------------------------------------------------------------
    create table(:channels, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :slug, :citext, null: false
      add :name, :string, null: false
      add :description, :text
      add :visibility, :string, null: false, default: "public"
      add :workspace_slug, :string
      add :icon, :string
      add :color, :string
      add :created_by_user_id, :binary_id
      add :archived_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:channels, [:slug])

    # -------------------------------------------------------------------------
    # channel_members
    # -------------------------------------------------------------------------
    create table(:channel_members, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")

      add :channel_id,
          references(:channels, type: :binary_id, on_delete: :delete_all),
          null: false

      add :actor_type, :string, null: false
      add :actor_id, :string, null: false
      add :role, :string, null: false, default: "member"
      add :notifications_enabled, :boolean, null: false, default: true
      add :last_read_at, :utc_datetime
      add :joined_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    # One membership record per (channel, actor)
    create unique_index(:channel_members, [:channel_id, :actor_type, :actor_id],
             name: :channel_members_channel_actor_unique_index
           )

    # "What channels is this actor a member of?"
    create index(:channel_members, [:actor_type, :actor_id], name: :channel_members_actor_index)

    # Admin listing within a channel
    create index(:channel_members, [:channel_id, :role],
             name: :channel_members_channel_role_index
           )

    # -------------------------------------------------------------------------
    # channel_messages
    # -------------------------------------------------------------------------
    create table(:channel_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")

      add :channel_id,
          references(:channels, type: :binary_id, on_delete: :delete_all),
          null: false

      add :author_type, :string, null: false
      add :author_id, :string

      add :body_markdown, :text, null: false
      add :body_rendered_html, :text

      # Self-referential: nil = top-level, non-nil = reply in thread
      add :reply_to_id, references(:channel_messages, type: :binary_id, on_delete: :nilify_all)

      # Denormalized count of direct replies; incremented in INSERT transaction
      add :thread_count, :integer, null: false, default: 0

      add :edited_at, :utc_datetime
      add :deleted_at, :utc_datetime

      # Extracted @mentions: list of "agent-slug" or "user-uuid" strings
      add :mentions, {:array, :string}, null: false, default: []

      # JSONB: [%{type, url, filename, size}]
      add :attachments, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    # Channel timeline — primary read path
    create index(:channel_messages, [:channel_id, :inserted_at],
             name: :channel_messages_channel_timeline_index
           )

    # Thread lookup — fetch replies to a parent message
    create index(:channel_messages, [:reply_to_id],
             where: "reply_to_id IS NOT NULL",
             name: :channel_messages_reply_to_index
           )

    # Exclude soft-deleted messages from default scans
    create index(:channel_messages, [:channel_id],
             where: "deleted_at IS NULL",
             name: :channel_messages_not_deleted_index
           )

    # GIN on mentions array — "show messages mentioning @me"
    execute """
    CREATE INDEX channel_messages_mentions_gin_index
    ON channel_messages USING GIN (mentions)
    """

    # -------------------------------------------------------------------------
    # channel_reactions
    # -------------------------------------------------------------------------
    create table(:channel_reactions, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")

      add :message_id,
          references(:channel_messages, type: :binary_id, on_delete: :delete_all),
          null: false

      add :actor_type, :string, null: false
      add :actor_id, :string, null: false
      add :emoji, :string, null: false

      # inserted_at only — reactions are immutable once created
      add :inserted_at, :utc_datetime, null: false, default: fragment("now()")
    end

    # One reaction per (message, actor, emoji) — no double-reacting
    create unique_index(:channel_reactions, [:message_id, :actor_type, :actor_id, :emoji],
             name: :channel_reactions_unique_index
           )

    create index(:channel_reactions, [:message_id], name: :channel_reactions_message_index)

    # -------------------------------------------------------------------------
    # channel_pins
    # -------------------------------------------------------------------------
    create table(:channel_pins, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")

      add :channel_id,
          references(:channels, type: :binary_id, on_delete: :delete_all),
          null: false

      add :message_id,
          references(:channel_messages, type: :binary_id, on_delete: :delete_all),
          null: false

      add :pinned_by_user_id, :binary_id, null: false
      add :pinned_at, :utc_datetime, null: false

      add :inserted_at, :utc_datetime, null: false, default: fragment("now()")
    end

    # A message can only be pinned once per channel
    create unique_index(:channel_pins, [:channel_id, :message_id],
             name: :channel_pins_unique_index
           )

    create index(:channel_pins, [:channel_id], name: :channel_pins_channel_index)
  end

  def down do
    execute "DROP INDEX IF EXISTS channel_messages_mentions_gin_index"

    drop table(:channel_pins)
    drop table(:channel_reactions)
    drop table(:channel_messages)
    drop table(:channel_members)
    drop table(:channels)
  end
end
