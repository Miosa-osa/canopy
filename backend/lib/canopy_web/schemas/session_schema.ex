defmodule CanopyWeb.Schemas.SessionSchema do
  @moduledoc """
  OpenAPISpex schema definitions for the Session resource.

  These are API contract schemas for `/api/v1/sessions`. Distinct from Ecto schemas.
  """

  alias OpenApiSpex.Schema

  defmodule Session do
    @moduledoc "A Canopy agent execution session."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Session",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        kind: %Schema{
          type: :string,
          enum: ["terminal", "agent_conversation"],
          description: "Session discriminator"
        },
        runtime_type: %Schema{type: :string, description: "Runtime adapter type"},
        model_id: %Schema{type: :string, nullable: true},
        agent_slug: %Schema{type: :string, nullable: true},
        workspace_slug: %Schema{type: :string, nullable: true},
        status: %Schema{
          type: :string,
          enum: ["pending", "running", "completed", "cancelled", "failed"]
        },
        cwd: %Schema{type: :string, description: "Working directory at session start"},
        prompt: %Schema{type: :string, nullable: true},
        prompt_bundle_key: %Schema{
          type: :string,
          nullable: true,
          description: "SHA256 of skill bundle for triple-key resume"
        },
        wake_reason: %Schema{type: :string, nullable: true},
        parent_session_id: %Schema{type: :string, format: :uuid, nullable: true},
        sequence_number: %Schema{type: :integer},
        external_session_id: %Schema{type: :string, nullable: true},
        started_at: %Schema{type: :string, format: :"date-time", nullable: true},
        completed_at: %Schema{type: :string, format: :"date-time", nullable: true},
        cost_usd: %Schema{type: :string, description: "Cost in USD as decimal string"},
        input_tokens: %Schema{type: :integer},
        output_tokens: %Schema{type: :integer},
        cache_read_tokens: %Schema{type: :integer},
        cache_write_tokens: %Schema{type: :integer},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :kind, :runtime_type, :status, :cwd]
    })
  end

  defmodule SessionMessage do
    @moduledoc "A single transcript entry within a session."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SessionMessage",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        session_id: %Schema{type: :string, format: :uuid},
        sequence: %Schema{type: :integer},
        kind: %Schema{
          type: :string,
          enum: [
            "assistant",
            "thinking",
            "tool_call",
            "tool_result",
            "diff",
            "stderr",
            "stdout",
            "system",
            "user"
          ]
        },
        content: %Schema{type: :object, description: "Discriminated payload per kind"},
        tool_call_id: %Schema{type: :string, nullable: true},
        emitted_at: %Schema{type: :string, format: :"date-time"},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :session_id, :sequence, :kind, :content, :emitted_at]
    })
  end

  defmodule CreateSessionRequest do
    @moduledoc "Request body for POST /api/v1/sessions."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "CreateSessionRequest",
      type: :object,
      properties: %{
        runtime_type: %Schema{type: :string},
        kind: %Schema{
          type: :string,
          enum: ["terminal", "agent_conversation"],
          nullable: true
        },
        cwd: %Schema{type: :string},
        model_id: %Schema{type: :string, nullable: true},
        agent_slug: %Schema{type: :string, nullable: true},
        workspace_slug: %Schema{type: :string, nullable: true},
        prompt: %Schema{type: :string, nullable: true},
        parent_session_id: %Schema{type: :string, format: :uuid, nullable: true}
      },
      required: [:runtime_type, :cwd]
    })
  end

  defmodule SessionList do
    @moduledoc "A paginated list of sessions."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SessionList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: Session}
      },
      required: [:data]
    })
  end

  defmodule SessionDetail do
    @moduledoc "A session with its most recent messages."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SessionDetail",
      type: :object,
      properties: %{
        session: Session,
        messages: %Schema{type: :array, items: SessionMessage}
      },
      required: [:session, :messages]
    })
  end

  defmodule CreateSessionResponse do
    @moduledoc "Response body for POST /api/v1/sessions."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "CreateSessionResponse",
      type: :object,
      properties: %{
        session_id: %Schema{type: :string, format: :uuid},
        sse_url: %Schema{type: :string, description: "SSE stream URL for this session"}
      },
      required: [:session_id, :sse_url]
    })
  end

  defmodule MessageList do
    @moduledoc "A paginated list of session messages."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "MessageList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: SessionMessage}
      },
      required: [:data]
    })
  end

  defmodule SessionChain do
    @moduledoc "A session chain with ancestors and children."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SessionChain",
      type: :object,
      properties: %{
        session: Session,
        ancestors: %Schema{type: :array, items: Session},
        children: %Schema{type: :array, items: Session}
      },
      required: [:session, :ancestors, :children]
    })
  end

  defmodule SendMessageRequest do
    @moduledoc "Request body for POST /api/v1/sessions/:id/messages."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SendMessageRequest",
      type: :object,
      properties: %{
        content: %Schema{type: :string, description: "Text to write to PTY stdin"},
        message: %Schema{type: :string, description: "Alias for content"}
      }
    })
  end

  defmodule SendMessageResponse do
    @moduledoc "Response for POST /api/v1/sessions/:id/messages."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SendMessageResponse",
      type: :object,
      properties: %{
        status: %Schema{type: :string, enum: ["sent"]},
        session_id: %Schema{type: :string, format: :uuid}
      },
      required: [:status, :session_id]
    })
  end

  defmodule InjectMessageRequest do
    @moduledoc "Request body for POST /api/v1/sessions/:id/inject."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "InjectMessageRequest",
      type: :object,
      properties: %{
        content: %Schema{type: :string, description: "Text to write to PTY stdin"},
        from_agent: %Schema{type: :string, description: "Slug of the agent sending the injection"}
      },
      required: [:content, :from_agent]
    })
  end

  defmodule InjectMessageResponse do
    @moduledoc "Response for POST /api/v1/sessions/:id/inject."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "InjectMessageResponse",
      type: :object,
      properties: %{
        status: %Schema{type: :string, enum: ["injected"]},
        session_id: %Schema{type: :string, format: :uuid},
        from_agent: %Schema{type: :string}
      },
      required: [:status, :session_id, :from_agent]
    })
  end
end
