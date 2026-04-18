defmodule CanopyWeb.Schemas.NotificationSchema do
  @moduledoc """
  OpenAPISpex schema definitions for the Notification resource.

  These are API contract schemas for `/api/v1/notifications`. Distinct from Ecto schemas.
  """

  alias OpenApiSpex.Schema

  defmodule Notification do
    @moduledoc "A persisted Canopy notification."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Notification",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        user_id: %Schema{
          type: :string,
          format: :uuid,
          nullable: true,
          description: "Recipient user ID; nil for agent-destined notifications"
        },
        agent_slug: %Schema{
          type: :string,
          nullable: true,
          description: "Recipient agent slug for agent inbox (future)"
        },
        type: %Schema{
          type: :string,
          description: "Notification type, e.g. task_assigned, mention_in_channel"
        },
        title: %Schema{type: :string, description: "Short human-readable title"},
        body: %Schema{type: :string, description: "Full notification body text"},
        icon: %Schema{type: :string, nullable: true, description: "Emoji icon"},
        link_path: %Schema{
          type: :string,
          nullable: true,
          description: "In-app path the user should navigate to"
        },
        payload: %Schema{
          type: :object,
          additionalProperties: true,
          description: "Type-specific data (JSONB)"
        },
        read_at: %Schema{
          type: :string,
          format: :"date-time",
          nullable: true,
          description: "When the notification was marked read; nil if unread"
        },
        delivered_channels: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "Channels that have delivered this notification"
        },
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :type, :title, :body]
    })
  end

  defmodule NotificationList do
    @moduledoc "A list of notifications."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "NotificationList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: Notification},
        unread_count: %Schema{type: :integer, description: "Total unread for this user"}
      },
      required: [:data, :unread_count]
    })
  end

  defmodule UnreadCountResponse do
    @moduledoc "Response for GET /notifications/unread_count."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "UnreadCountResponse",
      type: :object,
      properties: %{
        unread_count: %Schema{type: :integer}
      },
      required: [:unread_count]
    })
  end

  defmodule MarkAllReadResponse do
    @moduledoc "Response for POST /notifications/read_all."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "MarkAllReadResponse",
      type: :object,
      properties: %{
        marked_read: %Schema{type: :integer, description: "Number of notifications marked read"}
      },
      required: [:marked_read]
    })
  end
end
