defmodule CanopyWeb.Schemas.ProjectsSchema do
  @moduledoc "OpenAPI schemas for the Projects API."

  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule ProjectDetail do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ProjectDetail",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        slug: %Schema{type: :string, example: "canopy-launch"},
        name: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        workspace_slug: %Schema{type: :string},
        status: %Schema{
          type: :string,
          enum: ["active", "paused", "archived"]
        },
        color: %Schema{type: :string, example: "#7bd88f", nullable: true},
        icon: %Schema{type: :string, example: "FolderKanban", nullable: true},
        owner_type: %Schema{type: :string, enum: ["agent", "human"], nullable: true},
        owner_id: %Schema{type: :string, nullable: true},
        target_date: %Schema{type: :string, format: :"date-time", nullable: true},
        archived_at: %Schema{type: :string, format: :"date-time", nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule ProjectList do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ProjectList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: ProjectDetail},
        count: %Schema{type: :integer}
      }
    })
  end

  defmodule ProjectSummary do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ProjectSummary",
      type: :object,
      properties: %{
        data: %Schema{
          type: :object,
          properties: %{
            project: ProjectDetail,
            issues_count: %Schema{type: :integer},
            tasks_count: %Schema{type: :integer},
            goals_count: %Schema{type: :integer},
            sessions_count: %Schema{type: :integer}
          }
        }
      }
    })
  end

  defmodule CreateProjectRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "CreateProjectRequest",
      type: :object,
      required: ["name", "workspace_slug"],
      properties: %{
        name: %Schema{type: :string},
        slug: %Schema{type: :string},
        description: %Schema{type: :string},
        workspace_slug: %Schema{type: :string},
        status: %Schema{type: :string, enum: ["active", "paused", "archived"]},
        color: %Schema{type: :string},
        icon: %Schema{type: :string},
        owner_type: %Schema{type: :string, enum: ["agent", "human"]},
        owner_id: %Schema{type: :string},
        target_date: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule UpdateProjectRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "UpdateProjectRequest",
      type: :object,
      properties: %{
        name: %Schema{type: :string},
        description: %Schema{type: :string},
        status: %Schema{type: :string, enum: ["active", "paused", "archived"]},
        color: %Schema{type: :string},
        icon: %Schema{type: :string},
        owner_type: %Schema{type: :string, enum: ["agent", "human"]},
        owner_id: %Schema{type: :string},
        target_date: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule ErrorResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ProjectErrorResponse",
      type: :object,
      properties: %{
        error: %Schema{type: :string},
        message: %Schema{type: :string}
      }
    })
  end
end
