defmodule CanopyWeb.Schemas.WorkspaceSchema do
  @moduledoc """
  OpenAPISpex schema definitions for the Workspace resource.

  These are API contract schemas for `/api/v1/workspaces`. Distinct from Ecto schemas.
  """

  alias OpenApiSpex.Schema

  defmodule Workspace do
    @moduledoc "A Canopy workspace mapping to a filesystem directory."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Workspace",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        slug: %Schema{type: :string, description: "Stable URL-safe identifier"},
        name: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        root_path: %Schema{
          type: :string,
          description: "Absolute filesystem path for the workspace root"
        },
        template: %Schema{
          type: :string,
          nullable: true,
          description: "Workspace template name, e.g. sales-engine"
        },
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :slug, :name, :root_path]
    })
  end

  defmodule CreateWorkspaceRequest do
    @moduledoc "Request body for POST /api/v1/workspaces."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "CreateWorkspaceRequest",
      type: :object,
      properties: %{
        slug: %Schema{type: :string},
        name: %Schema{type: :string},
        root_path: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        template: %Schema{type: :string, nullable: true}
      },
      required: [:slug, :name, :root_path]
    })
  end
end
