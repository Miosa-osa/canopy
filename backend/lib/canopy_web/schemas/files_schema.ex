defmodule CanopyWeb.Schemas.FilesSchema do
  @moduledoc """
  OpenAPISpex schema definitions for the Files resource.

  These are API contract schemas for `/api/v1/files`. Distinct from Ecto schemas.
  """

  alias OpenApiSpex.Schema

  defmodule FileRecord do
    @moduledoc "A Canopy indexed file (metadata only — no binary content)."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "FileRecord",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        workspace_id: %Schema{type: :string, format: :uuid},
        path: %Schema{
          type: :string,
          description: "Relative path within workspace root, e.g. 'docs/intro.md'"
        },
        name: %Schema{type: :string, description: "Filename, e.g. 'intro.md'"},
        extension: %Schema{
          type: :string,
          nullable: true,
          description: "Extension without dot, e.g. 'md'"
        },
        mime_type: %Schema{type: :string, description: "MIME type derived from extension"},
        size_bytes: %Schema{type: :integer, description: "File size in bytes"},
        sha256: %Schema{type: :string, nullable: true, description: "SHA-256 hex digest"},
        owner_type: %Schema{
          type: :string,
          enum: ["user", "agent", "system"],
          description: "Who owns this file"
        },
        owner_id: %Schema{type: :string, nullable: true, description: "UUID or slug of owner"},
        tags: %Schema{type: :array, items: %Schema{type: :string}},
        last_indexed_at: %Schema{type: :string, format: :"date-time", nullable: true},
        archived_at: %Schema{type: :string, format: :"date-time", nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :workspace_id, :path, :name, :mime_type]
    })
  end

  defmodule FileRecordDetail do
    @moduledoc "Single file detail response."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "FileRecordDetail",
      type: :object,
      properties: %{
        file: CanopyWeb.Schemas.FilesSchema.FileRecord
      }
    })
  end

  defmodule FileRecordList do
    @moduledoc "List of indexed files."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "FileRecordList",
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          items: CanopyWeb.Schemas.FilesSchema.FileRecord
        },
        count: %Schema{type: :integer}
      }
    })
  end

  defmodule ActivityEntry do
    @moduledoc "A single file activity log entry."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ActivityEntry",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        file_id: %Schema{type: :string, format: :uuid},
        actor_type: %Schema{type: :string, enum: ["user", "agent", "system"]},
        actor_id: %Schema{type: :string},
        action: %Schema{
          type: :string,
          enum: ["created", "updated", "read", "deleted", "renamed", "tagged"]
        },
        metadata: %Schema{type: :object, additionalProperties: true},
        occurred_at: %Schema{type: :string, format: :"date-time"},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :file_id, :actor_type, :actor_id, :action, :occurred_at]
    })
  end

  defmodule ActivityList do
    @moduledoc "List of file activity entries."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ActivityList",
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          items: CanopyWeb.Schemas.FilesSchema.ActivityEntry
        }
      }
    })
  end

  defmodule ScanResponse do
    @moduledoc "Response from the workspace scan endpoint."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ScanResponse",
      type: :object,
      properties: %{
        indexed: %Schema{type: :integer, description: "Number of files newly indexed or updated"},
        workspace_slug: %Schema{type: :string}
      },
      required: [:indexed, :workspace_slug]
    })
  end

  defmodule UploadResponse do
    @moduledoc "Response from the file upload endpoint."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "UploadResponse",
      type: :object,
      properties: %{
        file: CanopyWeb.Schemas.FilesSchema.FileRecord
      },
      required: [:file]
    })
  end

  defmodule SearchResponse do
    @moduledoc "Response from the file search endpoint."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SearchResponse",
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          items: CanopyWeb.Schemas.FilesSchema.FileRecord
        },
        mode: %Schema{type: :string, enum: ["name", "semantic"]},
        query: %Schema{type: :string},
        count: %Schema{type: :integer}
      }
    })
  end
end
