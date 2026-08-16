defmodule CanopyWeb.ProjectsController do
  @moduledoc """
  HTTP API for Projects.

  Routes:
    GET    /api/v1/projects               — list with filters (workspace_slug, status)
    POST   /api/v1/projects               — create
    GET    /api/v1/projects/:slug         — get by slug
    PATCH  /api/v1/projects/:slug         — update
    POST   /api/v1/projects/:slug/archive — archive
    POST   /api/v1/projects/:slug/unarchive — restore
    DELETE /api/v1/projects/:slug         — delete (dissociates work items)
    GET    /api/v1/projects/:slug/summary — aggregated counts
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Projects
  alias CanopyWeb.Schemas.ProjectsSchema

  action_fallback CanopyWeb.FallbackController

  tags ["projects"]

  operation :index,
    summary: "List projects",
    parameters: [
      workspace_slug: [in: :query, type: :string, required: false],
      status: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Project list", "application/json", ProjectsSchema.ProjectList}]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    filters =
      %{}
      |> maybe_put(:workspace_slug, params["workspace_slug"])
      |> maybe_put(:status, params["status"])
      |> maybe_put(:limit, parse_int(params["limit"]))

    projects = Projects.list(filters)
    json(conn, %{data: projects, count: length(projects)})
  end

  operation :create,
    summary: "Create a project",
    request_body: {"Project params", "application/json", ProjectsSchema.CreateProjectRequest},
    responses: [
      created: {"Project created", "application/json", ProjectsSchema.ProjectDetail},
      unprocessable_entity: {"Validation error", "application/json", ProjectsSchema.ErrorResponse}
    ]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    case Projects.create(params) do
      {:ok, project} -> conn |> put_status(:created) |> json(%{data: project})
      {:error, changeset} -> {:error, changeset}
    end
  end

  operation :show,
    summary: "Get a project by slug",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Project", "application/json", ProjectsSchema.ProjectDetail},
      not_found: {"Not found", "application/json", ProjectsSchema.ErrorResponse}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"slug" => slug}) do
    with {:ok, project} <- Projects.get(slug) do
      json(conn, %{data: project})
    end
  end

  operation :update,
    summary: "Update a project",
    parameters: [slug: [in: :path, type: :string, required: true]],
    request_body: {"Update params", "application/json", ProjectsSchema.UpdateProjectRequest},
    responses: [
      ok: {"Updated project", "application/json", ProjectsSchema.ProjectDetail},
      not_found: {"Not found", "application/json", ProjectsSchema.ErrorResponse},
      unprocessable_entity: {"Validation error", "application/json", ProjectsSchema.ErrorResponse}
    ]

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"slug" => slug} = params) do
    case Projects.update(slug, params) do
      {:ok, project} -> json(conn, %{data: project})
      {:error, :not_found} -> {:error, :not_found}
      {:error, changeset} -> {:error, changeset}
    end
  end

  operation :archive,
    summary: "Archive a project",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Archived project", "application/json", ProjectsSchema.ProjectDetail},
      not_found: {"Not found", "application/json", ProjectsSchema.ErrorResponse}
    ]

  @spec archive(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def archive(conn, %{"slug" => slug}) do
    case Projects.archive(slug) do
      {:ok, project} -> json(conn, %{data: project})
      error -> error
    end
  end

  operation :unarchive,
    summary: "Restore an archived project",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Restored project", "application/json", ProjectsSchema.ProjectDetail},
      not_found: {"Not found", "application/json", ProjectsSchema.ErrorResponse}
    ]

  @spec unarchive(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def unarchive(conn, %{"slug" => slug}) do
    case Projects.unarchive(slug) do
      {:ok, project} -> json(conn, %{data: project})
      error -> error
    end
  end

  operation :delete,
    summary: "Delete a project (dissociates work items)",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [
      no_content: "Deleted",
      not_found: {"Not found", "application/json", ProjectsSchema.ErrorResponse}
    ]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"slug" => slug}) do
    case Projects.delete(slug) do
      :ok -> send_resp(conn, :no_content, "")
      error -> error
    end
  end

  operation :summary,
    summary: "Aggregated activity counts for a project",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Project summary", "application/json", ProjectsSchema.ProjectSummary},
      not_found: {"Not found", "application/json", ProjectsSchema.ErrorResponse}
    ]

  @spec summary(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def summary(conn, %{"slug" => slug}) do
    with {:ok, data} <- Projects.get_summary(slug) do
      json(conn, %{data: data})
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

  defp parse_int(nil), do: nil

  defp parse_int(s) do
    case Integer.parse(s) do
      {n, ""} when n > 0 -> n
      _ -> nil
    end
  end
end
