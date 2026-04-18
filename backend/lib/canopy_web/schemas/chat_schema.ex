defmodule CanopyWeb.Schemas.ChatSchema do
  @moduledoc """
  OpenAPISpex schema definitions for the Chat resource.

  These are API contract schemas for `/api/v1/chat/threads`.
  Distinct from the Ecto schemas in `Canopy.Chat`.
  """

  alias OpenApiSpex.Schema

  defmodule Thread do
    @moduledoc "A chat thread."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Thread",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        title: %Schema{type: :string, nullable: true, description: "User-editable display name"},
        user_id: %Schema{type: :string, format: :uuid, nullable: true},
        agent_slug: %Schema{type: :string, nullable: true},
        runtime_type: %Schema{type: :string},
        model_id: %Schema{type: :string, nullable: true},
        workspace_slug: %Schema{type: :string, nullable: true},
        last_session_id: %Schema{type: :string, format: :uuid, nullable: true},
        last_message_at: %Schema{type: :string, format: :"date-time", nullable: true},
        pinned: %Schema{type: :boolean},
        archived_at: %Schema{type: :string, format: :"date-time", nullable: true},
        metadata: %Schema{type: :object, nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :runtime_type, :pinned]
    })
  end

  defmodule ThreadList do
    @moduledoc "A list of threads."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ThreadList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: Thread}
      },
      required: [:data]
    })
  end

  defmodule ThreadDetail do
    @moduledoc "A thread with its full concatenated transcript."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ThreadDetail",
      type: :object,
      properties: %{
        thread: Thread,
        messages: %Schema{type: :array, items: CanopyWeb.Schemas.SessionSchema.SessionMessage}
      },
      required: [:thread, :messages]
    })
  end

  defmodule CreateThreadRequest do
    @moduledoc "Request body for POST /api/v1/chat/threads."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "CreateThreadRequest",
      type: :object,
      properties: %{
        title: %Schema{type: :string, nullable: true},
        agent_slug: %Schema{type: :string, nullable: true},
        runtime_type: %Schema{type: :string},
        model_id: %Schema{type: :string, nullable: true},
        workspace_slug: %Schema{type: :string, nullable: true},
        prompt: %Schema{type: :string, nullable: true}
      },
      required: [:runtime_type]
    })
  end

  defmodule CreateThreadResponse do
    @moduledoc "Response body for POST /api/v1/chat/threads."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "CreateThreadResponse",
      type: :object,
      properties: %{
        thread: Thread,
        session_id: %Schema{type: :string, format: :uuid},
        sse_url: %Schema{type: :string, description: "SSE stream URL for the initial session"}
      },
      required: [:thread, :session_id, :sse_url]
    })
  end

  defmodule ContinueThreadRequest do
    @moduledoc "Request body for POST /api/v1/chat/threads/:id/continue."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ContinueThreadRequest",
      type: :object,
      properties: %{
        prompt: %Schema{type: :string, description: "The next user message"}
      },
      required: [:prompt]
    })
  end

  defmodule ContinueThreadResponse do
    @moduledoc "Response body for POST /api/v1/chat/threads/:id/continue."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ContinueThreadResponse",
      type: :object,
      properties: %{
        session_id: %Schema{type: :string, format: :uuid},
        sse_url: %Schema{type: :string, description: "SSE stream URL for this session turn"}
      },
      required: [:session_id, :sse_url]
    })
  end

  defmodule UpdateThreadRequest do
    @moduledoc "Request body for PATCH /api/v1/chat/threads/:id."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "UpdateThreadRequest",
      type: :object,
      properties: %{
        title: %Schema{type: :string, nullable: true, description: "Rename the thread"},
        pinned: %Schema{type: :boolean, nullable: true, description: "Pin or unpin"},
        archived: %Schema{
          type: :boolean,
          nullable: true,
          description: "true = archive, false = unarchive"
        }
      }
    })
  end
end
