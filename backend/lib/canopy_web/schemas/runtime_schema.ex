defmodule CanopyWeb.Schemas.RuntimeSchema do
  @moduledoc """
  OpenAPISpex schema definitions for the Runtime resource.

  These are API contract schemas for `/api/v1/runtimes`. They are distinct from
  the Ecto schemas — they define what the HTTP API exposes, not the DB shape.
  """

  alias OpenApiSpex.Schema

  defmodule Runtime do
    @moduledoc "A detected AI runtime available on the user's machine."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Runtime",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "Runtime ID"},
        type: %Schema{type: :string, description: "Unique type identifier, e.g. claude-local"},
        kind: %Schema{
          type: :string,
          enum: ["cli", "api", "mcp"],
          description: "Runtime interface kind"
        },
        name: %Schema{type: :string, description: "Human-readable runtime name"},
        enabled: %Schema{type: :boolean, description: "Whether the runtime is enabled"},
        installed: %Schema{
          type: :boolean,
          description: "Whether the binary was detected on PATH"
        },
        version: %Schema{
          type: :string,
          nullable: true,
          description: "Detected version string"
        },
        binary_path: %Schema{
          type: :string,
          nullable: true,
          description: "Absolute path to the runtime binary"
        },
        capabilities: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "List of capability strings from the adapter"
        },
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :type, :kind, :name, :enabled, :installed]
    })
  end

  defmodule RuntimeList do
    @moduledoc "A list of runtimes."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "RuntimeList",
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          items: Runtime
        }
      },
      required: [:data]
    })
  end
end
