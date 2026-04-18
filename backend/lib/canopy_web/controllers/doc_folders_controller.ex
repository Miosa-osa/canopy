defmodule CanopyWeb.DocFoldersController do
  @moduledoc """
  HTTP API for document folders.

  Routes:
    GET    /api/v1/doc-folders?workspace=slug   — flat list of folders
    GET    /api/v1/doc-folders/tree             — hierarchical tree
    POST   /api/v1/doc-folders                  — create folder
    PATCH  /api/v1/doc-folders/:id              — update folder
    DELETE /api/v1/doc-folders/:id              — archive folder (soft-delete)
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Docs
  alias CanopyWeb.Schemas.DocsSchema

  action_fallback CanopyWeb.FallbackController

  tags ["doc-folders"]

  # ---------------------------------------------------------------------------
  # GET /api/v1/doc-folders
  # ---------------------------------------------------------------------------

  operation :index,
    summary: "List doc folders (flat)",
    parameters: [
      workspace: [in: :query, type: :string, required: true, description: "Workspace slug"]
    ],
    responses: [
      ok: {"Folder list", "application/json", DocsSchema.DocFolderList}
    ]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, %{"workspace" => workspace_slug}) do
    folders = Docs.list_folders(workspace_slug)
    json(conn, %{data: folders})
  end

  def index(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: "'workspace' query param is required."})
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/doc-folders/tree
  # ---------------------------------------------------------------------------

  operation :tree,
    summary: "Get doc folder tree (hierarchical)",
    parameters: [
      workspace: [in: :query, type: :string, required: true, description: "Workspace slug"]
    ],
    responses: [
      ok: {"Folder tree", "application/json", DocsSchema.DocFolderTree}
    ]

  @spec tree(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def tree(conn, %{"workspace" => workspace_slug}) do
    tree = Docs.get_folder_tree(workspace_slug)
    json(conn, %{data: tree})
  end

  def tree(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: "'workspace' query param is required."})
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/doc-folders
  # ---------------------------------------------------------------------------

  operation :create,
    summary: "Create a doc folder",
    request_body: {"Create folder params", "application/json", DocsSchema.CreateFolderRequest},
    responses: [
      created: {"Folder created", "application/json", DocsSchema.DocFolderDetail},
      unprocessable_entity: {"Validation error", "application/json", DocsSchema.ErrorResponse}
    ]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    case Docs.create_folder(params) do
      {:ok, folder} ->
        conn
        |> put_status(:created)
        |> json(%{data: folder})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/doc-folders/:id
  # ---------------------------------------------------------------------------

  operation :update,
    summary: "Update a doc folder",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Update folder params", "application/json", DocsSchema.UpdateFolderRequest},
    responses: [
      ok: {"Folder updated", "application/json", DocsSchema.DocFolderDetail},
      not_found: {"Not found", "application/json", DocsSchema.ErrorResponse},
      unprocessable_entity: {"Validation error", "application/json", DocsSchema.ErrorResponse}
    ]

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    with {:ok, folder} <- Docs.get_folder(id) do
      case Docs.update_folder(folder, params) do
        {:ok, updated} -> json(conn, %{data: updated})
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/doc-folders/:id
  # ---------------------------------------------------------------------------

  operation :delete,
    summary: "Archive a doc folder (soft-delete)",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      no_content: "Folder archived",
      not_found: {"Not found", "application/json", DocsSchema.ErrorResponse}
    ]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    with {:ok, _folder} <- Docs.archive_folder(id) do
      send_resp(conn, :no_content, "")
    end
  end
end
