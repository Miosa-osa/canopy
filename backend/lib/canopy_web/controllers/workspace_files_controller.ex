defmodule CanopyWeb.WorkspaceFilesController do
  @moduledoc """
  HTTP API for workspace filesystem operations.

  All paths are validated against the workspace root — directory traversal
  attempts receive 400 Bad Request.

  Routes:
    GET    /api/v1/workspaces/:slug/tree          — full nested file tree
    GET    /api/v1/workspaces/:slug/files         — list_dir (pass ?path= for subdir)
    GET    /api/v1/workspaces/:slug/files/*path   — read a file
    PUT    /api/v1/workspaces/:slug/files/*path   — write a file
    DELETE /api/v1/workspaces/:slug/files/*path   — delete a file
    POST   /api/v1/workspaces/:slug/files/move    — move/rename a file
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Workspaces
  alias Canopy.Workspaces.{Files, Tree}

  action_fallback CanopyWeb.FallbackController

  tags ["workspace-files"]

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces/:slug/tree
  # ---------------------------------------------------------------------------

  operation :tree,
    summary: "Get workspace file tree",
    description: "Returns the full nested file tree for the workspace.",
    parameters: [
      slug: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"File tree", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec tree(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def tree(conn, %{"slug" => slug}) do
    with {:ok, workspace} <- Workspaces.get_by_slug(slug),
         {:ok, file_tree} <- Tree.build(workspace) do
      json(conn, %{data: file_tree})
    else
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces/:slug/files?path=<rel>
  # ---------------------------------------------------------------------------

  operation :list_dir,
    summary: "List directory entries",
    description:
      "Lists the immediate contents of a directory inside the workspace. " <>
        "Pass `?path=subdir` to list a subdirectory; omit for workspace root.",
    parameters: [
      slug: [in: :path, type: :string, required: true],
      path: [in: :query, type: :string, required: false]
    ],
    responses: [
      ok: {"Directory listing", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request:
        {"Path traversal rejected", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec list_dir(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_dir(conn, %{"slug" => slug} = params) do
    rel_path = params["path"] || ""

    with {:ok, workspace} <- Workspaces.get_by_slug(slug) do
      case Files.list_dir(workspace, rel_path) do
        {:ok, entries} ->
          json(conn, %{data: entries, path: rel_path})

        {:error, :traversal} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "traversal_rejected", message: "Path traversal attempt rejected."})

        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "not_found", message: "Directory '#{rel_path}' not found."})

        {:error, reason} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "filesystem_error", message: inspect(reason)})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces/:slug/files/*path
  # ---------------------------------------------------------------------------

  operation :read,
    summary: "Read a file",
    description: "Returns the UTF-8 content of a file inside the workspace.",
    parameters: [
      slug: [in: :path, type: :string, required: true],
      path: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"File content", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request:
        {"Path traversal or oversized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec read(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def read(conn, %{"slug" => slug, "path" => path_segments}) do
    rel_path = join_path_segments(path_segments)

    with {:ok, workspace} <- Workspaces.get_by_slug(slug) do
      case Files.read_file(workspace, rel_path) do
        {:ok, content} ->
          json(conn, %{path: rel_path, content: content})

        {:error, :traversal} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "traversal_rejected", message: "Path traversal attempt rejected."})

        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "not_found", message: "File '#{rel_path}' not found."})

        {:error, :too_large} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "too_large", message: "File '#{rel_path}' exceeds 10MB limit."})

        {:error, :not_utf8} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "not_utf8", message: "File '#{rel_path}' is not valid UTF-8."})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /api/v1/workspaces/:slug/files/*path
  # ---------------------------------------------------------------------------

  operation :write,
    summary: "Write a file",
    description:
      "Writes content to a file inside the workspace. Creates parent directories " <>
        "as needed. Write is atomic (tmp + rename).",
    parameters: [
      slug: [in: :path, type: :string, required: true],
      path: [in: :path, type: :string, required: true]
    ],
    request_body: {"File content", "application/json", %OpenApiSpex.Schema{type: :object}},
    responses: [
      ok: {"File written", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request:
        {"Path traversal rejected", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec write(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def write(conn, %{"slug" => slug, "path" => path_segments} = params) do
    rel_path = join_path_segments(path_segments)
    content = params["content"] || ""

    with {:ok, workspace} <- Workspaces.get_by_slug(slug) do
      case Files.write_file(workspace, rel_path, content) do
        :ok ->
          # Fire-and-forget: update the file DB index after a successful write.
          # If the workspace_id lookup fails (workspace not yet in DB or not indexed),
          # the index operation fails silently — it never blocks the write response.
          Task.start(fn ->
            Canopy.Files.index_file(workspace.id, rel_path, %{actor: %{type: "system", id: nil}})
          end)

          json(conn, %{path: rel_path, written: true})

        {:error, :traversal} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "traversal_rejected", message: "Path traversal attempt rejected."})

        {:error, reason} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "write_failed", message: inspect(reason)})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/workspaces/:slug/files/*path
  # ---------------------------------------------------------------------------

  operation :delete,
    summary: "Delete a file",
    description: "Deletes a file inside the workspace.",
    parameters: [
      slug: [in: :path, type: :string, required: true],
      path: [in: :path, type: :string, required: true]
    ],
    responses: [
      no_content: "File deleted",
      bad_request:
        {"Path traversal rejected", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"slug" => slug, "path" => path_segments}) do
    rel_path = join_path_segments(path_segments)

    with {:ok, workspace} <- Workspaces.get_by_slug(slug) do
      case Files.delete_file(workspace, rel_path) do
        :ok ->
          send_resp(conn, :no_content, "")

        {:error, :traversal} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "traversal_rejected", message: "Path traversal attempt rejected."})

        {:error, reason} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "delete_failed", message: inspect(reason)})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/workspaces/:slug/files/move
  # ---------------------------------------------------------------------------

  operation :move,
    summary: "Move or rename a file",
    description: "Moves a file from one relative path to another inside the workspace.",
    parameters: [
      slug: [in: :path, type: :string, required: true]
    ],
    request_body:
      {"Move params — {from: rel_path, to: rel_path}", "application/json",
       %OpenApiSpex.Schema{type: :object}},
    responses: [
      ok: {"File moved", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request:
        {"Path traversal or missing params", "application/json",
         %OpenApiSpex.Schema{type: :object}},
      not_found: {"Source not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec move(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def move(conn, %{"slug" => slug} = params) do
    from = params["from"]
    to = params["to"]

    if is_nil(from) or is_nil(to) or from == "" or to == "" do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "missing_params", message: "Both 'from' and 'to' are required."})
    else
      with {:ok, workspace} <- Workspaces.get_by_slug(slug) do
        case Files.move_file(workspace, from, to) do
          :ok ->
            json(conn, %{from: from, to: to, moved: true})

          {:error, :traversal} ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: "traversal_rejected", message: "Path traversal attempt rejected."})

          {:error, :not_found} ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "not_found", message: "Source file '#{from}' not found."})

          {:error, reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "move_failed", message: inspect(reason)})
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Phoenix captures wildcard path segments as a list ["a", "b", "c"].
  # Join them back into a relative path string.
  defp join_path_segments(segments) when is_list(segments), do: Enum.join(segments, "/")
  defp join_path_segments(segment) when is_binary(segment), do: segment
end
