defmodule CanopyWeb.Schemas.DocsSchema do
  @moduledoc """
  OpenAPISpex schema definitions for the Docs module resources:
  DocFolder, Document, DocumentVersion, and request/response wrappers.
  """

  alias OpenApiSpex.Schema

  # ---------------------------------------------------------------------------
  # DocFolder
  # ---------------------------------------------------------------------------

  defmodule DocFolder do
    @moduledoc "A document folder within a workspace."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DocFolder",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        name: %Schema{type: :string},
        parent_id: %Schema{type: :string, format: :uuid, nullable: true},
        workspace_slug: %Schema{type: :string},
        owner_user_id: %Schema{type: :string, format: :uuid, nullable: true},
        owner_agent_slug: %Schema{type: :string, nullable: true},
        color: %Schema{type: :string, nullable: true},
        sort_order: %Schema{type: :integer},
        archived_at: %Schema{type: :string, format: :"date-time", nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :name, :workspace_slug]
    })
  end

  defmodule DocFolderWithChildren do
    @moduledoc "A folder with its nested children tree."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DocFolderWithChildren",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        name: %Schema{type: :string},
        parent_id: %Schema{type: :string, format: :uuid, nullable: true},
        workspace_slug: %Schema{type: :string},
        color: %Schema{type: :string, nullable: true},
        sort_order: %Schema{type: :integer},
        archived_at: %Schema{type: :string, format: :"date-time", nullable: true},
        children: %Schema{
          type: :array,
          # Recursive self-reference represented as generic object to avoid circular schema issue.
          items: %Schema{type: :object}
        }
      },
      required: [:id, :name, :workspace_slug, :children]
    })
  end

  defmodule DocFolderList do
    @moduledoc "List of folders."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DocFolderList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: CanopyWeb.Schemas.DocsSchema.DocFolder}
      }
    })
  end

  defmodule DocFolderTree do
    @moduledoc "Hierarchical folder tree response."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DocFolderTree",
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          items: CanopyWeb.Schemas.DocsSchema.DocFolderWithChildren
        }
      }
    })
  end

  defmodule DocFolderDetail do
    @moduledoc "Single folder detail response."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DocFolderDetail",
      type: :object,
      properties: %{data: CanopyWeb.Schemas.DocsSchema.DocFolder}
    })
  end

  defmodule CreateFolderRequest do
    @moduledoc "Request body for POST /api/v1/doc-folders."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "CreateFolderRequest",
      type: :object,
      properties: %{
        name: %Schema{type: :string},
        workspace_slug: %Schema{type: :string},
        parent_id: %Schema{type: :string, format: :uuid, nullable: true},
        owner_user_id: %Schema{type: :string, format: :uuid, nullable: true},
        owner_agent_slug: %Schema{type: :string, nullable: true},
        color: %Schema{type: :string, nullable: true},
        sort_order: %Schema{type: :integer, nullable: true}
      },
      required: [:name, :workspace_slug]
    })
  end

  defmodule UpdateFolderRequest do
    @moduledoc "Request body for PATCH /api/v1/doc-folders/:id."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "UpdateFolderRequest",
      type: :object,
      properties: %{
        name: %Schema{type: :string, nullable: true},
        parent_id: %Schema{type: :string, format: :uuid, nullable: true},
        color: %Schema{type: :string, nullable: true},
        sort_order: %Schema{type: :integer, nullable: true}
      }
    })
  end

  # ---------------------------------------------------------------------------
  # Document
  # ---------------------------------------------------------------------------

  defmodule Document do
    @moduledoc "A rich-text document."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Document",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        slug: %Schema{type: :string},
        folder_id: %Schema{type: :string, format: :uuid, nullable: true},
        workspace_slug: %Schema{type: :string},
        title: %Schema{type: :string},
        body_json: %Schema{type: :object, description: "ProseMirror JSON document tree"},
        body_text: %Schema{type: :string, description: "Derived plaintext for full-text search"},
        summary: %Schema{type: :string, nullable: true},
        author_type: %Schema{type: :string, enum: ["user", "agent"]},
        author_id: %Schema{type: :string},
        last_editor_type: %Schema{type: :string, enum: ["user", "agent"]},
        last_editor_id: %Schema{type: :string},
        published: %Schema{type: :boolean},
        published_at: %Schema{type: :string, format: :"date-time", nullable: true},
        tags: %Schema{type: :array, items: %Schema{type: :string}},
        version: %Schema{type: :integer},
        archived_at: %Schema{type: :string, format: :"date-time", nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :slug, :workspace_slug, :title, :version]
    })
  end

  defmodule DocumentDetail do
    @moduledoc "Single document detail response."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DocumentDetail",
      type: :object,
      properties: %{data: CanopyWeb.Schemas.DocsSchema.Document}
    })
  end

  defmodule DocumentList do
    @moduledoc "List of documents."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DocumentList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: CanopyWeb.Schemas.DocsSchema.Document}
      }
    })
  end

  defmodule CreateDocumentRequest do
    @moduledoc "Request body for POST /api/v1/docs."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "CreateDocumentRequest",
      type: :object,
      properties: %{
        slug: %Schema{type: :string},
        workspace_slug: %Schema{type: :string},
        title: %Schema{type: :string},
        folder_id: %Schema{type: :string, format: :uuid, nullable: true},
        body_json: %Schema{type: :object, nullable: true},
        summary: %Schema{type: :string, nullable: true},
        author_type: %Schema{type: :string, enum: ["user", "agent"]},
        author_id: %Schema{type: :string},
        last_editor_type: %Schema{type: :string, enum: ["user", "agent"]},
        last_editor_id: %Schema{type: :string},
        tags: %Schema{type: :array, items: %Schema{type: :string}, nullable: true}
      },
      required: [
        :slug,
        :workspace_slug,
        :title,
        :author_type,
        :author_id,
        :last_editor_type,
        :last_editor_id
      ]
    })
  end

  defmodule UpdateDocumentRequest do
    @moduledoc "Request body for PUT /api/v1/docs/:id. Requires expected_version."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "UpdateDocumentRequest",
      type: :object,
      properties: %{
        expected_version: %Schema{
          type: :integer,
          description: "Must match the current document version (optimistic lock)"
        },
        title: %Schema{type: :string, nullable: true},
        body_json: %Schema{type: :object, nullable: true},
        folder_id: %Schema{type: :string, format: :uuid, nullable: true},
        summary: %Schema{type: :string, nullable: true},
        tags: %Schema{type: :array, items: %Schema{type: :string}, nullable: true},
        last_editor_type: %Schema{type: :string, enum: ["user", "agent"], nullable: true},
        last_editor_id: %Schema{type: :string, nullable: true},
        change_summary: %Schema{type: :string, nullable: true}
      },
      required: [:expected_version]
    })
  end

  # ---------------------------------------------------------------------------
  # DocumentVersion
  # ---------------------------------------------------------------------------

  defmodule DocumentVersion do
    @moduledoc "An immutable document version snapshot."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DocumentVersion",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        document_id: %Schema{type: :string, format: :uuid},
        version: %Schema{type: :integer},
        body_json: %Schema{type: :object},
        body_text: %Schema{type: :string},
        editor_type: %Schema{type: :string},
        editor_id: %Schema{type: :string},
        change_summary: %Schema{type: :string, nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :document_id, :version]
    })
  end

  defmodule DocumentVersionList do
    @moduledoc "List of document versions."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DocumentVersionList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: CanopyWeb.Schemas.DocsSchema.DocumentVersion}
      }
    })
  end

  defmodule DocumentVersionDetail do
    @moduledoc "Single document version detail."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DocumentVersionDetail",
      type: :object,
      properties: %{data: CanopyWeb.Schemas.DocsSchema.DocumentVersion}
    })
  end

  # ---------------------------------------------------------------------------
  # Shared
  # ---------------------------------------------------------------------------

  defmodule ErrorResponse do
    @moduledoc "Generic error response for docs endpoints."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DocsErrorResponse",
      type: :object,
      properties: %{
        error: %Schema{type: :string},
        message: %Schema{type: :string}
      },
      required: [:error, :message]
    })
  end
end
