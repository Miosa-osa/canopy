defmodule CanopyWeb.Schemas.KnowledgeSchema do
  @moduledoc """
  OpenAPISpex schema definitions for the Knowledge Bases resource.

  API contract schemas for `/api/v1/knowledge-bases`. Distinct from Ecto schemas.
  """

  alias OpenApiSpex.Schema

  defmodule KnowledgeBase do
    @moduledoc "A named collection of chunked, embedded documents for RAG retrieval."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "KnowledgeBase",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        slug: %Schema{type: :string, description: "Stable URL-safe identifier"},
        name: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        workspace_slug: %Schema{type: :string, nullable: true},
        embedding_model: %Schema{type: :string, default: "text-embedding-3-small"},
        dimensions: %Schema{type: :integer, default: 1536},
        chunk_size: %Schema{type: :integer, default: 800},
        chunk_overlap: %Schema{type: :integer, default: 100},
        chunk_count: %Schema{type: :integer, description: "Total chunks in this KB"},
        archived_at: %Schema{type: :string, format: :"date-time", nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :slug, :name, :embedding_model, :dimensions, :chunk_size, :chunk_overlap]
    })
  end

  defmodule KnowledgeBaseList do
    @moduledoc "List of knowledge bases."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "KnowledgeBaseList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: KnowledgeBase}
      },
      required: [:data]
    })
  end

  defmodule KbChunk do
    @moduledoc "A single chunk of indexed content within a KB."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "KbChunk",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        kb_id: %Schema{type: :string, format: :uuid},
        source_file_id: %Schema{type: :string, format: :uuid, nullable: true},
        source_path: %Schema{type: :string},
        chunk_index: %Schema{type: :integer},
        content: %Schema{type: :string},
        content_hash: %Schema{type: :string, description: "SHA256 of content"},
        token_count: %Schema{type: :integer},
        metadata: %Schema{type: :object},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :kb_id, :source_path, :chunk_index, :content, :content_hash, :token_count]
    })
  end

  defmodule KbChunkList do
    @moduledoc "Paginated list of chunks."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "KbChunkList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: KbChunk},
        limit: %Schema{type: :integer},
        offset: %Schema{type: :integer}
      },
      required: [:data]
    })
  end

  defmodule KbAssignment do
    @moduledoc "A KB-to-agent assignment record."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "KbAssignment",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        kb_id: %Schema{type: :string, format: :uuid},
        agent_slug: %Schema{type: :string},
        priority: %Schema{type: :integer, default: 0},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :kb_id, :agent_slug, :priority]
    })
  end

  defmodule CreateBaseBody do
    @moduledoc "Request body for creating a knowledge base."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "CreateBaseBody",
      type: :object,
      properties: %{
        slug: %Schema{type: :string},
        name: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        workspace_slug: %Schema{type: :string, nullable: true},
        embedding_model: %Schema{type: :string},
        dimensions: %Schema{type: :integer},
        chunk_size: %Schema{type: :integer},
        chunk_overlap: %Schema{type: :integer}
      },
      required: [:slug, :name]
    })
  end

  defmodule AddFileBody do
    @moduledoc "Request body for adding a file to a KB by file_id reference."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AddFileBody",
      type: :object,
      properties: %{
        file_id: %Schema{type: :string, format: :uuid, description: "Files.FileRecord id"}
      },
      required: [:file_id]
    })
  end

  defmodule SearchBody do
    @moduledoc "Request body for KB semantic search."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SearchBody",
      type: :object,
      properties: %{
        query: %Schema{type: :string},
        limit: %Schema{type: :integer, default: 5}
      },
      required: [:query]
    })
  end

  defmodule AssignBody do
    @moduledoc "Request body for assigning an agent to a KB."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AssignBody",
      type: :object,
      properties: %{
        agent_slug: %Schema{type: :string}
      },
      required: [:agent_slug]
    })
  end

  defmodule SearchResponse do
    @moduledoc "Search results with matched chunks."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SearchResponse",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: KbChunk},
        query: %Schema{type: :string},
        note: %Schema{
          type: :string,
          description: "Preview note about ranking behavior with stub embeddings"
        }
      },
      required: [:data, :query]
    })
  end
end
