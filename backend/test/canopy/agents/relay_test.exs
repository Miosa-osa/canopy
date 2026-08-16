defmodule Canopy.Agents.RelayTest do
  use Canopy.DataCase, async: true

  alias Canopy.Agents.Relay

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp register!(slug, ctx \\ %{}) do
    {:ok, p} = Relay.register_participant(slug, ctx)
    p
  end

  defp send!(attrs) do
    {:ok, msg} = Relay.send_message(attrs)
    msg
  end

  # ---------------------------------------------------------------------------
  # Participants
  # ---------------------------------------------------------------------------

  describe "register_participant/2" do
    test "creates a new participant" do
      {:ok, p} = Relay.register_participant("backend-elixir")
      assert p.agent_slug == "backend-elixir"
      assert p.status == "online"
    end

    test "upserts an existing participant" do
      register!("backend-elixir")
      {:ok, p2} = Relay.register_participant("backend-elixir", %{summary: "refactoring"})
      assert p2.work_context["summary"] == "refactoring"
    end

    test "sets last_seen_at on registration" do
      {:ok, p} = Relay.register_participant("atlas")
      assert %DateTime{} = p.last_seen_at
    end
  end

  describe "update_status/2" do
    test "changes status to busy" do
      register!("iris")
      {:ok, p} = Relay.update_status("iris", "busy")
      assert p.status == "busy"
    end

    test "returns :not_found for unknown agent" do
      assert {:error, :not_found} = Relay.update_status("ghost", "online")
    end

    test "rejects invalid status" do
      register!("conductor")
      assert {:error, %Ecto.Changeset{}} = Relay.update_status("conductor", "sleeping")
    end
  end

  describe "update_work_context/2" do
    test "replaces work context map" do
      register!("forge")
      ctx = %{"branch" => "feat/relay", "files" => ["relay.ex"], "topics" => ["relay"]}
      {:ok, p} = Relay.update_work_context("forge", ctx)
      assert p.work_context["branch"] == "feat/relay"
    end

    test "returns :not_found for unknown agent" do
      assert {:error, :not_found} = Relay.update_work_context("nobody", %{})
    end
  end

  describe "list_participants/0" do
    test "returns all participants ordered by slug" do
      register!("zzz-last")
      register!("aaa-first")
      slugs = Relay.list_participants() |> Enum.map(& &1.agent_slug)
      aaa_idx = Enum.find_index(slugs, &(&1 == "aaa-first"))
      zzz_idx = Enum.find_index(slugs, &(&1 == "zzz-last"))
      assert aaa_idx < zzz_idx
    end
  end

  # ---------------------------------------------------------------------------
  # Direct messages
  # ---------------------------------------------------------------------------

  describe "send_message/1 — direct" do
    test "creates a direct message" do
      {:ok, msg} =
        Relay.send_message(%{
          from_agent_slug: "forge",
          to_agent_slug: "atlas",
          scope: "direct",
          priority: "normal",
          content: "hey, need review on PR #42"
        })

      assert msg.from_agent_slug == "forge"
      assert msg.to_agent_slug == "atlas"
      assert msg.scope == "direct"
      assert is_nil(msg.read_at)
      assert is_binary(msg.thread_id)
    end

    test "auto-assigns thread_id when not provided" do
      msg = send!(%{from_agent_slug: "a", to_agent_slug: "b", scope: "direct", content: "hi"})
      assert is_binary(msg.thread_id)
      assert byte_size(msg.thread_id) > 0
    end

    test "preserves provided thread_id" do
      msg =
        send!(%{
          from_agent_slug: "a",
          to_agent_slug: "b",
          scope: "direct",
          content: "reply",
          thread_id: "my-thread"
        })

      assert msg.thread_id == "my-thread"
    end

    test "rejects message with empty content" do
      assert {:error, %Ecto.Changeset{}} =
               Relay.send_message(%{
                 from_agent_slug: "a",
                 to_agent_slug: "b",
                 scope: "direct",
                 content: ""
               })
    end

    test "rejects invalid priority" do
      assert {:error, %Ecto.Changeset{}} =
               Relay.send_message(%{
                 from_agent_slug: "a",
                 to_agent_slug: "b",
                 scope: "direct",
                 content: "hi",
                 priority: "extreme"
               })
    end
  end

  # ---------------------------------------------------------------------------
  # Inbox
  # ---------------------------------------------------------------------------

  describe "list_inbox/2" do
    test "returns only unread messages addressed to agent" do
      send!(%{from_agent_slug: "forge", to_agent_slug: "atlas", scope: "direct", content: "msg1"})
      send!(%{from_agent_slug: "iris", to_agent_slug: "atlas", scope: "direct", content: "msg2"})
      # not for atlas
      send!(%{
        from_agent_slug: "forge",
        to_agent_slug: "other",
        scope: "direct",
        content: "other"
      })

      inbox = Relay.list_inbox("atlas")
      assert length(inbox) == 2
      assert Enum.all?(inbox, &(&1.to_agent_slug == "atlas"))
    end

    test "excludes read messages" do
      msg =
        send!(%{
          from_agent_slug: "forge",
          to_agent_slug: "atlas",
          scope: "direct",
          content: "read me"
        })

      {:ok, _} = Relay.mark_read(msg.id)

      inbox = Relay.list_inbox("atlas")
      refute Enum.any?(inbox, &(&1.id == msg.id))
    end

    test "orders by priority then timestamp" do
      send!(%{
        from_agent_slug: "a",
        to_agent_slug: "target",
        scope: "direct",
        content: "low",
        priority: "low"
      })

      send!(%{
        from_agent_slug: "a",
        to_agent_slug: "target",
        scope: "direct",
        content: "urgent",
        priority: "urgent"
      })

      send!(%{
        from_agent_slug: "a",
        to_agent_slug: "target",
        scope: "direct",
        content: "high",
        priority: "high"
      })

      inbox = Relay.list_inbox("target")
      priorities = Enum.map(inbox, & &1.priority)
      assert priorities == ["urgent", "high", "low"]
    end

    test "respects limit option" do
      for i <- 1..5 do
        send!(%{
          from_agent_slug: "a",
          to_agent_slug: "limited",
          scope: "direct",
          content: "msg #{i}"
        })
      end

      inbox = Relay.list_inbox("limited", limit: 3)
      assert length(inbox) == 3
    end
  end

  # ---------------------------------------------------------------------------
  # mark_read/1
  # ---------------------------------------------------------------------------

  describe "mark_read/1" do
    test "sets read_at timestamp" do
      msg = send!(%{from_agent_slug: "a", to_agent_slug: "b", scope: "direct", content: "hello"})
      {:ok, updated} = Relay.mark_read(msg.id)
      assert %DateTime{} = updated.read_at
    end

    test "returns :not_found for unknown id" do
      assert {:error, :not_found} = Relay.mark_read(Ecto.UUID.generate())
    end
  end

  # ---------------------------------------------------------------------------
  # Thread grouping
  # ---------------------------------------------------------------------------

  describe "list_thread/1" do
    test "returns all messages in a thread oldest-first" do
      thread = "t-abc"

      msg1 =
        send!(%{
          from_agent_slug: "a",
          to_agent_slug: "b",
          scope: "direct",
          content: "first",
          thread_id: thread
        })

      msg2 =
        send!(%{
          from_agent_slug: "b",
          to_agent_slug: "a",
          scope: "direct",
          content: "reply",
          thread_id: thread
        })

      # different thread
      send!(%{
        from_agent_slug: "a",
        to_agent_slug: "c",
        scope: "direct",
        content: "other",
        thread_id: "other-thread"
      })

      thread_msgs = Relay.list_thread(thread)
      assert length(thread_msgs) == 2
      ids = Enum.map(thread_msgs, & &1.id)
      assert msg1.id in ids
      assert msg2.id in ids
    end
  end

  # ---------------------------------------------------------------------------
  # Channels
  # ---------------------------------------------------------------------------

  describe "create_channel/2" do
    test "creates a channel with members" do
      {:ok, ch} = Relay.create_channel("general", ["forge", "atlas"])
      assert ch.name == "general"
      assert "forge" in ch.member_slugs
    end

    test "rejects duplicate channel names" do
      {:ok, _} = Relay.create_channel("unique-ch")
      assert {:error, %Ecto.Changeset{}} = Relay.create_channel("unique-ch")
    end

    test "rejects invalid channel name format" do
      assert {:error, %Ecto.Changeset{}} = Relay.create_channel("Has Spaces!")
    end
  end

  describe "join_channel/2 and leave_channel/2" do
    test "adds agent to member list" do
      {:ok, _} = Relay.create_channel("ops", [])
      {:ok, ch} = Relay.join_channel("ops", "iris")
      assert "iris" in ch.member_slugs
    end

    test "join is idempotent" do
      {:ok, _} = Relay.create_channel("ops2", ["iris"])
      {:ok, ch} = Relay.join_channel("ops2", "iris")
      assert Enum.count(ch.member_slugs, &(&1 == "iris")) == 1
    end

    test "removes agent from member list" do
      {:ok, _} = Relay.create_channel("eng", ["forge", "atlas"])
      {:ok, ch} = Relay.leave_channel("eng", "forge")
      refute "forge" in ch.member_slugs
      assert "atlas" in ch.member_slugs
    end

    test "leave is idempotent" do
      {:ok, _} = Relay.create_channel("eng2", ["atlas"])
      {:ok, ch} = Relay.leave_channel("eng2", "nobody")
      assert "atlas" in ch.member_slugs
    end

    test "returns :not_found for unknown channel" do
      assert {:error, :not_found} = Relay.join_channel("no-such-ch", "iris")
      assert {:error, :not_found} = Relay.leave_channel("no-such-ch", "iris")
    end
  end

  describe "broadcast/3" do
    test "sends a message to each channel member" do
      {:ok, _} = Relay.create_channel("alerts", ["forge", "atlas", "iris"])
      {:ok, messages} = Relay.broadcast("alerts", "conductor", "deploy complete")

      assert length(messages) == 3
      recipients = Enum.map(messages, & &1.to_agent_slug)
      assert "forge" in recipients
      assert "atlas" in recipients
      assert "iris" in recipients
    end

    test "each message has channel in metadata" do
      {:ok, _} = Relay.create_channel("meta-ch", ["a"])
      {:ok, [msg]} = Relay.broadcast("meta-ch", "sender", "hello")
      assert msg.metadata["channel"] == "meta-ch"
    end

    test "returns :not_found for unknown channel" do
      assert {:error, :not_found} = Relay.broadcast("ghost-ch", "sender", "hi")
    end
  end

  # ---------------------------------------------------------------------------
  # PubSub broadcasts
  # ---------------------------------------------------------------------------

  describe "PubSub delivery" do
    test "direct message triggers relay:<to_slug> broadcast" do
      Phoenix.PubSub.subscribe(Canopy.PubSub, "relay:pubsub-target")

      send!(%{
        from_agent_slug: "sender",
        to_agent_slug: "pubsub-target",
        scope: "direct",
        content: "ping"
      })

      assert_receive {:relay_message, msg}, 500
      assert msg.to_agent_slug == "pubsub-target"
    end

    test "channel broadcast triggers relay:channel:<name> broadcast" do
      Phoenix.PubSub.subscribe(Canopy.PubSub, "relay:channel:pubsub-ch")
      {:ok, _} = Relay.create_channel("pubsub-ch", ["member-a"])
      {:ok, _} = Relay.broadcast("pubsub-ch", "broadcaster", "channel message")

      assert_receive {:relay_broadcast, payload}, 500
      assert payload.channel == "pubsub-ch"
      assert payload.content == "channel message"
    end
  end
end
