defmodule CanopyWeb.Schemas.AgentKanbanSchema do
  @moduledoc "OpenAPI schemas for the Agent Kanban API."

  require OpenApiSpex
  alias CanopyWeb.Schemas.TasksSchema
  alias OpenApiSpex.Schema

  defmodule BoardColumn do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "AgentKanbanBoardColumn",
      type: :array,
      items: TasksSchema.TaskDetail
    })
  end

  defmodule Board do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "AgentKanbanBoard",
      type: :object,
      properties: %{
        backlog: BoardColumn,
        claimed: BoardColumn,
        in_progress: BoardColumn,
        done: BoardColumn
      }
    })
  end

  defmodule BoardResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "AgentKanbanBoardResponse",
      type: :object,
      properties: %{data: Board}
    })
  end

  defmodule ClaimRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "AgentKanbanClaimRequest",
      type: :object,
      required: ["agent_slug", "task_id"],
      properties: %{
        agent_slug: %Schema{type: :string, description: "Slug of the claiming agent"},
        task_id: %Schema{type: :string, description: "Task short_id to claim"}
      }
    })
  end

  defmodule TaskResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "AgentKanbanTaskResponse",
      type: :object,
      properties: %{data: TasksSchema.TaskDetail}
    })
  end

  defmodule IdleAgent do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "AgentKanbanIdleAgent",
      type: :object,
      properties: %{
        slug: %Schema{type: :string},
        name: %Schema{type: :string},
        category: %Schema{type: :string},
        capabilities: %Schema{type: :array, items: %Schema{type: :string}},
        active_session_count: %Schema{type: :integer},
        auto_pickup_enabled: %Schema{type: :boolean}
      }
    })
  end

  defmodule IdleAgentsResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "AgentKanbanIdleAgentsResponse",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: IdleAgent},
        count: %Schema{type: :integer}
      }
    })
  end

  defmodule CompleteRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "AgentKanbanCompleteRequest",
      type: :object,
      properties: %{
        session_id: %Schema{
          type: :string,
          format: :uuid,
          nullable: true,
          description: "Session that produced the work — recorded for traceability"
        }
      }
    })
  end

  defmodule ErrorResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "AgentKanbanErrorResponse",
      type: :object,
      properties: %{
        error: %Schema{type: :string},
        message: %Schema{type: :string}
      }
    })
  end
end
