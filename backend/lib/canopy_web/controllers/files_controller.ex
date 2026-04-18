defmodule CanopyWeb.FilesController do
  @moduledoc """
  HTTP API for the file index — metadata, uploads, search, and activity.

  Binary content is stored on disk via `Canopy.Workspaces.Files`.
  This controller manages the DB metadata index via `Canopy.Files`.

  Routes (added to router.ex under :api pipeline):
    POST   /api/v1/files                        — upload + index
    GET    /api/v1/files?workspace=slug&...     — list files
    GET    /api/v1/files/search                 — name or semantic search
    POST   /api/v1/files/scan                   — trigger workspace scan
    GET    /api/v1/files/:id                    — file metadata
    GET    /api/v1/files/:id/content            — stream file bytes
    GET    /api/v1/files/:id/activity           — activity log
    PATCH  /api/v1/files/:id                    — update tags
    DELETE /api/v1/files/:id                    — soft archive
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Files
  alias Canopy.Workspaces
  alias Canopy.Workspaces.Files, as: WorkspaceFiles
  alias CanopyWeb.Schemas.FilesSchema

  action_fallback CanopyWeb.FallbackController

  tags ["files"]

  # ---------------------------------------------------------------------------
  # POST /api/v1/files (multipart upload)
  # ---------------------------------------------------------------------------

  operation :upload,
    summary: "Upload and index a file",
    description: """
    Accepts multipart/form-data with fields: `workspace_slug` (string),
    `path` (relative path, e.g. "docs/intro.md"), `file` (binary).

    Saves bytes to `{workspace.root_path}/{path}` via Workspaces.Files,
    then creates or updates the DB index entry and logs activity.
    """,
    request_body: {"Multipart upload", "multipart/form-data", %OpenApiSpex.Schema{type: :object}},
    responses: [
      created: {"File uploaded and indexed", "application/json", FilesSchema.UploadResponse},
      bad_request:
        {"Missing params or traversal", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Workspace not found", "application/json", %OpenApiSpex.Schema{type: :object}},
      unprocessable_entity:
        {"Validation error", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec upload(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def upload(conn, %{"workspace_slug" => slug, "path" => rel_path} = params) do
    upload_info = params["file"]

    if is_nil(upload_info) do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "missing_file", message: "Multipart field 'file' is required."})
    else
      with {:ok, workspace} <- Workspaces.get_by_slug(slug),
           {:ok, content} <- read_upload(upload_info),
           :ok <- WorkspaceFiles.write_file(workspace, rel_path, content),
           actor <- current_actor(conn),
           {:ok, file} <- Files.index_file(workspace.id, rel_path, %{actor: actor}) do
        conn
        |> put_status(:created)
        |> json(%{file: file})
      else
        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "not_found", message: "Workspace not found."})

        {:error, :traversal} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "traversal_rejected", message: "Path traversal rejected."})

        {:error, changeset} when is_struct(changeset, Ecto.Changeset) ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: format_changeset(changeset)})

        {:error, reason} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "upload_failed", message: inspect(reason)})
      end
    end
  end

  def upload(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_params", message: "workspace_slug and path are required."})
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/files?workspace=slug&tag=...&q=...&extension=...
  # ---------------------------------------------------------------------------

  operation :index,
    summary: "List indexed files",
    description:
      "Lists files in a workspace. Filterable by extension, tag, owner, and name query.",
    parameters: [
      workspace: [in: :query, type: :string, required: true, description: "Workspace slug"],
      extension: [in: :query, type: :string, required: false],
      tag: [in: :query, type: :string, required: false],
      q: [in: :query, type: :string, required: false, description: "ILIKE name search"],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [
      ok: {"File list", "application/json", FilesSchema.FileRecordList},
      bad_request:
        {"Missing workspace param", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Workspace not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, %{"workspace" => slug} = params) do
    with {:ok, workspace} <- Workspaces.get_by_slug(slug) do
      filters =
        %{workspace_id: workspace.id}
        |> maybe_put(:extension, params["extension"])
        |> maybe_put(:tag, params["tag"])
        |> maybe_put(:q, params["q"])
        |> maybe_put(:limit, parse_int(params["limit"]))

      {:ok, files} = Files.list(filters)
      json(conn, %{data: files, count: length(files)})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Workspace not found."})
    end
  end

  def index(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_params", message: "workspace query param is required."})
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/files/:id
  # ---------------------------------------------------------------------------

  operation :show,
    summary: "Get file metadata",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"File metadata", "application/json", FilesSchema.FileRecordDetail},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    with {:ok, file} <- Files.get(id) do
      json(conn, %{file: file})
    else
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not_found", message: "File not found."})
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/files/:id/content
  # ---------------------------------------------------------------------------

  operation :content,
    summary: "Stream file bytes",
    description:
      "Returns the raw file bytes from disk. Sets Content-Type and Content-Disposition.",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok:
        {"File bytes", "application/octet-stream",
         %OpenApiSpex.Schema{type: :string, format: :binary}},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec content(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def content(conn, %{"id" => id}) do
    with {:ok, file} <- Files.get(id),
         {:ok, workspace} <- Workspaces.get_by_id(file.workspace_id),
         {:ok, bytes} <- WorkspaceFiles.read_file(workspace, file.path) do
      actor = current_actor(conn)
      Files.record_read(file.id, actor)

      conn
      |> put_resp_content_type(file.mime_type)
      |> put_resp_header(
        "content-disposition",
        "attachment; filename=\"#{file.name}\""
      )
      |> send_resp(200, bytes)
    else
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not_found", message: "File not found."})

      {:error, :too_large} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "too_large", message: "File exceeds read limit."})

      {:error, :not_utf8} ->
        # Binary files: read raw bytes without UTF-8 check
        with {:ok, file} <- Files.get(id),
             {:ok, workspace} <- Workspaces.get_by_id(file.workspace_id) do
          abs_path = Path.join(workspace.root_path, file.path)

          case File.read(abs_path) do
            {:ok, bytes} ->
              conn
              |> put_resp_content_type(file.mime_type)
              |> put_resp_header("content-disposition", "attachment; filename=\"#{file.name}\"")
              |> send_resp(200, bytes)

            {:error, _} ->
              conn
              |> put_status(:not_found)
              |> json(%{error: "not_found", message: "File not readable."})
          end
        end

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "read_failed", message: inspect(reason)})
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/files/:id
  # ---------------------------------------------------------------------------

  operation :update,
    summary: "Update file tags",
    description: "Updates the tags list on a file. Only tags can be patched via this endpoint.",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Tag update", "application/json", %OpenApiSpex.Schema{type: :object}},
    responses: [
      ok: {"Updated file", "application/json", FilesSchema.FileRecordDetail},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}},
      unprocessable_entity:
        {"Validation error", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "tags" => tags}) when is_list(tags) do
    actor = current_actor(conn)

    with {:ok, file} <- Files.update_tags(id, tags, actor) do
      json(conn, %{file: file})
    else
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not_found", message: "File not found."})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: format_changeset(changeset)})
    end
  end

  def update(conn, %{"id" => _id}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_params", message: "tags (array) is required."})
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/files/:id
  # ---------------------------------------------------------------------------

  operation :delete,
    summary: "Soft-archive a file",
    description: "Sets archived_at. Does NOT delete the file from disk.",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      no_content: "File archived",
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    actor = current_actor(conn)

    with {:ok, _file} <- Files.archive(id, actor) do
      send_resp(conn, :no_content, "")
    else
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not_found", message: "File not found."})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "archive_failed", message: inspect(reason)})
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/files/scan
  # ---------------------------------------------------------------------------

  operation :scan,
    summary: "Scan and index a workspace",
    description: "Walks the workspace tree and indexes all non-hidden files. Idempotent.",
    request_body:
      {"Scan params — {workspace_slug: string}", "application/json",
       %OpenApiSpex.Schema{type: :object}},
    responses: [
      ok: {"Scan result", "application/json", FilesSchema.ScanResponse},
      not_found: {"Workspace not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec scan(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def scan(conn, %{"workspace_slug" => slug}) do
    with {:ok, workspace} <- Workspaces.get_by_slug(slug),
         {:ok, count} <- Files.index_workspace(workspace.id) do
      json(conn, %{indexed: count, workspace_slug: workspace.slug})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Workspace not found."})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "scan_failed", message: inspect(reason)})
    end
  end

  def scan(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_params", message: "workspace_slug is required."})
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/files/:id/activity
  # ---------------------------------------------------------------------------

  operation :activity,
    summary: "Get file activity log",
    parameters: [
      id: [in: :path, type: :string, required: true],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [
      ok: {"Activity log", "application/json", FilesSchema.ActivityList},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec activity(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def activity(conn, %{"id" => id} = params) do
    limit = parse_int(params["limit"]) || 50

    with {:ok, _file} <- Files.get(id),
         {:ok, entries} <- Files.list_activity(id, limit) do
      json(conn, %{data: entries})
    else
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not_found", message: "File not found."})
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/files/search?workspace=slug&q=...&mode=name|semantic&limit=...
  # ---------------------------------------------------------------------------

  operation :search,
    summary: "Search files by name or semantic similarity",
    parameters: [
      workspace: [in: :query, type: :string, required: true, description: "Workspace slug"],
      q: [in: :query, type: :string, required: true, description: "Search query"],
      mode: [
        in: :query,
        type: :string,
        required: false,
        description: "Search mode: 'name' (default) or 'semantic'"
      ],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [
      ok: {"Search results", "application/json", FilesSchema.SearchResponse},
      bad_request: {"Missing params", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Workspace not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec search(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def search(conn, %{"workspace" => slug, "q" => query} = params) do
    limit = parse_int(params["limit"]) || 20

    with {:ok, workspace} <- Workspaces.get_by_slug(slug),
         {:ok, results} <- Files.search_by_name(workspace.id, query, limit) do
      json(conn, %{data: results, mode: "name", query: query, count: length(results)})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Workspace not found."})
    end
  end

  def search(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_params", message: "workspace and q params are required."})
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Reads upload content — handles both Plug.Upload struct and raw binary.
  @spec read_upload(Plug.Upload.t() | binary()) :: {:ok, binary()} | {:error, term()}
  defp read_upload(%Plug.Upload{path: tmp_path}), do: File.read(tmp_path)
  defp read_upload(binary) when is_binary(binary), do: {:ok, binary}
  defp read_upload(_), do: {:error, :invalid_upload}

  # Returns an actor map from conn assigns (optional auth — may be nil).
  @spec current_actor(Plug.Conn.t()) :: map()
  defp current_actor(conn) do
    case conn.assigns[:current_user] do
      nil -> %{type: "system", id: nil}
      user -> %{type: "user", id: to_string(user.id)}
    end
  end

  @spec maybe_put(map(), atom(), term()) :: map()
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  @spec parse_int(String.t() | nil) :: integer() | nil
  defp parse_int(nil), do: nil

  defp parse_int(s) do
    case Integer.parse(s) do
      {n, ""} when n > 0 -> n
      _ -> nil
    end
  end

  @spec format_changeset(Ecto.Changeset.t()) :: map()
  defp format_changeset(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
