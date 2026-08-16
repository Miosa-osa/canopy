defmodule CanopyWeb.WorkspacesController do
  @moduledoc """
  HTTP API for Canopy workspace management.

  Routes:
    GET    /api/v1/workspaces            — list all workspaces (not soft-deleted)
    GET    /api/v1/workspaces/templates  — list available starter templates
    GET    /api/v1/workspaces/:slug      — get a single workspace by slug
    POST   /api/v1/workspaces            — create workspace (optionally from template)
    PATCH  /api/v1/workspaces/:slug      — update workspace name / root_path
    DELETE /api/v1/workspaces/:slug      — soft-delete a workspace
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Workspaces
  alias CanopyWeb.Schemas.WorkspaceSchema

  action_fallback CanopyWeb.FallbackController

  tags ["workspaces"]

  operation :index,
    summary: "List workspaces",
    description: "Returns all workspaces that have not been soft-deleted.",
    responses: [
      ok: {"Workspace list", "application/json", WorkspaceSchema.WorkspaceList}
    ]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    {:ok, workspaces} = Workspaces.list()
    json(conn, %{data: workspaces})
  end

  operation :templates,
    summary: "List workspace templates",
    description: "Returns the 4 built-in starter workspace templates.",
    responses: [
      ok: {"Template list", "application/json", WorkspaceSchema.TemplateList}
    ]

  @spec templates(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def templates(conn, _params) do
    templates = Workspaces.list_templates()
    json(conn, %{data: templates})
  end

  operation :show,
    summary: "Get workspace by slug",
    description: "Returns a single workspace.",
    parameters: [
      slug: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Workspace", "application/json", WorkspaceSchema.WorkspaceDetail},
      not_found: {"Not found", "application/json", WorkspaceSchema.ErrorResponse}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"slug" => slug}) do
    with {:ok, workspace} <- Workspaces.get_by_slug(slug) do
      json(conn, %{data: workspace})
    end
  end

  operation :create,
    summary: "Create a workspace",
    description:
      "Creates a workspace DB record and initialises the filesystem root. " <>
        "If `template_slug` is provided, materialises template files on disk.",
    request_body:
      {"Workspace creation params", "application/json", WorkspaceSchema.CreateWorkspaceRequest},
    responses: [
      created: {"Workspace created", "application/json", WorkspaceSchema.WorkspaceDetail},
      unprocessable_entity:
        {"Validation error", "application/json", WorkspaceSchema.ErrorResponse}
    ]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    result =
      case params["template_slug"] do
        nil ->
          Workspaces.create(%{
            slug: params["slug"],
            name: params["name"],
            root_path: params["root_path"],
            description: params["description"],
            template: params["template"]
          })

        template_slug ->
          Workspaces.create_from_template(
            params["slug"],
            template_slug,
            params["root_path"]
          )
      end

    case result do
      {:ok, workspace} ->
        conn
        |> put_status(:created)
        |> json(%{data: workspace})

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, :unknown_template} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "unknown_template",
          message: "Template '#{params["template_slug"]}' does not exist."
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "create_failed", message: inspect(reason)})
    end
  end

  operation :update,
    summary: "Update a workspace",
    description:
      "Updates mutable fields on an existing workspace: `name` and/or `root_path`. " <>
        "`root_path`, when supplied, must be an absolute path that exists on disk.",
    parameters: [
      slug: [in: :path, type: :string, required: true]
    ],
    request_body:
      {"Workspace update params", "application/json", WorkspaceSchema.UpdateWorkspaceRequest},
    responses: [
      ok: {"Workspace updated", "application/json", WorkspaceSchema.WorkspaceDetail},
      not_found: {"Not found", "application/json", WorkspaceSchema.ErrorResponse},
      unprocessable_entity:
        {"Validation error", "application/json", WorkspaceSchema.ErrorResponse}
    ]

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"slug" => slug} = params) do
    attrs = Map.take(params, ["name", "root_path"])

    case Workspaces.update_workspace(slug, attrs) do
      {:ok, workspace} ->
        json(conn, %{data: workspace})

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, :root_path_not_found} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "root_path_not_found",
          message: "The path '#{params["root_path"]}' does not exist or is not a directory."
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  operation :delete,
    summary: "Soft-delete a workspace",
    description: "Marks the workspace as deleted. Does not mutate the filesystem.",
    parameters: [
      slug: [in: :path, type: :string, required: true]
    ],
    responses: [
      no_content: "Workspace deleted",
      not_found: {"Not found", "application/json", WorkspaceSchema.ErrorResponse}
    ]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"slug" => slug}) do
    with {:ok, _workspace} <- Workspaces.delete(slug) do
      send_resp(conn, :no_content, "")
    end
  end

  operation :detect,
    summary: "Re-run stack detection and rules scan",
    description:
      "Re-runs stack auto-detection and project rules scanning on the workspace root, " <>
        "updating `config.detected_stack` and `config.project_rules`.",
    parameters: [
      slug: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Updated workspace", "application/json", WorkspaceSchema.WorkspaceDetail},
      not_found: {"Not found", "application/json", WorkspaceSchema.ErrorResponse}
    ]

  @spec detect(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def detect(conn, %{"slug" => slug}) do
    with {:ok, workspace} <- Workspaces.detect_and_update(slug) do
      json(conn, %{data: workspace})
    end
  end
end
