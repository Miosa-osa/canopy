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
        deleted_at: %Schema{type: :string, format: :"date-time", nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :slug, :name, :root_path]
    })
  end

  defmodule WorkspaceDetail do
    @moduledoc "Single workspace detail response."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "WorkspaceDetail",
      type: :object,
      properties: %{
        data: CanopyWeb.Schemas.WorkspaceSchema.Workspace
      }
    })
  end

  defmodule WorkspaceList do
    @moduledoc "Paginated list of workspaces."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "WorkspaceList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: CanopyWeb.Schemas.WorkspaceSchema.Workspace}
      }
    })
  end

  defmodule Template do
    @moduledoc "A workspace starter template."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Template",
      type: :object,
      properties: %{
        slug: %Schema{type: :string},
        name: %Schema{type: :string},
        description: %Schema{type: :string},
        files: %Schema{type: :array, items: %Schema{type: :string}}
      },
      required: [:slug, :name, :description, :files]
    })
  end

  defmodule TemplateList do
    @moduledoc "List of workspace templates."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "TemplateList",
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          items: CanopyWeb.Schemas.WorkspaceSchema.Template
        }
      }
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
        template: %Schema{type: :string, nullable: true},
        template_slug: %Schema{
          type: :string,
          nullable: true,
          description: "If provided, materialises this starter template on disk"
        }
      },
      required: [:slug, :root_path]
    })
  end

  defmodule UpdateWorkspaceRequest do
    @moduledoc "Request body for PATCH /api/v1/workspaces/:slug."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "UpdateWorkspaceRequest",
      type: :object,
      properties: %{
        name: %Schema{type: :string, nullable: true, description: "New display name"},
        root_path: %Schema{
          type: :string,
          nullable: true,
          description: "New absolute filesystem path (must exist on disk)"
        }
      }
    })
  end

  defmodule ErrorResponse do
    @moduledoc "Generic error response."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "WorkspaceErrorResponse",
      type: :object,
      properties: %{
        error: %Schema{type: :string},
        message: %Schema{type: :string}
      },
      required: [:error, :message]
    })
  end
end
