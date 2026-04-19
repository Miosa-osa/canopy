defmodule CanopyWeb.KnowledgeController do
  @moduledoc """
  HTTP API for Canopy knowledge bases.

  Routes (mounted under /api/v1 in router.ex):
    GET    /knowledge-bases                       — list KBs
    POST   /knowledge-bases                       — create KB
    GET    /knowledge-bases/:slug                 — show KB with chunk count
    DELETE /knowledge-bases/:slug                 — archive KB
    POST   /knowledge-bases/:slug/files           — add file to KB
    GET    /knowledge-bases/:slug/chunks          — list chunks (paginated)
    POST   /knowledge-bases/:slug/search          — RAG lookup
    GET    /knowledge-bases/:slug/assignments     — list agent assignments
    POST   /knowledge-bases/:slug/assignments     — assign agent
    DELETE /knowledge-bases/:slug/assignments/:agent_slug — unassign agent
    POST   /knowledge-bases/:slug/rebuild         — full re-index
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Knowledge
  alias CanopyWeb.Schemas.KnowledgeSchema

  action_fallback CanopyWeb.FallbackController

  tags ["knowledge-bases"]

  # ---------------------------------------------------------------------------
  # GET /knowledge-bases
  # ---------------------------------------------------------------------------

  operation :index,
    summary: "List knowledge bases",
    parameters: [
      workspace: [in: :query, type: :string, required: false],
      archived: [
        in: :query,
        type: :string,
        required: false,
        description: "Pass 'true' to include archived KBs"
      ]
    ],
    responses: [
      ok: {"KB list", "application/json", KnowledgeSchema.KnowledgeBaseList}
    ]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    filters =
      []
      |> maybe_put(:workspace, Map.get(params, "workspace"))
      |> maybe_put(:archived, parse_boolean(Map.get(params, "archived")))

    {:ok, bases} = Knowledge.list_bases(filters)
    json(conn, %{data: bases})
  end

  # ---------------------------------------------------------------------------
  # POST /knowledge-bases
  # ---------------------------------------------------------------------------

  operation :create,
    summary: "Create knowledge base",
    request_body: {"Create request", "application/json", KnowledgeSchema.CreateBaseBody},
    responses: [
      created: {"Created KB", "application/json", KnowledgeSchema.KnowledgeBase}
    ]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    with {:ok, kb} <- Knowledge.create_base(params) do
      conn
      |> put_status(:created)
      |> json(kb)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /knowledge-bases/:slug
  # ---------------------------------------------------------------------------

  operation :show,
    summary: "Get knowledge base detail",
    parameters: [
      slug: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"KB detail", "application/json", KnowledgeSchema.KnowledgeBase},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"slug" => slug}) do
    with {:ok, kb} <- Knowledge.get_base(slug) do
      chunk_count = Knowledge.chunk_count(kb.id)
      agent_count = Knowledge.agent_count(kb.id)

      json(conn, %{
        id: kb.id,
        slug: kb.slug,
        name: kb.name,
        description: kb.description,
        workspace_slug: kb.workspace_slug,
        embedding_model: kb.embedding_model,
        dimensions: kb.dimensions,
        chunk_size: kb.chunk_size,
        chunk_overlap: kb.chunk_overlap,
        archived_at: kb.archived_at,
        inserted_at: kb.inserted_at,
        updated_at: kb.updated_at,
        chunk_count: chunk_count,
        agent_count: agent_count
      })
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /knowledge-bases/:slug
  # ---------------------------------------------------------------------------

  operation :delete,
    summary: "Archive knowledge base",
    parameters: [
      slug: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Archived", "application/json", KnowledgeSchema.KnowledgeBase},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"slug" => slug}) do
    with {:ok, kb} <- Knowledge.get_base(slug),
         {:ok, archived} <- Knowledge.delete_base(kb.id) do
      json(conn, archived)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /knowledge-bases/:slug/files
  # ---------------------------------------------------------------------------

  operation :add_file,
    summary: "Add file to knowledge base",
    description: """
    Chunks and embeds a file into the KB. Accepts either:
    - JSON body `{\"file_id\": \"uuid\"}` to index an existing Files.FileRecord
    - Multipart upload with a `file` field (path defaults to the upload filename)
    """,
    parameters: [
      slug: [in: :path, type: :string, required: true]
    ],
    request_body: {"File reference or upload", "application/json", KnowledgeSchema.AddFileBody},
    responses: [
      ok: {"Indexed", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec add_file(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def add_file(conn, %{"slug" => slug} = params) do
    with {:ok, kb} <- Knowledge.get_base(slug),
         {:ok, source} <- resolve_file_source(params),
         {:ok, count} <- Knowledge.add_file_to_base(kb.id, source) do
      json(conn, %{indexed_chunks: count})
    end
  end

  # ---------------------------------------------------------------------------
  # GET /knowledge-bases/:slug/chunks
  # ---------------------------------------------------------------------------

  operation :list_chunks,
    summary: "List chunks in a knowledge base",
    parameters: [
      slug: [in: :path, type: :string, required: true],
      limit: [in: :query, type: :integer, required: false],
      offset: [in: :query, type: :integer, required: false]
    ],
    responses: [
      ok: {"Chunk list", "application/json", KnowledgeSchema.KbChunkList}
    ]

  @spec list_chunks(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_chunks(conn, %{"slug" => slug} = params) do
    limit = parse_int(Map.get(params, "limit"), 50)
    offset = parse_int(Map.get(params, "offset"), 0)

    with {:ok, kb} <- Knowledge.get_base(slug),
         {:ok, chunks} <- Knowledge.list_chunks(kb.id, limit, offset) do
      json(conn, %{data: chunks, limit: limit, offset: offset})
    end
  end

  # ---------------------------------------------------------------------------
  # POST /knowledge-bases/:slug/search
  # ---------------------------------------------------------------------------

  operation :search,
    summary: "Semantic search within a knowledge base",
    description: """
    Returns top-K chunks by cosine similarity.
    NOTE: Relevance ranking is a preview — zero-vector stub embeddings mean
    results are returned in insertion order, not semantic order. Wire a real
    embedding provider in Canopy.Knowledge.Embedder to enable true RAG.
    """,
    parameters: [
      slug: [in: :path, type: :string, required: true]
    ],
    request_body: {"Search request", "application/json", KnowledgeSchema.SearchBody},
    responses: [
      ok: {"Search results", "application/json", KnowledgeSchema.SearchResponse}
    ]

  @spec search(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def search(conn, %{"slug" => slug, "query" => query} = params) do
    limit = parse_int(Map.get(params, "limit"), 5)

    with {:ok, kb} <- Knowledge.get_base(slug),
         {:ok, chunks} <- Knowledge.search(kb.id, query, limit) do
      json(conn, %{
        data: chunks,
        query: query,
        note:
          "Preview — relevance ranking active when real embeddings are wired (see Canopy.Knowledge.Embedder)"
      })
    end
  end

  def search(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "missing_param", message: "query is required"})
  end

  # ---------------------------------------------------------------------------
  # GET /knowledge-bases/:slug/assignments
  # ---------------------------------------------------------------------------

  operation :list_assignments,
    summary: "List agent assignments for a knowledge base",
    parameters: [
      slug: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Assignment list", "application/json", KnowledgeSchema.KbAssignmentList},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec list_assignments(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_assignments(conn, %{"slug" => slug}) do
    with {:ok, kb} <- Knowledge.get_base(slug),
         {:ok, assignments} <- Knowledge.list_assignments(kb.id) do
      json(conn, %{data: assignments})
    end
  end

  # ---------------------------------------------------------------------------
  # POST /knowledge-bases/:slug/assignments
  # ---------------------------------------------------------------------------

  operation :assign,
    summary: "Assign an agent to a knowledge base",
    parameters: [
      slug: [in: :path, type: :string, required: true]
    ],
    request_body: {"Assign request", "application/json", KnowledgeSchema.AssignBody},
    responses: [
      created: {"Assignment created", "application/json", KnowledgeSchema.KbAssignment}
    ]

  @spec assign(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def assign(conn, %{"slug" => slug, "agent_slug" => agent_slug}) do
    with {:ok, kb} <- Knowledge.get_base(slug),
         {:ok, assignment} <- Knowledge.assign(kb.id, agent_slug) do
      conn |> put_status(:created) |> json(assignment)
    end
  end

  def assign(conn, _) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "missing_param", message: "agent_slug is required"})
  end

  # ---------------------------------------------------------------------------
  # DELETE /knowledge-bases/:slug/assignments/:agent_slug
  # ---------------------------------------------------------------------------

  operation :unassign,
    summary: "Remove an agent from a knowledge base",
    parameters: [
      slug: [in: :path, type: :string, required: true],
      agent_slug: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Unassigned", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec unassign(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def unassign(conn, %{"slug" => slug, "agent_slug" => agent_slug}) do
    with {:ok, kb} <- Knowledge.get_base(slug) do
      :ok = Knowledge.unassign(kb.id, agent_slug)
      json(conn, %{ok: true})
    end
  end

  # ---------------------------------------------------------------------------
  # POST /knowledge-bases/:slug/rebuild
  # ---------------------------------------------------------------------------

  operation :rebuild,
    summary: "Rebuild index for a knowledge base",
    description: """
    Deletes all chunks and re-indexes from Files-backed sources.
    Chunks sourced from direct uploads (no source_file_id) are NOT recoverable
    after rebuild — the binary is not stored in Canopy.
    """,
    parameters: [
      slug: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Rebuild result", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec rebuild(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def rebuild(conn, %{"slug" => slug}) do
    with {:ok, kb} <- Knowledge.get_base(slug),
         {:ok, count} <- Knowledge.rebuild_index(kb.id) do
      json(conn, %{rebuilt_chunks: count})
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec resolve_file_source(map()) ::
          {:ok, {:file_id, String.t()} | {:path, String.t(), binary()}} | {:error, term()}
  defp resolve_file_source(%{"file_id" => file_id}) when is_binary(file_id) do
    {:ok, {:file_id, file_id}}
  end

  defp resolve_file_source(%{"file" => %Plug.Upload{filename: name, path: tmp}}) do
    case File.read(tmp) do
      {:ok, content} -> {:ok, {:path, name, content}}
      {:error, reason} -> {:error, {:upload_read_failed, reason}}
    end
  end

  defp resolve_file_source(_) do
    {:error, :missing_file_source}
  end

  @spec maybe_put(keyword(), atom(), term()) :: keyword()
  defp maybe_put(opts, _, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  @spec parse_boolean(String.t() | nil) :: boolean() | nil
  defp parse_boolean("true"), do: true
  defp parse_boolean("false"), do: false
  defp parse_boolean(_), do: nil

  @spec parse_int(String.t() | integer() | nil, integer()) :: integer()
  defp parse_int(nil, default), do: default
  defp parse_int(val, _default) when is_integer(val), do: val

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end
end
