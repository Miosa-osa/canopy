defmodule CanopyWeb.ChannelsControllerTest do
  @moduledoc """
  Controller tests for CanopyWeb.ChannelsController.

  Covers all 18 endpoints: channel CRUD, membership, messages, reactions,
  pins, mark-read, and unread count.
  """

  use CanopyWeb.ConnCase, async: true

  import Plug.Conn, only: [assign: 3]

  alias Canopy.Channels

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp uuid, do: Ecto.UUID.generate()

  defp with_user(conn, uid \\ nil) do
    uid = uid || uuid()
    assign(conn, :current_user, %{id: uid})
  end

  defp slug, do: "ch-#{:rand.uniform(999_999)}"

  defp create_channel!(overrides \\ %{}) do
    {:ok, ch} =
      Channels.create(Map.merge(%{slug: slug(), name: "Test", visibility: "public"}, overrides))

    ch
  end

  defp create_message!(channel_id, overrides \\ %{}) do
    {:ok, msg} =
      Channels.create_message(
        Map.merge(
          %{
            channel_id: channel_id,
            author_type: "user",
            author_id: uuid(),
            body_markdown: "Hello"
          },
          overrides
        )
      )

    msg
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/channels
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/channels" do
    test "returns 200 with list of public channels", %{conn: conn} do
      ch = create_channel!()
      conn = get(conn, "/api/v1/channels")
      body = json_response(conn, 200)
      ids = Enum.map(body["data"], & &1["id"])
      assert ch.id in ids
    end

    test "filters by workspace_slug", %{conn: conn} do
      ch = create_channel!(%{workspace_slug: "ws-1"})
      _other = create_channel!(%{workspace_slug: "ws-2"})

      conn = get(conn, "/api/v1/channels?workspace_slug=ws-1")
      body = json_response(conn, 200)
      ids = Enum.map(body["data"], & &1["id"])
      assert ch.id in ids
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/channels
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/channels" do
    test "creates a channel and returns 201", %{conn: conn} do
      conn = with_user(conn)
      s = slug()

      conn =
        post(conn, "/api/v1/channels", %{
          "slug" => s,
          "name" => "New Channel",
          "visibility" => "public"
        })

      body = json_response(conn, 201)
      assert body["data"]["slug"] == s
    end

    test "returns 422 on missing slug", %{conn: conn} do
      conn = with_user(conn)
      conn = post(conn, "/api/v1/channels", %{"name" => "No slug"})
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/channels/:id
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/channels/:id" do
    test "returns 200 for public channel", %{conn: conn} do
      ch = create_channel!()
      conn = get(conn, "/api/v1/channels/#{ch.id}")
      body = json_response(conn, 200)
      assert body["data"]["id"] == ch.id
    end

    test "returns 200 for channel looked up by slug", %{conn: conn} do
      ch = create_channel!()
      conn = get(conn, "/api/v1/channels/#{ch.slug}")
      assert json_response(conn, 200)["data"]["slug"] == ch.slug
    end

    test "returns 404 for unknown channel", %{conn: conn} do
      conn = get(conn, "/api/v1/channels/#{uuid()}")
      assert json_response(conn, 404)
    end

    test "returns 404 for private channel without auth", %{conn: conn} do
      ch = create_channel!(%{visibility: "private"})
      conn = get(conn, "/api/v1/channels/#{ch.id}")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/channels/:id
  # ---------------------------------------------------------------------------

  describe "PATCH /api/v1/channels/:id" do
    test "updates channel name and returns 200", %{conn: conn} do
      ch = create_channel!()
      conn = patch(conn, "/api/v1/channels/#{ch.id}", %{"name" => "Renamed"})
      body = json_response(conn, 200)
      assert body["data"]["name"] == "Renamed"
    end

    test "returns 404 for unknown channel", %{conn: conn} do
      conn = patch(conn, "/api/v1/channels/#{uuid()}", %{"name" => "x"})
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/channels/:id (archive)
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/channels/:id" do
    test "archives the channel and returns 200", %{conn: conn} do
      ch = create_channel!()
      conn = delete(conn, "/api/v1/channels/#{ch.id}")
      body = json_response(conn, 200)
      assert body["data"]["archived_at"] != nil
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/channels/:id/members
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/channels/:id/members" do
    test "adds a user member and returns 201", %{conn: conn} do
      ch = create_channel!()
      uid = uuid()

      conn =
        post(conn, "/api/v1/channels/#{ch.id}/members", %{
          "actor_type" => "user",
          "actor_id" => uid
        })

      body = json_response(conn, 201)
      assert body["data"]["actor_type"] == "user"
      assert body["data"]["actor_id"] == uid
    end

    test "adds an agent member", %{conn: conn} do
      ch = create_channel!()

      conn =
        post(conn, "/api/v1/channels/#{ch.id}/members", %{
          "actor_type" => "agent",
          "actor_id" => "test-agent"
        })

      assert json_response(conn, 201)["data"]["actor_type"] == "agent"
    end

    test "returns 422 on duplicate membership", %{conn: conn} do
      ch = create_channel!()
      uid = uuid()

      post(conn, "/api/v1/channels/#{ch.id}/members", %{"actor_type" => "user", "actor_id" => uid})

      conn =
        post(conn, "/api/v1/channels/#{ch.id}/members", %{
          "actor_type" => "user",
          "actor_id" => uid
        })

      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/channels/:id/members/:actor_type/:actor_id
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/channels/:id/members/:actor_type/:actor_id" do
    test "removes a member and returns 200", %{conn: conn} do
      ch = create_channel!()
      uid = uuid()
      Channels.add_member(ch.id, %{actor_type: "user", actor_id: uid})

      conn = delete(conn, "/api/v1/channels/#{ch.id}/members/user/#{uid}")
      assert json_response(conn, 200)
    end

    test "returns 404 when actor is not a member", %{conn: conn} do
      ch = create_channel!()
      conn = delete(conn, "/api/v1/channels/#{ch.id}/members/user/#{uuid()}")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/channels/:id/messages
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/channels/:id/messages" do
    test "returns 200 with messages and has_more", %{conn: conn} do
      ch = create_channel!()
      create_message!(ch.id)

      conn = get(conn, "/api/v1/channels/#{ch.id}/messages")
      body = json_response(conn, 200)
      assert is_list(body["data"])
      assert is_boolean(body["has_more"])
    end

    test "returns 404 for unknown or private channel without access", %{conn: conn} do
      priv = create_channel!(%{visibility: "private"})
      conn = get(conn, "/api/v1/channels/#{priv.id}/messages")
      assert json_response(conn, 404)
    end

    test "respects limit param", %{conn: conn} do
      ch = create_channel!()
      for _ <- 1..5, do: create_message!(ch.id)

      conn = get(conn, "/api/v1/channels/#{ch.id}/messages?limit=3")
      body = json_response(conn, 200)
      assert length(body["data"]) == 3
      assert body["has_more"] == true
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/channels/:id/messages
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/channels/:id/messages" do
    test "creates a message and returns 201", %{conn: conn} do
      ch = create_channel!()
      uid = uuid()
      conn = with_user(conn, uid)

      conn =
        post(conn, "/api/v1/channels/#{ch.id}/messages", %{
          "body_markdown" => "Hello from test"
        })

      body = json_response(conn, 201)
      assert body["data"]["body_markdown"] == "Hello from test"
    end

    test "creates a reply with reply_to_id", %{conn: conn} do
      ch = create_channel!()
      parent = create_message!(ch.id)
      conn = with_user(conn)

      conn =
        post(conn, "/api/v1/channels/#{ch.id}/messages", %{
          "body_markdown" => "A reply",
          "reply_to_id" => parent.id
        })

      body = json_response(conn, 201)
      assert body["data"]["reply_to_id"] == parent.id
    end

    test "returns 422 on empty body", %{conn: conn} do
      ch = create_channel!()
      conn = with_user(conn)
      conn = post(conn, "/api/v1/channels/#{ch.id}/messages", %{"body_markdown" => ""})
      # empty string fails min-length validation
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/channels/:id/messages/:message_id
  # ---------------------------------------------------------------------------

  describe "PATCH /api/v1/channels/:id/messages/:message_id" do
    test "edits a message", %{conn: conn} do
      ch = create_channel!()
      msg = create_message!(ch.id)

      conn =
        patch(conn, "/api/v1/channels/#{ch.id}/messages/#{msg.id}", %{
          "body_markdown" => "Edited content"
        })

      body = json_response(conn, 200)
      assert body["data"]["body_markdown"] == "Edited content"
      assert body["data"]["edited_at"] != nil
    end

    test "returns 404 for unknown message", %{conn: conn} do
      ch = create_channel!()

      conn =
        patch(conn, "/api/v1/channels/#{ch.id}/messages/#{uuid()}", %{
          "body_markdown" => "x"
        })

      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/channels/:id/messages/:message_id
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/channels/:id/messages/:message_id" do
    test "soft-deletes a message", %{conn: conn} do
      ch = create_channel!()
      msg = create_message!(ch.id)

      conn = delete(conn, "/api/v1/channels/#{ch.id}/messages/#{msg.id}")
      body = json_response(conn, 200)
      assert body["data"]["body_markdown"] == "[deleted]"
      assert body["data"]["deleted_at"] != nil
    end

    test "returns 404 for unknown message", %{conn: conn} do
      ch = create_channel!()
      conn = delete(conn, "/api/v1/channels/#{ch.id}/messages/#{uuid()}")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/channels/:id/messages/:message_id/reactions
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/channels/:id/messages/:message_id/reactions" do
    test "adds a reaction and returns 201", %{conn: conn} do
      ch = create_channel!()
      msg = create_message!(ch.id)
      uid = uuid()
      conn = with_user(conn, uid)

      conn =
        post(conn, "/api/v1/channels/#{ch.id}/messages/#{msg.id}/reactions", %{"emoji" => "heart"})

      body = json_response(conn, 201)
      assert body["data"]["emoji"] == "heart"
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/channels/:id/messages/:message_id/reactions/:emoji
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/channels/:id/messages/:message_id/reactions/:emoji" do
    test "removes a reaction and returns 200", %{conn: conn} do
      ch = create_channel!()
      msg = create_message!(ch.id)
      uid = uuid()

      Channels.add_reaction(%{
        message_id: msg.id,
        actor_type: "user",
        actor_id: uid,
        emoji: "fire"
      })

      conn = with_user(conn, uid)
      conn = delete(conn, "/api/v1/channels/#{ch.id}/messages/#{msg.id}/reactions/fire")
      assert json_response(conn, 200)
    end
  end

  # ---------------------------------------------------------------------------
  # POST/DELETE /api/v1/channels/:id/messages/:message_id/pin
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/channels/:id/messages/:message_id/pin" do
    test "pins a message and returns 201", %{conn: conn} do
      ch = create_channel!()
      msg = create_message!(ch.id)
      conn = with_user(conn)

      conn = post(conn, "/api/v1/channels/#{ch.id}/messages/#{msg.id}/pin")
      body = json_response(conn, 201)
      assert body["data"]["message_id"] == msg.id
    end
  end

  describe "DELETE /api/v1/channels/:id/messages/:message_id/pin" do
    test "unpins a message and returns 200", %{conn: conn} do
      ch = create_channel!()
      msg = create_message!(ch.id)
      uid = uuid()
      Channels.pin_message(ch.id, msg.id, uid)

      conn = delete(conn, "/api/v1/channels/#{ch.id}/messages/#{msg.id}/pin")
      assert json_response(conn, 200)
    end

    test "returns 404 when message is not pinned", %{conn: conn} do
      ch = create_channel!()
      msg = create_message!(ch.id)
      conn = delete(conn, "/api/v1/channels/#{ch.id}/messages/#{msg.id}/pin")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/channels/:id/read
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/channels/:id/read" do
    test "returns 404 for non-member actor", %{conn: conn} do
      ch = create_channel!()
      conn = with_user(conn)
      conn = post(conn, "/api/v1/channels/#{ch.id}/read")
      assert json_response(conn, 404)
    end

    test "marks channel read for a member", %{conn: conn} do
      ch = create_channel!()
      uid = uuid()
      Channels.add_member(ch.id, %{actor_type: "user", actor_id: uid})

      conn = with_user(conn, uid)
      conn = post(conn, "/api/v1/channels/#{ch.id}/read")
      body = json_response(conn, 200)
      assert body["data"]["actor_id"] == uid
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/channels/:id/unread
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/channels/:id/unread" do
    test "returns unread count as integer", %{conn: conn} do
      ch = create_channel!()
      conn = with_user(conn)
      conn = get(conn, "/api/v1/channels/#{ch.id}/unread")
      body = json_response(conn, 200)
      assert is_integer(body["count"])
    end
  end
end
