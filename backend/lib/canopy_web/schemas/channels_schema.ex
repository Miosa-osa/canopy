defmodule CanopyWeb.Schemas.ChannelsSchema do
  @moduledoc """
  OpenAPISpex schema definitions for the Channels resource.

  Covers channels, members, messages, reactions, and pins.
  """

  alias OpenApiSpex.Schema

  # ---------------------------------------------------------------------------
  # Shared
  # ---------------------------------------------------------------------------

  defmodule ErrorResponse do
    @moduledoc "Generic error response."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ChannelErrorResponse",
      type: :object,
      properties: %{
        error: %Schema{type: :string},
        message: %Schema{type: :string}
      }
    })
  end

  # ---------------------------------------------------------------------------
  # Channel
  # ---------------------------------------------------------------------------

  defmodule Channel do
    @moduledoc "A Canopy channel."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Channel",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        slug: %Schema{type: :string},
        name: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        visibility: %Schema{type: :string, enum: ["public", "private"]},
        workspace_slug: %Schema{type: :string, nullable: true},
        icon: %Schema{type: :string, nullable: true},
        color: %Schema{type: :string, nullable: true},
        created_by_user_id: %Schema{type: :string, format: :uuid, nullable: true},
        archived_at: %Schema{type: :string, format: :"date-time", nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :slug, :name, :visibility]
    })
  end

  defmodule ChannelList do
    @moduledoc "A list of channels."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ChannelList",
      type: :object,
      properties: %{data: %Schema{type: :array, items: Channel}},
      required: [:data]
    })
  end

  defmodule ChannelResponse do
    @moduledoc "Single channel response."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ChannelResponse",
      type: :object,
      properties: %{data: Channel},
      required: [:data]
    })
  end

  defmodule CreateChannelRequest do
    @moduledoc "Request body for creating a channel."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "CreateChannelRequest",
      type: :object,
      properties: %{
        slug: %Schema{type: :string},
        name: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        visibility: %Schema{type: :string, enum: ["public", "private"]},
        workspace_slug: %Schema{type: :string, nullable: true},
        icon: %Schema{type: :string, nullable: true},
        color: %Schema{type: :string, nullable: true}
      },
      required: [:slug, :name]
    })
  end

  defmodule UpdateChannelRequest do
    @moduledoc "Request body for updating a channel."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "UpdateChannelRequest",
      type: :object,
      properties: %{
        name: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        visibility: %Schema{type: :string, enum: ["public", "private"]},
        icon: %Schema{type: :string, nullable: true},
        color: %Schema{type: :string, nullable: true}
      }
    })
  end

  # ---------------------------------------------------------------------------
  # Member
  # ---------------------------------------------------------------------------

  defmodule Member do
    @moduledoc "A channel member (user or agent)."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ChannelMember",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        channel_id: %Schema{type: :string, format: :uuid},
        actor_type: %Schema{type: :string, enum: ["user", "agent"]},
        actor_id: %Schema{type: :string},
        role: %Schema{type: :string, enum: ["member", "admin"]},
        notifications_enabled: %Schema{type: :boolean},
        last_read_at: %Schema{type: :string, format: :"date-time", nullable: true},
        joined_at: %Schema{type: :string, format: :"date-time"},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :channel_id, :actor_type, :actor_id, :role]
    })
  end

  defmodule MemberResponse do
    @moduledoc "Single member response."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ChannelMemberResponse",
      type: :object,
      properties: %{data: Member},
      required: [:data]
    })
  end

  defmodule AddMemberRequest do
    @moduledoc "Request body for adding a member."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AddMemberRequest",
      type: :object,
      properties: %{
        actor_type: %Schema{type: :string, enum: ["user", "agent"]},
        actor_id: %Schema{type: :string},
        role: %Schema{type: :string, enum: ["member", "admin"]}
      },
      required: [:actor_type, :actor_id]
    })
  end

  # ---------------------------------------------------------------------------
  # Message
  # ---------------------------------------------------------------------------

  defmodule Message do
    @moduledoc "A channel message."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ChannelMessage",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        channel_id: %Schema{type: :string, format: :uuid},
        author_type: %Schema{type: :string, enum: ["user", "agent", "system"]},
        author_id: %Schema{type: :string, nullable: true},
        body_markdown: %Schema{type: :string},
        body_rendered_html: %Schema{type: :string, nullable: true},
        reply_to_id: %Schema{type: :string, format: :uuid, nullable: true},
        thread_count: %Schema{type: :integer},
        edited_at: %Schema{type: :string, format: :"date-time", nullable: true},
        deleted_at: %Schema{type: :string, format: :"date-time", nullable: true},
        mentions: %Schema{type: :array, items: %Schema{type: :string}},
        attachments: %Schema{type: :object},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :channel_id, :author_type, :body_markdown]
    })
  end

  defmodule MessageList do
    @moduledoc "Paginated message list."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ChannelMessageList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: Message},
        has_more: %Schema{type: :boolean}
      },
      required: [:data, :has_more]
    })
  end

  defmodule MessageResponse do
    @moduledoc "Single message response."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ChannelMessageResponse",
      type: :object,
      properties: %{data: Message},
      required: [:data]
    })
  end

  defmodule CreateMessageRequest do
    @moduledoc "Request body for posting a message."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "CreateMessageRequest",
      type: :object,
      properties: %{
        body_markdown: %Schema{type: :string},
        author_type: %Schema{type: :string, enum: ["user", "agent", "system"]},
        author_id: %Schema{type: :string, nullable: true},
        reply_to_id: %Schema{type: :string, format: :uuid, nullable: true},
        attachments: %Schema{type: :object, nullable: true}
      },
      required: [:body_markdown]
    })
  end

  defmodule EditMessageRequest do
    @moduledoc "Request body for editing a message."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "EditMessageRequest",
      type: :object,
      properties: %{
        body_markdown: %Schema{type: :string},
        body_rendered_html: %Schema{type: :string, nullable: true}
      },
      required: [:body_markdown]
    })
  end

  # ---------------------------------------------------------------------------
  # Reaction
  # ---------------------------------------------------------------------------

  defmodule Reaction do
    @moduledoc "A message reaction."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ChannelReaction",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        message_id: %Schema{type: :string, format: :uuid},
        actor_type: %Schema{type: :string, enum: ["user", "agent"]},
        actor_id: %Schema{type: :string},
        emoji: %Schema{type: :string},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :message_id, :actor_type, :actor_id, :emoji]
    })
  end

  defmodule ReactionResponse do
    @moduledoc "Single reaction response."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ChannelReactionResponse",
      type: :object,
      properties: %{data: Reaction},
      required: [:data]
    })
  end

  defmodule AddReactionRequest do
    @moduledoc "Request body for adding a reaction."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AddReactionRequest",
      type: :object,
      properties: %{
        emoji: %Schema{type: :string},
        actor_type: %Schema{type: :string, enum: ["user", "agent"]},
        actor_id: %Schema{type: :string}
      },
      required: [:emoji]
    })
  end

  # ---------------------------------------------------------------------------
  # Pin
  # ---------------------------------------------------------------------------

  defmodule Pin do
    @moduledoc "A pinned message."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ChannelPin",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        channel_id: %Schema{type: :string, format: :uuid},
        message_id: %Schema{type: :string, format: :uuid},
        pinned_by_user_id: %Schema{type: :string, format: :uuid},
        pinned_at: %Schema{type: :string, format: :"date-time"},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :channel_id, :message_id, :pinned_by_user_id, :pinned_at]
    })
  end

  defmodule PinResponse do
    @moduledoc "Single pin response."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ChannelPinResponse",
      type: :object,
      properties: %{data: Pin},
      required: [:data]
    })
  end

  # ---------------------------------------------------------------------------
  # Unread count
  # ---------------------------------------------------------------------------

  defmodule UnreadCountResponse do
    @moduledoc "Unread message count for an actor in a channel."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "UnreadCountResponse",
      type: :object,
      properties: %{
        count: %Schema{type: :integer, minimum: 0}
      },
      required: [:count]
    })
  end
end
