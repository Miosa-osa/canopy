defmodule CanopyWeb.Schemas.IssuesSchema do
  @moduledoc "OpenAPI schemas for the Issues API."

  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule IssueDetail do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IssueDetail",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        short_id: %Schema{type: :string, example: "I-00003721"},
        title: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        status: %Schema{
          type: :string,
          enum: ["backlog", "open", "in_progress", "in_review", "closed"]
        },
        priority: %Schema{type: :integer, minimum: 0, maximum: 4},
        assignee_type: %Schema{type: :string, nullable: true},
        assignee_id: %Schema{type: :string, nullable: true},
        workspace_slug: %Schema{type: :string},
        project_slug: %Schema{type: :string, nullable: true},
        parent_id: %Schema{type: :string, format: :uuid, nullable: true},
        session_id: %Schema{type: :string, format: :uuid, nullable: true},
        dispatched_at: %Schema{type: :string, format: :"date-time", nullable: true},
        completed_at: %Schema{type: :string, format: :"date-time", nullable: true},
        branch: %Schema{type: :string, nullable: true},
        pr_url: %Schema{type: :string, nullable: true},
        labels: %Schema{type: :array, items: %Schema{type: :string}},
        estimate_minutes: %Schema{type: :integer, nullable: true},
        due_at: %Schema{type: :string, format: :"date-time", nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule IssueList do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IssueList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: IssueDetail},
        count: %Schema{type: :integer}
      }
    })
  end

  defmodule CreateIssueRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "CreateIssueRequest",
      type: :object,
      required: ["title", "workspace_slug"],
      properties: %{
        title: %Schema{type: :string},
        description: %Schema{type: :string},
        status: %Schema{
          type: :string,
          enum: ["backlog", "open", "in_progress", "in_review", "closed"]
        },
        priority: %Schema{type: :integer, minimum: 0, maximum: 4},
        assignee_type: %Schema{type: :string},
        assignee_id: %Schema{type: :string},
        workspace_slug: %Schema{type: :string},
        project_slug: %Schema{type: :string},
        parent_id: %Schema{type: :string, format: :uuid},
        branch: %Schema{type: :string},
        pr_url: %Schema{type: :string},
        labels: %Schema{type: :array, items: %Schema{type: :string}},
        estimate_minutes: %Schema{type: :integer},
        due_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule UpdateIssueRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "UpdateIssueRequest",
      type: :object,
      properties: %{
        title: %Schema{type: :string},
        description: %Schema{type: :string},
        status: %Schema{
          type: :string,
          enum: ["backlog", "open", "in_progress", "in_review", "closed"]
        },
        priority: %Schema{type: :integer, minimum: 0, maximum: 4},
        assignee_type: %Schema{type: :string},
        assignee_id: %Schema{type: :string},
        project_slug: %Schema{type: :string},
        branch: %Schema{type: :string},
        pr_url: %Schema{type: :string},
        labels: %Schema{type: :array, items: %Schema{type: :string}},
        estimate_minutes: %Schema{type: :integer},
        due_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule AssignIssueRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "AssignIssueRequest",
      type: :object,
      required: ["assignee_type", "assignee_id"],
      properties: %{
        assignee_type: %Schema{type: :string, enum: ["agent", "human"]},
        assignee_id: %Schema{type: :string}
      }
    })
  end

  defmodule IssueDispatchRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IssueDispatchRequest",
      type: :object,
      properties: %{
        agent_slug: %Schema{type: :string, nullable: true},
        runtime_type: %Schema{type: :string, nullable: true}
      }
    })
  end

  defmodule IssueDispatchResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IssueDispatchResponse",
      type: :object,
      properties: %{
        data: %Schema{
          type: :object,
          properties: %{
            session_id: %Schema{type: :string, format: :uuid},
            issue: IssueDetail
          }
        }
      }
    })
  end

  defmodule ErrorResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IssueErrorResponse",
      type: :object,
      properties: %{
        error: %Schema{type: :string},
        message: %Schema{type: :string}
      }
    })
  end
end
