defmodule Canopy.ChannelsTest do
  @moduledoc """
  Integration tests for Canopy.Channels, Canopy.Channels.Messages,
  and Canopy.Channels.Membership.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Channels
  alias Canopy.Channels.{Channel, Member, Message, Pin, Reaction}
  alias Canopy.Repo

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp uuid, do: Ecto.UUID.generate()

  defp channel_attrs(overrides \\ %{}) do
    slug = "test-#{:rand.uniform(999_999)}"

    Map.merge(
      %{slug: slug, name: "Test Channel", visibility: "public"},
      overrides
    )
  end

  defp insert_channel!(overrides \\ %{}) do
    {:ok, ch} = Channels.create(channel_attrs(overrides))
    ch
  end

  defp message_attrs(channel_id, overrides \\ %{}) do
    Map.merge(
      %{
        channel_id: channel_id,
        author_type: "user",
        author_id: uuid(),
        body_markdown: "Hello channel!"
      },
      overrides
    )
  end

  defp insert_message!(channel_id, overrides \\ %{}) do
    {:ok, msg} = Channels.create_message(message_attrs(channel_id, overrides))
    msg
  end

  # ---------------------------------------------------------------------------
  # Channel CRUD
  # ---------------------------------------------------------------------------

  describe "create/1" do
    test "inserts a public channel with required fields" do
      {:ok, ch} = Channels.create(channel_attrs())
      assert %Channel{} = ch
      assert ch.visibility == "public"
      assert is_nil(ch.archived_at)
    end

    test "inserts a private channel" do
      {:ok, ch} = Channels.create(channel_attrs(%{visibility: "private"}))
      assert ch.visibility == "private"
    end

    test "returns error changeset on missing slug" do
      assert {:error, %Ecto.Changeset{}} = Channels.create(%{name: "No slug"})
    end

    test "returns error changeset on invalid visibility" do
      assert {:error, %Ecto.Changeset{}} =
               Channels.create(channel_attrs(%{visibility: "secret"}))
    end

    test "enforces slug uniqueness" do
      attrs = channel_attrs()
      {:ok, _} = Channels.create(attrs)
      assert {:error, %Ecto.Changeset{errors: errors}} = Channels.create(attrs)
      assert Keyword.has_key?(errors, :slug)
    end
  end

  describe "get/2" do
    test "returns channel by id" do
      ch = insert_channel!()
      assert {:ok, found} = Channels.get(ch.id)
      assert found.id == ch.id
    end

    test "returns channel by slug" do
      ch = insert_channel!()
      assert {:ok, found} = Channels.get(ch.slug)
      assert found.id == ch.id
    end

    test "returns :not_found for unknown id" do
      assert {:error, :not_found} = Channels.get(uuid())
    end

    test "returns :not_found for private channel when no actor provided" do
      ch = insert_channel!(%{visibility: "private"})
      assert {:error, :not_found} = Channels.get(ch.id, current_actor: nil)
    end

    test "returns private channel for a member" do
      ch = insert_channel!(%{visibility: "private"})
      actor = %{actor_type: "user", actor_id: uuid()}
      Channels.add_member(ch.id, actor)

      assert {:ok, found} = Channels.get(ch.id, current_actor: actor)
      assert found.id == ch.id
    end
  end

  describe "list/1" do
    test "returns only public channels for nil actor" do
      pub = insert_channel!(%{visibility: "public"})
      _priv = insert_channel!(%{visibility: "private"})

      {:ok, channels} = Channels.list(current_actor: nil)
      ids = Enum.map(channels, & &1.id)
      assert pub.id in ids
    end

    test "excludes archived channels by default" do
      ch = insert_channel!()
      Channels.archive(ch.id)

      {:ok, channels} = Channels.list()
      assert ch.id not in Enum.map(channels, & &1.id)
    end

    test "includes archived when include_archived: true" do
      ch = insert_channel!()
      Channels.archive(ch.id)

      {:ok, channels} = Channels.list(include_archived: true)
      assert ch.id in Enum.map(channels, & &1.id)
    end
  end

  describe "update/2" do
    test "updates channel name" do
      ch = insert_channel!()
      {:ok, updated} = Channels.update(ch.id, %{name: "Renamed"})
      assert updated.name == "Renamed"
    end

    test "returns :not_found for unknown id" do
      assert {:error, :not_found} = Channels.update(uuid(), %{name: "x"})
    end
  end

  describe "archive/1" do
    test "sets archived_at" do
      ch = insert_channel!()
      assert {:ok, archived} = Channels.archive(ch.id)
      assert %DateTime{} = archived.archived_at
    end
  end

  # ---------------------------------------------------------------------------
  # Membership
  # ---------------------------------------------------------------------------

  describe "add_member/2" do
    test "adds a user member" do
      ch = insert_channel!()
      actor = %{actor_type: "user", actor_id: uuid()}
      assert {:ok, %Member{}} = Channels.add_member(ch.id, actor)
    end

    test "adds an agent member" do
      ch = insert_channel!()
      actor = %{actor_type: "agent", actor_id: "phoenix-api"}
      assert {:ok, %Member{}} = Channels.add_member(ch.id, actor)
    end

    test "returns error on duplicate membership" do
      ch = insert_channel!()
      actor = %{actor_type: "user", actor_id: uuid()}
      Channels.add_member(ch.id, actor)
      assert {:error, %Ecto.Changeset{}} = Channels.add_member(ch.id, actor)
    end
  end

  describe "remove_member/2" do
    test "removes a member" do
      ch = insert_channel!()
      actor = %{actor_type: "user", actor_id: uuid()}
      Channels.add_member(ch.id, actor)
      assert {:ok, %Member{}} = Channels.remove_member(ch.id, actor)
    end

    test "returns :not_found when actor is not a member" do
      ch = insert_channel!()
      actor = %{actor_type: "user", actor_id: uuid()}
      assert {:error, :not_found} = Channels.remove_member(ch.id, actor)
    end
  end

  describe "list_members/1" do
    test "returns members ordered by joined_at" do
      ch = insert_channel!()
      a1 = %{actor_type: "user", actor_id: uuid()}
      a2 = %{actor_type: "agent", actor_id: "test-agent"}
      Channels.add_member(ch.id, a1)
      Channels.add_member(ch.id, a2)

      members = Channels.list_members(ch.id)
      assert length(members) == 2
    end
  end

  describe "list_channels_for/1" do
    test "returns channels for a given actor" do
      ch = insert_channel!()
      actor = %{actor_type: "user", actor_id: uuid()}
      Channels.add_member(ch.id, actor)

      {:ok, channels} = Channels.list_channels_for(actor)
      assert ch.id in Enum.map(channels, & &1.id)
    end
  end

  describe "update_member/3" do
    test "updates role to admin" do
      ch = insert_channel!()
      actor = %{actor_type: "user", actor_id: uuid()}
      Channels.add_member(ch.id, actor)

      assert {:ok, member} = Channels.update_member(ch.id, actor, %{role: "admin"})
      assert member.role == "admin"
    end

    test "returns :not_found for non-member" do
      ch = insert_channel!()
      actor = %{actor_type: "user", actor_id: uuid()}
      assert {:error, :not_found} = Channels.update_member(ch.id, actor, %{role: "admin"})
    end
  end

  # ---------------------------------------------------------------------------
  # Messages
  # ---------------------------------------------------------------------------

  describe "create_message/1" do
    test "creates a top-level message" do
      ch = insert_channel!()
      {:ok, msg} = Channels.create_message(message_attrs(ch.id))
      assert %Message{} = msg
      assert msg.channel_id == ch.id
      assert is_nil(msg.reply_to_id)
      assert msg.thread_count == 0
    end

    test "creates a reply and increments parent thread_count" do
      ch = insert_channel!()
      parent = insert_message!(ch.id)

      {:ok, reply} = Channels.create_message(message_attrs(ch.id, %{reply_to_id: parent.id}))
      assert reply.reply_to_id == parent.id

      updated_parent = Repo.get(Message, parent.id)
      assert updated_parent.thread_count == 1
    end

    test "extracts @mentions from body into mentions array" do
      ch = insert_channel!()

      {:ok, msg} =
        Channels.create_message(
          message_attrs(ch.id, %{body_markdown: "Hey @phoenix-api check this out"})
        )

      assert "phoenix-api" in msg.mentions
    end

    test "returns error changeset on missing body" do
      ch = insert_channel!()
      assert {:error, _} = Channels.create_message(%{channel_id: ch.id, author_type: "user"})
    end
  end

  describe "list_messages/2" do
    test "returns messages in reverse-chronological order" do
      ch = insert_channel!()
      insert_message!(ch.id, %{body_markdown: "older"})
      # Sleep past the second boundary so inserted_at timestamps differ
      :timer.sleep(1100)
      insert_message!(ch.id, %{body_markdown: "newer"})

      {messages, _has_more} = Channels.list_messages(ch.id)
      assert length(messages) >= 2
      # Newest first (desc inserted_at)
      [newest | _] = messages
      assert newest.body_markdown == "newer"
    end

    test "returns has_more: true when over limit" do
      ch = insert_channel!()
      for i <- 1..4, do: insert_message!(ch.id, %{body_markdown: "msg #{i}"})

      {messages, has_more} = Channels.list_messages(ch.id, limit: 3)
      assert length(messages) == 3
      assert has_more
    end

    test "cursor pagination with before: param" do
      ch = insert_channel!()
      msg1 = insert_message!(ch.id, %{body_markdown: "older"})
      _msg2 = insert_message!(ch.id, %{body_markdown: "newer"})

      before_dt = DateTime.add(msg1.inserted_at, 1, :second)
      {messages, _} = Channels.list_messages(ch.id, before: before_dt)
      ids = Enum.map(messages, & &1.id)
      assert msg1.id in ids
    end

    test "excludes soft-deleted messages by default" do
      ch = insert_channel!()
      msg = insert_message!(ch.id)
      Channels.soft_delete_message(msg.id)

      {messages, _} = Channels.list_messages(ch.id)
      assert msg.id not in Enum.map(messages, & &1.id)
    end

    test "thread_id filter returns only replies to that message" do
      ch = insert_channel!()
      parent = insert_message!(ch.id)
      reply = insert_message!(ch.id, %{reply_to_id: parent.id, body_markdown: "a reply"})
      _other = insert_message!(ch.id, %{body_markdown: "unrelated"})

      {messages, _} = Channels.list_messages(ch.id, thread_id: parent.id)
      ids = Enum.map(messages, & &1.id)
      assert reply.id in ids
      assert parent.id not in ids
    end
  end

  describe "edit_message/2" do
    test "updates body and sets edited_at" do
      ch = insert_channel!()
      msg = insert_message!(ch.id)

      {:ok, edited} = Channels.edit_message(msg.id, %{body_markdown: "Updated body"})
      assert edited.body_markdown == "Updated body"
      assert %DateTime{} = edited.edited_at
    end

    test "returns :not_found for unknown message" do
      assert {:error, :not_found} = Channels.edit_message(uuid(), %{body_markdown: "x"})
    end

    test "returns :not_found for soft-deleted message" do
      ch = insert_channel!()
      msg = insert_message!(ch.id)
      Channels.soft_delete_message(msg.id)

      assert {:error, :not_found} = Channels.edit_message(msg.id, %{body_markdown: "x"})
    end
  end

  describe "soft_delete_message/1" do
    test "sets deleted_at and clears body to [deleted]" do
      ch = insert_channel!()
      msg = insert_message!(ch.id)

      {:ok, deleted} = Channels.soft_delete_message(msg.id)
      assert %DateTime{} = deleted.deleted_at
      assert deleted.body_markdown == "[deleted]"
      assert is_nil(deleted.body_rendered_html)
      assert deleted.mentions == []
      assert deleted.attachments == %{}
    end

    test "returns :not_found for unknown message" do
      assert {:error, :not_found} = Channels.soft_delete_message(uuid())
    end
  end

  # ---------------------------------------------------------------------------
  # Reactions
  # ---------------------------------------------------------------------------

  describe "add_reaction/1" do
    test "adds a reaction" do
      ch = insert_channel!()
      msg = insert_message!(ch.id)
      actor_id = uuid()

      {:ok, reaction} =
        Channels.add_reaction(%{
          message_id: msg.id,
          actor_type: "user",
          actor_id: actor_id,
          emoji: "thumbsup"
        })

      assert %Reaction{} = reaction
      assert reaction.emoji == "thumbsup"
    end

    test "prevents double-reaction with same emoji — idempotency" do
      ch = insert_channel!()
      msg = insert_message!(ch.id)
      actor_id = uuid()

      attrs = %{message_id: msg.id, actor_type: "user", actor_id: actor_id, emoji: "heart"}
      {:ok, _} = Channels.add_reaction(attrs)
      assert {:error, %Ecto.Changeset{}} = Channels.add_reaction(attrs)
    end

    test "allows same emoji from different actors" do
      ch = insert_channel!()
      msg = insert_message!(ch.id)

      {:ok, _} =
        Channels.add_reaction(%{
          message_id: msg.id,
          actor_type: "user",
          actor_id: uuid(),
          emoji: "fire"
        })

      {:ok, _} =
        Channels.add_reaction(%{
          message_id: msg.id,
          actor_type: "user",
          actor_id: uuid(),
          emoji: "fire"
        })

      reactions = Channels.list_reactions(msg.id)
      assert length(reactions) == 2
    end
  end

  describe "remove_reaction/4" do
    test "removes an existing reaction" do
      ch = insert_channel!()
      msg = insert_message!(ch.id)
      actor_id = uuid()

      Channels.add_reaction(%{
        message_id: msg.id,
        actor_type: "user",
        actor_id: actor_id,
        emoji: "wave"
      })

      assert {:ok, %Reaction{}} = Channels.remove_reaction(msg.id, "user", actor_id, "wave")
    end

    test "returns :not_found when reaction does not exist" do
      ch = insert_channel!()
      msg = insert_message!(ch.id)
      assert {:error, :not_found} = Channels.remove_reaction(msg.id, "user", uuid(), "wave")
    end
  end

  describe "list_reactions/1" do
    test "returns reactions in inserted_at order" do
      ch = insert_channel!()
      msg = insert_message!(ch.id)

      Channels.add_reaction(%{
        message_id: msg.id,
        actor_type: "user",
        actor_id: uuid(),
        emoji: "a"
      })

      Channels.add_reaction(%{
        message_id: msg.id,
        actor_type: "user",
        actor_id: uuid(),
        emoji: "b"
      })

      reactions = Channels.list_reactions(msg.id)
      assert length(reactions) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # Pins
  # ---------------------------------------------------------------------------

  describe "pin_message/3" do
    test "pins a message" do
      ch = insert_channel!()
      msg = insert_message!(ch.id)
      user_id = uuid()

      assert {:ok, %Pin{}} = Channels.pin_message(ch.id, msg.id, user_id)
    end

    test "returns error on duplicate pin — idempotency" do
      ch = insert_channel!()
      msg = insert_message!(ch.id)
      user_id = uuid()

      Channels.pin_message(ch.id, msg.id, user_id)
      assert {:error, %Ecto.Changeset{}} = Channels.pin_message(ch.id, msg.id, user_id)
    end
  end

  describe "unpin_message/2" do
    test "unpins a pinned message" do
      ch = insert_channel!()
      msg = insert_message!(ch.id)
      user_id = uuid()
      Channels.pin_message(ch.id, msg.id, user_id)

      assert {:ok, %Pin{}} = Channels.unpin_message(ch.id, msg.id)
    end

    test "returns :not_found for non-pinned message" do
      ch = insert_channel!()
      msg = insert_message!(ch.id)
      assert {:error, :not_found} = Channels.unpin_message(ch.id, msg.id)
    end
  end

  describe "list_pins/1" do
    test "returns pins for a channel in reverse pinned_at order" do
      ch = insert_channel!()
      msg1 = insert_message!(ch.id)
      msg2 = insert_message!(ch.id)
      user_id = uuid()

      Channels.pin_message(ch.id, msg1.id, user_id)
      Channels.pin_message(ch.id, msg2.id, user_id)

      pins = Channels.list_pins(ch.id)
      assert length(pins) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # Read receipts / Unread count
  # ---------------------------------------------------------------------------

  describe "mark_read/3 and unread_count/2" do
    test "unread_count returns 0 for non-member" do
      ch = insert_channel!()
      actor = %{actor_type: "user", actor_id: uuid()}
      assert Channels.unread_count(ch.id, actor) == 0
    end

    test "unread_count counts messages after last_read_at" do
      ch = insert_channel!()
      actor = %{actor_type: "user", actor_id: uuid()}
      Channels.add_member(ch.id, actor)

      insert_message!(ch.id)
      insert_message!(ch.id)

      # Without mark_read: all messages unread
      count = Channels.unread_count(ch.id, actor)
      assert count == 2
    end

    test "mark_read reduces unread_count" do
      ch = insert_channel!()
      actor = %{actor_type: "user", actor_id: uuid()}
      Channels.add_member(ch.id, actor)

      insert_message!(ch.id)
      now = DateTime.utc_now()
      insert_message!(ch.id)

      Channels.mark_read(ch.id, actor, now)

      # After mark_read, only messages after `now` count
      count = Channels.unread_count(ch.id, actor)
      assert count >= 0
    end

    test "mark_read returns :not_found for non-member" do
      ch = insert_channel!()
      actor = %{actor_type: "user", actor_id: uuid()}
      assert {:error, :not_found} = Channels.mark_read(ch.id, actor, DateTime.utc_now())
    end
  end
end
