defmodule CanopyWeb.Schemas.ToolSchema do
  @moduledoc """
  OpenAPISpex schema definitions for the Tools resource.

  These are API contract schemas for `/api/v1/tools`. Distinct from the
  internal `Canopy.Tools.Tool` struct — they define what the HTTP API
  exposes, not the runtime shape.
  """

  alias OpenApiSpex.Schema

  defmodule Tool do
    @moduledoc "A registered agent-callable tool."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Tool",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Unique tool name, e.g. \"read_file\""},
        description: %Schema{
          type: :string,
          description: "Human-readable description shown to LLM"
        },
        parameters: %Schema{
          type: :object,
          description: "JSON Schema describing accepted arguments"
        },
        requires: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "Capability atoms the runtime must possess to use this tool"
        },
        mcp_exposed: %Schema{
          type: :boolean,
          description: "Whether this tool appears in the MCP server manifest"
        },
        prompt_exposed: %Schema{
          type: :boolean,
          description: "Whether this tool is injected as a curl instruction for non-MCP runtimes"
        }
      },
      required: [:name, :description, :parameters]
    })
  end

  defmodule ToolList do
    @moduledoc "A list of registered tools."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ToolList",
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          items: Tool
        }
      },
      required: [:data]
    })
  end

  defmodule DispatchRequest do
    @moduledoc "Request body for dispatching a tool."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DispatchRequest",
      type: :object,
      properties: %{
        args: %Schema{
          type: :object,
          description: "Arguments map matching the tool's parameter schema"
        }
      },
      required: [:args]
    })
  end

  defmodule DispatchResponse do
    @moduledoc "Successful dispatch response."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DispatchResponse",
      type: :object,
      properties: %{
        result: %Schema{
          description: "Value returned by the tool handler (shape is tool-specific)"
        }
      },
      required: [:result]
    })
  end

  defmodule ErrorResponse do
    @moduledoc "Generic error response for tool endpoints."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ToolErrorResponse",
      type: :object,
      properties: %{
        error: %Schema{type: :string},
        message: %Schema{type: :string, nullable: true}
      },
      required: [:error]
    })
  end
end
