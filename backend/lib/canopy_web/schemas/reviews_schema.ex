defmodule CanopyWeb.Schemas.ReviewsSchema do
  @moduledoc "OpenAPI schemas for the Reviews (human approval queue) API."

  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule ReviewDetail do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ReviewDetail",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        workspace_slug: %Schema{type: :string, nullable: true},
        kind: %Schema{type: :string, enum: ["artifact", "tool_call", "hire_agent"]},
        artifact_type: %Schema{type: :string, nullable: true},
        artifact_id: %Schema{type: :string, nullable: true},
        artifact_preview: %Schema{type: :string, nullable: true},
        tool_name: %Schema{type: :string, nullable: true},
        tool_args: %Schema{type: :object, nullable: true, additionalProperties: true},
        session_id: %Schema{type: :string, format: :uuid, nullable: true},
        agent_id: %Schema{type: :string, nullable: true},
        reviewer_id: %Schema{type: :string, nullable: true},
        status: %Schema{
          type: :string,
          enum: ["pending", "approved", "rejected", "changes_requested", "expired"]
        },
        feedback: %Schema{type: :string, nullable: true},
        requested_at: %Schema{type: :string, format: :"date-time"},
        decided_at: %Schema{type: :string, format: :"date-time", nullable: true},
        expires_at: %Schema{type: :string, format: :"date-time", nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule ReviewList do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ReviewList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: ReviewDetail},
        count: %Schema{type: :integer}
      }
    })
  end

  defmodule ReviewSummary do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ReviewSummary",
      type: :object,
      properties: %{
        total: %Schema{type: :integer},
        pending_count: %Schema{type: :integer},
        decided_count: %Schema{type: :integer},
        changes_requested_count: %Schema{type: :integer},
        by_status: %Schema{type: :object, additionalProperties: %Schema{type: :integer}},
        by_kind: %Schema{type: :object, additionalProperties: %Schema{type: :integer}},
        by_workspace: %Schema{type: :object, additionalProperties: %Schema{type: :integer}},
        by_agent: %Schema{type: :object, additionalProperties: %Schema{type: :integer}},
        oldest_pending_at: %Schema{type: :string, format: :"date-time", nullable: true},
        next_expiry_at: %Schema{type: :string, format: :"date-time", nullable: true},
        recent: %Schema{type: :array, items: ReviewDetail}
      }
    })
  end

  defmodule CreateArtifactReviewRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "CreateArtifactReviewRequest",
      type: :object,
      required: ["kind"],
      properties: %{
        kind: %Schema{type: :string, enum: ["artifact", "tool_call", "hire_agent"]},
        workspace_slug: %Schema{type: :string},
        artifact_type: %Schema{
          type: :string,
          enum: ["doc", "task", "issue", "pr", "file", "kb_chunk"]
        },
        artifact_id: %Schema{type: :string},
        artifact_preview: %Schema{type: :string},
        tool_name: %Schema{type: :string},
        tool_args: %Schema{type: :object, additionalProperties: true},
        session_id: %Schema{type: :string, format: :uuid},
        agent_id: %Schema{type: :string}
      }
    })
  end

  defmodule ApproveRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ApproveRequest",
      type: :object,
      properties: %{
        reviewer_id: %Schema{type: :string}
      }
    })
  end

  defmodule RejectRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "RejectRequest",
      type: :object,
      properties: %{
        reviewer_id: %Schema{type: :string},
        feedback: %Schema{type: :string}
      }
    })
  end

  defmodule RequestChangesRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "RequestChangesRequest",
      type: :object,
      properties: %{
        reviewer_id: %Schema{type: :string},
        feedback: %Schema{type: :string}
      }
    })
  end

  defmodule ErrorResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ReviewErrorResponse",
      type: :object,
      properties: %{
        error: %Schema{type: :string},
        message: %Schema{type: :string}
      }
    })
  end
end
