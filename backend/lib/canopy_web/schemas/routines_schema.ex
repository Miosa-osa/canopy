defmodule CanopyWeb.Schemas.RoutinesSchema do
  @moduledoc "OpenAPI schemas for the Routines API."

  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule RoutineDetail do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "RoutineDetail",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        short_id: %Schema{type: :string, example: "R-00003721"},
        name: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        cron: %Schema{type: :string, example: "0 9 * * 1"},
        prompt_template: %Schema{type: :string},
        creates: %Schema{type: :string, enum: ["issue", "task", "goal"]},
        target_agent_id: %Schema{type: :string, nullable: true},
        target_runtime_type: %Schema{type: :string, nullable: true},
        workspace_slug: %Schema{type: :string},
        enabled: %Schema{type: :boolean},
        last_run_at: %Schema{type: :string, format: :"date-time", nullable: true},
        next_run_at: %Schema{type: :string, format: :"date-time", nullable: true},
        run_count: %Schema{type: :integer},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule RoutineList do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "RoutineList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: RoutineDetail},
        count: %Schema{type: :integer}
      }
    })
  end

  defmodule CreateRoutineRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "CreateRoutineRequest",
      type: :object,
      required: ["name", "cron", "prompt_template", "workspace_slug"],
      properties: %{
        name: %Schema{type: :string},
        description: %Schema{type: :string},
        cron: %Schema{type: :string},
        prompt_template: %Schema{type: :string},
        creates: %Schema{type: :string, enum: ["issue", "task", "goal"]},
        target_agent_id: %Schema{type: :string},
        target_runtime_type: %Schema{type: :string},
        workspace_slug: %Schema{type: :string},
        enabled: %Schema{type: :boolean}
      }
    })
  end

  defmodule UpdateRoutineRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "UpdateRoutineRequest",
      type: :object,
      properties: %{
        name: %Schema{type: :string},
        description: %Schema{type: :string},
        cron: %Schema{type: :string},
        prompt_template: %Schema{type: :string},
        creates: %Schema{type: :string, enum: ["issue", "task", "goal"]},
        target_agent_id: %Schema{type: :string},
        target_runtime_type: %Schema{type: :string},
        enabled: %Schema{type: :boolean}
      }
    })
  end

  defmodule FireResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "RoutineFireResponse",
      type: :object,
      properties: %{
        data: %Schema{
          type: :object,
          properties: %{
            routine: RoutineDetail,
            created: %Schema{type: :object, description: "The created issue, task, or goal"}
          }
        }
      }
    })
  end

  defmodule ErrorResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "RoutineErrorResponse",
      type: :object,
      properties: %{
        error: %Schema{type: :string},
        message: %Schema{type: :string}
      }
    })
  end
end
