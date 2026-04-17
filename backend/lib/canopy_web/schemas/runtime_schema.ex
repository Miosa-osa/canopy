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

  defmodule RuntimeDetail do
    @moduledoc "Detailed runtime info including config schema, models, and quota."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "RuntimeDetail",
      type: :object,
      properties: %{
        type: %Schema{type: :string},
        capabilities: %Schema{type: :array, items: %Schema{type: :string}},
        config_schema: %Schema{type: :array, description: "Declarative config field specs"},
        models: %Schema{type: :array, description: "Available models"},
        quota_windows: %Schema{
          type: :array,
          nullable: true,
          description: "Live quota windows if supported"
        }
      },
      required: [:type, :capabilities, :config_schema, :models]
    })
  end

  defmodule EnvironmentCheck do
    @moduledoc "A single environment preflight check result."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "EnvironmentCheck",
      type: :object,
      properties: %{
        level: %Schema{type: :string, enum: ["info", "warn", "error"]},
        message: %Schema{type: :string}
      },
      required: [:level, :message]
    })
  end

  defmodule EnvironmentCheckList do
    @moduledoc "Result of running runtime preflight checks."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "EnvironmentCheckList",
      type: :object,
      properties: %{
        checks: %Schema{type: :array, items: EnvironmentCheck}
      },
      required: [:checks]
    })
  end

  defmodule ModelList do
    @moduledoc "A list of models available for a runtime."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ModelList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, description: "Model objects from the adapter"}
      },
      required: [:data]
    })
  end

  defmodule ErrorResponse do
    @moduledoc "Generic error response."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ErrorResponse",
      type: :object,
      properties: %{
        error: %Schema{type: :string},
        message: %Schema{type: :string}
      },
      required: [:error]
    })
  end

  defmodule DetectedItem do
    @moduledoc "Single result from the Tauri runtime_detect sidecar command."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DetectedItem",
      type: :object,
      properties: %{
        slug: %Schema{type: :string, description: "Canonical runtime type (e.g. claude-local)"},
        installed: %Schema{type: :boolean},
        path: %Schema{type: :string, nullable: true, description: "Absolute path to binary"},
        version: %Schema{type: :string, nullable: true, description: "Detected version"}
      },
      required: [:slug, :installed]
    })
  end

  defmodule DetectRequest do
    @moduledoc "Wrapper for POST /runtimes/detect body — list of DetectedItem."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DetectRequest",
      type: :object,
      properties: %{
        detected: %Schema{type: :array, items: DetectedItem}
      },
      required: [:detected]
    })
  end
end
