defmodule CanopyWeb.ChannelsController do
  @moduledoc """
  HTTP API for Canopy channels.

  Routes:
    GET    /api/v1/channels                                   — list channels
    POST   /api/v1/channels                                   — create channel
    GET    /api/v1/channels/:id                               — show channel
    PATCH  /api/v1/channels/:id                               — update channel
    DELETE /api/v1/channels/:id                               — archive channel

    POST   /api/v1/channels/:id/members                       — add member
    DELETE /api/v1/channels/:id/members/:actor_type/:actor_id — remove member

    GET    /api/v1/channels/:id/messages                      — list messages (cursor)
    POST   /api/v1/channels/:id/messages                      — create message
    PATCH  /api/v1/channels/:id/messages/:message_id          — edit message
    DELETE /api/v1/channels/:id/messages/:message_id          — soft-delete message

    POST   /api/v1/channels/:id/messages/:message_id/reactions        — add reaction
    DELETE /api/v1/channels/:id/messages/:message_id/reactions/:emoji — remove reaction

    POST   /api/v1/channels/:id/messages/:message_id/pin   — pin message
    DELETE /api/v1/channels/:id/messages/:message_id/pin   — unpin message

    POST   /api/v1/channels/:id/read    — mark channel read
    GET    /api/v1/channels/:id/unread  — unread count
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Channels
  alias CanopyWeb.Schemas.ChannelsSchema

  action_fallback CanopyWeb.FallbackController

  tags ["channels"]

  # ---------------------------------------------------------------------------
  # Channel CRUD
  # ---------------------------------------------------------------------------

  operation :index,
    summary: "List channels",
    parameters: [
      workspace_slug: [in: :query, type: :string, required: false],
      include_archived: [in: :query, type: :string, required: false]
    ],
    responses: [ok: {"Channel list", "application/json", ChannelsSchema.ChannelList}]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    current_actor = actor_from_conn(conn)
    include_archived = params["include_archived"] == "true"

    {:ok, channels} =
      Channels.list(
        workspace_slug: params["workspace_slug"],
        current_actor: current_actor,
        include_archived: include_archived
      )

    json(conn, %{data: channels})
  end

  operation :create,
    summary: "Create a channel",
    request_body:
      {"Channel attrs", "application/json", ChannelsSchema.CreateChannelRequest, required: true},
    responses: [
      created: {"Created channel", "application/json", ChannelsSchema.ChannelResponse},
      unprocessable_entity: {"Validation error", "application/json", ChannelsSchema.ErrorResponse}
    ]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    attrs = channel_attrs(params, conn)

    case Channels.create(attrs) do
      {:ok, channel} ->
        conn |> put_status(:created) |> json(%{data: channel})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  operation :show,
    summary: "Get a channel",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Channel", "application/json", ChannelsSchema.ChannelResponse},
      not_found: {"Not found", "application/json", ChannelsSchema.ErrorResponse}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    current_actor = actor_from_conn(conn)

    with {:ok, channel} <- Channels.get(id, current_actor: current_actor) do
      json(conn, %{data: channel})
    end
  end

  operation :update,
    summary: "Update a channel",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body:
      {"Update attrs", "application/json", ChannelsSchema.UpdateChannelRequest, required: true},
    responses: [
      ok: {"Updated channel", "application/json", ChannelsSchema.ChannelResponse},
      not_found: {"Not found", "application/json", ChannelsSchema.ErrorResponse},
      unprocessable_entity: {"Validation error", "application/json", ChannelsSchema.ErrorResponse}
    ]

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    attrs = Map.drop(params, ["id"])

    with {:ok, channel} <- Channels.update(id, attrs) do
      json(conn, %{data: channel})
    end
  end

  operation :delete,
    summary: "Archive a channel",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Archived channel", "application/json", ChannelsSchema.ChannelResponse},
      not_found: {"Not found", "application/json", ChannelsSchema.ErrorResponse}
    ]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    with {:ok, channel} <- Channels.archive(id) do
      json(conn, %{data: channel})
    end
  end

  # ---------------------------------------------------------------------------
  # Membership
  # ---------------------------------------------------------------------------

  operation :add_member,
    summary: "Add a member to a channel",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body:
      {"Member attrs", "application/json", ChannelsSchema.AddMemberRequest, required: true},
    responses: [
      created: {"Member", "application/json", ChannelsSchema.MemberResponse},
      unprocessable_entity: {"Error", "application/json", ChannelsSchema.ErrorResponse}
    ]

  @spec add_member(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def add_member(conn, %{"id" => channel_id} = params) do
    actor = %{
      actor_type: params["actor_type"],
      actor_id: params["actor_id"],
      role: params["role"] || "member"
    }

    case Channels.add_member(channel_id, actor) do
      {:ok, member} -> conn |> put_status(:created) |> json(%{data: member})
      {:error, changeset} -> {:error, changeset}
    end
  end

  operation :remove_member,
    summary: "Remove a member from a channel",
    parameters: [
      id: [in: :path, type: :string, required: true],
      actor_type: [in: :path, type: :string, required: true],
      actor_id: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Removed", "application/json", ChannelsSchema.MemberResponse},
      not_found: {"Not found", "application/json", ChannelsSchema.ErrorResponse}
    ]

  @spec remove_member(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def remove_member(conn, %{
        "id" => channel_id,
        "actor_type" => actor_type,
        "actor_id" => actor_id
      }) do
    actor = %{actor_type: actor_type, actor_id: actor_id}

    with {:ok, member} <- Channels.remove_member(channel_id, actor) do
      json(conn, %{data: member})
    end
  end

  # ---------------------------------------------------------------------------
  # Messages
  # ---------------------------------------------------------------------------

  operation :list_messages,
    summary: "List channel messages (cursor pagination)",
    parameters: [
      id: [in: :path, type: :string, required: true],
      before: [in: :query, type: :string, required: false, description: "ISO8601 cursor"],
      limit: [in: :query, type: :integer, required: false],
      thread_id: [in: :query, type: :string, required: false, description: "Fetch thread replies"]
    ],
    responses: [
      ok: {"Messages", "application/json", ChannelsSchema.MessageList},
      not_found: {"Not found", "application/json", ChannelsSchema.ErrorResponse}
    ]

  @spec list_messages(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_messages(conn, %{"id" => channel_id} = params) do
    with {:ok, _channel} <- Channels.get(channel_id, current_actor: actor_from_conn(conn)) do
      before_dt = parse_datetime(params["before"])
      limit = parse_int(params["limit"], 50)
      thread_id = params["thread_id"]

      {messages, has_more} =
        Channels.list_messages(channel_id,
          before: before_dt,
          limit: limit,
          thread_id: thread_id
        )

      json(conn, %{data: messages, has_more: has_more})
    end
  end

  operation :create_message,
    summary: "Post a message to a channel",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body:
      {"Message", "application/json", ChannelsSchema.CreateMessageRequest, required: true},
    responses: [
      created: {"Message", "application/json", ChannelsSchema.MessageResponse},
      unprocessable_entity: {"Error", "application/json", ChannelsSchema.ErrorResponse}
    ]

  @spec create_message(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create_message(conn, %{"id" => channel_id} = params) do
    current_actor = actor_from_conn(conn)

    attrs = %{
      channel_id: channel_id,
      author_type: params["author_type"] || (current_actor && "user") || "system",
      author_id: params["author_id"] || (current_actor && current_actor.actor_id),
      body_markdown: params["body_markdown"],
      reply_to_id: params["reply_to_id"],
      attachments: params["attachments"] || %{}
    }

    case Channels.create_message(attrs) do
      {:ok, message} -> conn |> put_status(:created) |> json(%{data: message})
      {:error, reason} -> {:error, reason}
    end
  end

  operation :edit_message,
    summary: "Edit a channel message",
    parameters: [
      id: [in: :path, type: :string, required: true],
      message_id: [in: :path, type: :string, required: true]
    ],
    request_body:
      {"Edit body", "application/json", ChannelsSchema.EditMessageRequest, required: true},
    responses: [
      ok: {"Message", "application/json", ChannelsSchema.MessageResponse},
      not_found: {"Not found", "application/json", ChannelsSchema.ErrorResponse}
    ]

  @spec edit_message(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit_message(conn, %{"message_id" => message_id} = params) do
    attrs = Map.take(params, ["body_markdown", "body_rendered_html"])

    with {:ok, message} <- Channels.edit_message(message_id, attrs) do
      json(conn, %{data: message})
    end
  end

  operation :delete_message,
    summary: "Soft-delete a channel message",
    parameters: [
      id: [in: :path, type: :string, required: true],
      message_id: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Deleted message", "application/json", ChannelsSchema.MessageResponse},
      not_found: {"Not found", "application/json", ChannelsSchema.ErrorResponse}
    ]

  @spec delete_message(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete_message(conn, %{"message_id" => message_id}) do
    with {:ok, message} <- Channels.soft_delete_message(message_id) do
      json(conn, %{data: message})
    end
  end

  # ---------------------------------------------------------------------------
  # Reactions
  # ---------------------------------------------------------------------------

  operation :add_reaction,
    summary: "Add a reaction to a message",
    parameters: [
      id: [in: :path, type: :string, required: true],
      message_id: [in: :path, type: :string, required: true]
    ],
    request_body:
      {"Reaction", "application/json", ChannelsSchema.AddReactionRequest, required: true},
    responses: [
      created: {"Reaction", "application/json", ChannelsSchema.ReactionResponse},
      unprocessable_entity: {"Error", "application/json", ChannelsSchema.ErrorResponse}
    ]

  @spec add_reaction(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def add_reaction(conn, %{"message_id" => message_id} = params) do
    current_actor = actor_from_conn(conn)

    attrs = %{
      message_id: message_id,
      actor_type: params["actor_type"] || (current_actor && "user") || "user",
      actor_id: params["actor_id"] || (current_actor && current_actor.actor_id) || "",
      emoji: params["emoji"]
    }

    case Channels.add_reaction(attrs) do
      {:ok, reaction} -> conn |> put_status(:created) |> json(%{data: reaction})
      {:error, changeset} -> {:error, changeset}
    end
  end

  operation :remove_reaction,
    summary: "Remove a reaction from a message",
    parameters: [
      id: [in: :path, type: :string, required: true],
      message_id: [in: :path, type: :string, required: true],
      emoji: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Removed", "application/json", ChannelsSchema.ReactionResponse},
      not_found: {"Not found", "application/json", ChannelsSchema.ErrorResponse}
    ]

  @spec remove_reaction(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def remove_reaction(conn, %{"message_id" => message_id, "emoji" => emoji} = _params) do
    current_actor = actor_from_conn(conn)
    actor_type = (current_actor && "user") || "user"
    actor_id = (current_actor && current_actor.actor_id) || ""

    with {:ok, reaction} <- Channels.remove_reaction(message_id, actor_type, actor_id, emoji) do
      json(conn, %{data: reaction})
    end
  end

  # ---------------------------------------------------------------------------
  # Pins
  # ---------------------------------------------------------------------------

  operation :pin_message,
    summary: "Pin a message in a channel",
    parameters: [
      id: [in: :path, type: :string, required: true],
      message_id: [in: :path, type: :string, required: true]
    ],
    responses: [
      created: {"Pin", "application/json", ChannelsSchema.PinResponse},
      unprocessable_entity: {"Error", "application/json", ChannelsSchema.ErrorResponse}
    ]

  @spec pin_message(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def pin_message(conn, %{"id" => channel_id, "message_id" => message_id}) do
    user_id = get_user_id(conn)

    case Channels.pin_message(channel_id, message_id, user_id) do
      {:ok, pin} -> conn |> put_status(:created) |> json(%{data: pin})
      {:error, changeset} -> {:error, changeset}
    end
  end

  operation :unpin_message,
    summary: "Unpin a message from a channel",
    parameters: [
      id: [in: :path, type: :string, required: true],
      message_id: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Unpinned", "application/json", ChannelsSchema.PinResponse},
      not_found: {"Not found", "application/json", ChannelsSchema.ErrorResponse}
    ]

  @spec unpin_message(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def unpin_message(conn, %{"id" => channel_id, "message_id" => message_id}) do
    with {:ok, pin} <- Channels.unpin_message(channel_id, message_id) do
      json(conn, %{data: pin})
    end
  end

  # ---------------------------------------------------------------------------
  # Read receipts
  # ---------------------------------------------------------------------------

  operation :mark_read,
    summary: "Mark a channel as read up to now",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Member", "application/json", ChannelsSchema.MemberResponse},
      not_found: {"Not found", "application/json", ChannelsSchema.ErrorResponse}
    ]

  @spec mark_read(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def mark_read(conn, %{"id" => channel_id}) do
    actor = actor_from_conn(conn) || %{actor_type: "user", actor_id: ""}

    with {:ok, member} <- Channels.mark_read(channel_id, actor, DateTime.utc_now()) do
      json(conn, %{data: member})
    end
  end

  operation :unread_count,
    summary: "Get unread message count for current actor in a channel",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [ok: {"Count", "application/json", ChannelsSchema.UnreadCountResponse}]

  @spec unread_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def unread_count(conn, %{"id" => channel_id}) do
    actor = actor_from_conn(conn) || %{actor_type: "user", actor_id: ""}
    count = Channels.unread_count(channel_id, actor)
    json(conn, %{count: count})
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec actor_from_conn(Plug.Conn.t()) :: map() | nil
  defp actor_from_conn(conn) do
    case conn.assigns[:current_user] do
      nil -> nil
      user -> %{actor_type: "user", actor_id: user.id}
    end
  end

  @spec get_user_id(Plug.Conn.t()) :: String.t()
  defp get_user_id(conn) do
    case conn.assigns[:current_user] do
      nil -> ""
      user -> user.id
    end
  end

  @spec channel_attrs(map(), Plug.Conn.t()) :: map()
  defp channel_attrs(params, conn) do
    user_id = get_user_id(conn)

    %{
      slug: params["slug"],
      name: params["name"],
      description: params["description"],
      visibility: params["visibility"] || "public",
      workspace_slug: params["workspace_slug"],
      icon: params["icon"],
      color: params["color"],
      created_by_user_id: user_id
    }
  end

  @spec parse_datetime(String.t() | nil) :: DateTime.t() | nil
  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  @spec parse_int(String.t() | nil, integer()) :: integer()
  defp parse_int(nil, default), do: default

  defp parse_int(str, default) do
    case Integer.parse(str) do
      {n, _} when n > 0 -> n
      _ -> default
    end
  end
end
