defmodule CanopyWeb.Schemas.BuildSchema do
  @moduledoc "OpenAPI schemas for the Build super-super-module."

  alias OpenApiSpex.Schema

  defmodule Layout do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        slug: %Schema{type: :string},
        name: %Schema{type: :string},
        scope: %Schema{type: :string, enum: ["personal", "team", "workspace"]},
        owner_id: %Schema{type: :string, format: :uuid, nullable: true},
        workspace_slug: %Schema{type: :string, nullable: true},
        layout_json: %Schema{type: :object, additionalProperties: true},
        default_pane_kind: %Schema{type: :string, nullable: true},
        density: %Schema{type: :string, enum: ["compact", "comfortable", "roomy"]},
        pane_title_format: %Schema{type: :string, enum: ["command", "cwd", "branch"]},
        description: %Schema{type: :string, nullable: true},
        archived_at: %Schema{type: :string, format: :"date-time", nullable: true},
        last_used_at: %Schema{type: :string, format: :"date-time", nullable: true},
        use_count: %Schema{type: :integer},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule LayoutList do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: Layout}
      }
    })
  end

  defmodule LayoutCreate do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        slug: %Schema{type: :string},
        name: %Schema{type: :string},
        scope: %Schema{type: :string, enum: ["personal", "team", "workspace"]},
        owner_id: %Schema{type: :string, format: :uuid},
        workspace_slug: %Schema{type: :string},
        layout_json: %Schema{type: :object, additionalProperties: true},
        default_pane_kind: %Schema{type: :string},
        density: %Schema{type: :string, enum: ["compact", "comfortable", "roomy"]},
        pane_title_format: %Schema{type: :string, enum: ["command", "cwd", "branch"]},
        description: %Schema{type: :string}
      },
      required: [:slug, :name]
    })
  end

  defmodule LayoutUpdate do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        name: %Schema{type: :string},
        layout_json: %Schema{type: :object, additionalProperties: true},
        default_pane_kind: %Schema{type: :string},
        density: %Schema{type: :string, enum: ["compact", "comfortable", "roomy"]},
        pane_title_format: %Schema{type: :string, enum: ["command", "cwd", "branch"]},
        description: %Schema{type: :string}
      }
    })
  end

  defmodule SuggestionResult do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        intent: %Schema{type: :string},
        count: %Schema{type: :integer},
        suggestions: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              slug: %Schema{type: :string},
              name: %Schema{type: :string},
              scope: %Schema{type: :string},
              description: %Schema{type: :string, nullable: true},
              use_count: %Schema{type: :integer},
              score: %Schema{type: :number, format: :float}
            }
          }
        }
      }
    })
  end

  defmodule SetDefaultRequest do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        workspace_slug: %Schema{type: :string}
      },
      required: [:workspace_slug]
    })
  end

  defmodule Command do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        namespace: %Schema{
          type: :string,
          enum: ["build", "runtimes", "drive", "templates", "skills"]
        },
        name: %Schema{type: :string, description: "Slash command including leading /"},
        description: %Schema{type: :string},
        icon: %Schema{type: :string, description: "lucide-svelte icon name"},
        source: %Schema{
          type: :string,
          enum: [
            "builtin",
            "runtime",
            "drive_workflow",
            "drive_prompt",
            "template",
            "skill"
          ]
        },
        source_id: %Schema{type: :string, nullable: true}
      },
      required: [:namespace, :name, :description, :icon, :source]
    })
  end

  defmodule CommandList do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: Command}
      }
    })
  end
end
