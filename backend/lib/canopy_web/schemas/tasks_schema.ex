defmodule CanopyWeb.Schemas.TasksSchema do
  @moduledoc "OpenAPI schemas for the Tasks API."

  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule TaskDetail do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "TaskDetail",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        short_id: %Schema{type: :string, example: "T-00003721"},
        parent_id: %Schema{type: :string, format: :uuid, nullable: true},
        project_slug: %Schema{type: :string, nullable: true},
        title: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        status: %Schema{type: :string, enum: ["todo", "in_progress", "done", "cancelled"]},
        priority: %Schema{type: :integer, minimum: 0, maximum: 4},
        assignee_type: %Schema{type: :string, nullable: true},
        assignee_id: %Schema{type: :string, nullable: true},
        workspace_slug: %Schema{type: :string, nullable: true},
        due_at: %Schema{type: :string, format: :"date-time", nullable: true},
        completed_at: %Schema{type: :string, format: :"date-time", nullable: true},
        labels: %Schema{type: :array, items: %Schema{type: :string}},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule TaskList do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "TaskList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: TaskDetail},
        count: %Schema{type: :integer}
      }
    })
  end

  defmodule CreateTaskRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "CreateTaskRequest",
      type: :object,
      required: ["title"],
      properties: %{
        title: %Schema{type: :string},
        description: %Schema{type: :string},
        status: %Schema{type: :string, enum: ["todo", "in_progress", "done", "cancelled"]},
        priority: %Schema{type: :integer, minimum: 0, maximum: 4},
        project_slug: %Schema{type: :string},
        parent_id: %Schema{type: :string, format: :uuid},
        assignee_type: %Schema{type: :string},
        assignee_id: %Schema{type: :string},
        workspace_slug: %Schema{type: :string},
        due_at: %Schema{type: :string, format: :"date-time"},
        labels: %Schema{type: :array, items: %Schema{type: :string}}
      }
    })
  end

  defmodule UpdateTaskRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "UpdateTaskRequest",
      type: :object,
      properties: %{
        title: %Schema{type: :string},
        description: %Schema{type: :string},
        status: %Schema{type: :string, enum: ["todo", "in_progress", "done", "cancelled"]},
        priority: %Schema{type: :integer, minimum: 0, maximum: 4},
        project_slug: %Schema{type: :string},
        assignee_type: %Schema{type: :string},
        assignee_id: %Schema{type: :string},
        due_at: %Schema{type: :string, format: :"date-time"},
        labels: %Schema{type: :array, items: %Schema{type: :string}}
      }
    })
  end

  defmodule ErrorResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "TaskErrorResponse",
      type: :object,
      properties: %{
        error: %Schema{type: :string},
        message: %Schema{type: :string}
      }
    })
  end
end
