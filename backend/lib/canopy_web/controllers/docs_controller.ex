defmodule CanopyWeb.DocsController do
  @moduledoc """
  HTTP API for the Docs module.

  Routes:
    GET    /api/v1/docs                — list with filters
    POST   /api/v1/docs                — create document
    GET    /api/v1/docs/search         — full-text search
    GET    /api/v1/docs/:id            — get by id
    PUT    /api/v1/docs/:id            — update
    POST   /api/v1/docs/:id/publish    — publish
    POST   /api/v1/docs/:id/unpublish  — unpublish
    POST   /api/v1/docs/:id/archive    — archive
    POST   /api/v1/docs/:id/unarchive  — unarchive
    DELETE /api/v1/docs/:id            — hard delete
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Docs
  alias CanopyWeb.Schemas.DocsSchema

  action_fallback CanopyWeb.FallbackController

  tags ["docs"]

  operation :index,
    summary: "List documents",
    parameters: [
      workspace_slug: [in: :query, type: :string, required: false],
      folder_id: [in: :query, type: :string, required: false],
      author_id: [in: :query, type: :string, required: false],
      tag: [in: :query, type: :string, required: false],
      published: [in: :query, type: :boolean, required: false],
      q: [in: :query, type: :string, required: false]
    ],
    responses: [ok: {"Document list", "application/json", DocsSchema.DocumentList}]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    filters =
      params
      |> Map.take(["workspace_slug", "folder_id", "author_id", "tag", "published", "archived"])
      |> maybe_add_text_query(params)

    docs = Docs.list_documents(filters)
    json(conn, %{data: docs})
  end

  operation :create,
    summary: "Create a document",
    request_body:
      {"Create document params", "application/json", DocsSchema.CreateDocumentRequest},
    responses: [
      created: {"Document created", "application/json", DocsSchema.DocumentDetail},
      unprocessable_entity: {"Validation error", "application/json", DocsSchema.ErrorResponse}
    ]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    case Docs.create(params) do
      {:ok, doc} ->
        conn |> put_status(:created) |> json(%{data: doc})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  operation :search,
    summary: "Full-text search over documents",
    parameters: [
      q: [in: :query, type: :string, required: true],
      workspace_slug: [in: :query, type: :string, required: true]
    ],
    responses: [ok: {"Search results", "application/json", DocsSchema.DocumentList}]

  @spec search(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def search(conn, %{"q" => query, "workspace_slug" => workspace_slug}) do
    results = Docs.search(workspace_slug, query)
    json(conn, %{data: results})
  end

  def search(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      error: "bad_request",
      message: "Both 'q' and 'workspace_slug' params are required."
    })
  end

  operation :show,
    summary: "Get a document by id",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Document", "application/json", DocsSchema.DocumentDetail},
      not_found: {"Not found", "application/json", DocsSchema.ErrorResponse}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    with {:ok, doc} <- Docs.get(id) do
      json(conn, %{data: doc})
    end
  end

  operation :update,
    summary: "Update a document",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Update params", "application/json", DocsSchema.UpdateDocumentRequest},
    responses: [
      ok: {"Updated document", "application/json", DocsSchema.DocumentDetail},
      not_found: {"Not found", "application/json", DocsSchema.ErrorResponse},
      unprocessable_entity: {"Validation error", "application/json", DocsSchema.ErrorResponse}
    ]

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    with {:ok, doc} <- Docs.get(id) do
      case Docs.update(doc, params) do
        {:ok, updated} -> json(conn, %{data: updated})
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  operation :publish,
    summary: "Publish a document",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Published document", "application/json", DocsSchema.DocumentDetail},
      not_found: {"Not found", "application/json", DocsSchema.ErrorResponse}
    ]

  @spec publish(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def publish(conn, %{"id" => id}) do
    with {:ok, doc} <- Docs.publish(id) do
      json(conn, %{data: doc})
    end
  end

  operation :unpublish,
    summary: "Unpublish a document",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Unpublished document", "application/json", DocsSchema.DocumentDetail},
      not_found: {"Not found", "application/json", DocsSchema.ErrorResponse}
    ]

  @spec unpublish(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def unpublish(conn, %{"id" => id}) do
    with {:ok, doc} <- Docs.unpublish(id) do
      json(conn, %{data: doc})
    end
  end

  operation :archive,
    summary: "Archive a document",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Archived document", "application/json", DocsSchema.DocumentDetail},
      not_found: {"Not found", "application/json", DocsSchema.ErrorResponse}
    ]

  @spec archive(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def archive(conn, %{"id" => id}) do
    with {:ok, doc} <- Docs.archive(id) do
      json(conn, %{data: doc})
    end
  end

  operation :unarchive,
    summary: "Unarchive a document",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Unarchived document", "application/json", DocsSchema.DocumentDetail},
      not_found: {"Not found", "application/json", DocsSchema.ErrorResponse}
    ]

  @spec unarchive(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def unarchive(conn, %{"id" => id}) do
    with {:ok, doc} <- Docs.unarchive(id) do
      json(conn, %{data: doc})
    end
  end

  operation :delete,
    summary: "Hard-delete a document",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      no_content: "Deleted",
      not_found: {"Not found", "application/json", DocsSchema.ErrorResponse}
    ]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    with {:ok, _doc} <- Docs.delete(id) do
      send_resp(conn, :no_content, "")
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp maybe_add_text_query(filters, %{"q" => q}) when is_binary(q) and q != "" do
    Map.put(filters, "text_query", q)
  end

  defp maybe_add_text_query(filters, _), do: filters
end
