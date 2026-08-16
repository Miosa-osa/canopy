defmodule CanopyWeb.Schemas.GoalsSchema do
  @moduledoc "OpenAPI schemas for the Goals API."

  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule GoalDetail do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "GoalDetail",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        short_id: %Schema{type: :string, example: "G-00003721"},
        title: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        status: %Schema{
          type: :string,
          enum: ["proposed", "active", "blocked", "achieved", "cancelled"]
        },
        priority: %Schema{type: :integer, minimum: 0, maximum: 4},
        owner_type: %Schema{type: :string, nullable: true},
        owner_id: %Schema{type: :string, nullable: true},
        workspace_slug: %Schema{type: :string},
        target_date: %Schema{type: :string, format: :"date-time", nullable: true},
        achieved_at: %Schema{type: :string, format: :"date-time", nullable: true},
        progress_pct: %Schema{type: :integer, minimum: 0, maximum: 100},
        success_criteria: %Schema{type: :string, nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule GoalList do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "GoalList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: GoalDetail},
        count: %Schema{type: :integer}
      }
    })
  end

  defmodule CreateGoalRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "CreateGoalRequest",
      type: :object,
      required: ["title", "workspace_slug"],
      properties: %{
        title: %Schema{type: :string},
        description: %Schema{type: :string},
        status: %Schema{
          type: :string,
          enum: ["proposed", "active", "blocked", "achieved", "cancelled"]
        },
        priority: %Schema{type: :integer, minimum: 0, maximum: 4},
        owner_type: %Schema{type: :string},
        owner_id: %Schema{type: :string},
        workspace_slug: %Schema{type: :string},
        target_date: %Schema{type: :string, format: :"date-time"},
        progress_pct: %Schema{type: :integer, minimum: 0, maximum: 100},
        success_criteria: %Schema{type: :string}
      }
    })
  end

  defmodule UpdateGoalRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "UpdateGoalRequest",
      type: :object,
      properties: %{
        title: %Schema{type: :string},
        description: %Schema{type: :string},
        status: %Schema{
          type: :string,
          enum: ["proposed", "active", "blocked", "achieved", "cancelled"]
        },
        priority: %Schema{type: :integer, minimum: 0, maximum: 4},
        owner_type: %Schema{type: :string},
        owner_id: %Schema{type: :string},
        target_date: %Schema{type: :string, format: :"date-time"},
        progress_pct: %Schema{type: :integer, minimum: 0, maximum: 100},
        success_criteria: %Schema{type: :string}
      }
    })
  end

  defmodule SetProgressRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "SetProgressRequest",
      type: :object,
      required: ["progress_pct"],
      properties: %{
        progress_pct: %Schema{type: :integer, minimum: 0, maximum: 100}
      }
    })
  end

  defmodule ErrorResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "GoalErrorResponse",
      type: :object,
      properties: %{
        error: %Schema{type: :string},
        message: %Schema{type: :string}
      }
    })
  end
end
