defmodule CanopyWeb.MissionsController do
  @moduledoc """
  HTTP API for Missions and Milestones.

  Routes:
    GET    /api/v1/missions                              — list missions
    POST   /api/v1/missions                             — create mission
    GET    /api/v1/missions/:id                         — show with milestones
    PATCH  /api/v1/missions/:id                         — update mission
    POST   /api/v1/missions/:id/milestones              — add milestone
    POST   /api/v1/missions/:id/milestones/:mid/advance — advance milestone
    GET    /api/v1/orchestrator/status                  — dispatch queue status
    POST   /api/v1/orchestrator/dispatch                — manual dispatch trigger
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Missions
  alias Canopy.Orchestrator

  action_fallback CanopyWeb.FallbackController

  tags ["missions"]

  # ---------------------------------------------------------------------------
  # GET /missions
  # ---------------------------------------------------------------------------

  operation :index,
    summary: "List missions",
    parameters: [
      workspace_slug: [in: :query, type: :string, required: false],
      status: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Mission list", "application/json", %OpenApiSpex.Schema{type: :object}}]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    filters =
      %{}
      |> maybe_put(:workspace_slug, params["workspace_slug"])
      |> maybe_put(:status, params["status"])
      |> maybe_put(:limit, parse_int(params["limit"]))

    missions = Missions.list_missions(filters)
    json(conn, %{data: missions, count: length(missions)})
  end

  # ---------------------------------------------------------------------------
  # POST /missions
  # ---------------------------------------------------------------------------

  operation :create,
    summary: "Create a mission",
    request_body:
      {"Mission params", "application/json", %OpenApiSpex.Schema{type: :object}, required: true},
    responses: [
      created: {"Mission created", "application/json", %OpenApiSpex.Schema{type: :object}},
      unprocessable_entity: {"Validation error", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    case Missions.create_mission(params) do
      {:ok, mission} ->
        conn |> put_status(:created) |> json(%{data: mission})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # ---------------------------------------------------------------------------
  # GET /missions/:id
  # ---------------------------------------------------------------------------

  operation :show,
    summary: "Show a mission with its milestones",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Mission detail", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    with {:ok, mission} <- Missions.get_mission(id) do
      {:ok, progress} = Missions.mission_progress(id)
      json(conn, %{data: mission, progress: progress})
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /missions/:id
  # ---------------------------------------------------------------------------

  operation :update,
    summary: "Update a mission",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body:
      {"Update params", "application/json", %OpenApiSpex.Schema{type: :object}, required: true},
    responses: [
      ok: {"Updated mission", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}},
      unprocessable_entity: {"Validation error", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    with {:ok, mission} <- Missions.get_mission(id) do
      attrs = Map.drop(params, ["id"])

      case mission
           |> Canopy.Missions.Mission.changeset(attrs)
           |> Canopy.Repo.update() do
        {:ok, updated} -> json(conn, %{data: updated})
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /missions/:id/milestones
  # ---------------------------------------------------------------------------

  operation :add_milestone,
    summary: "Add a milestone to a mission",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body:
      {"Milestone params", "application/json", %OpenApiSpex.Schema{type: :object},
       required: true},
    responses: [
      created: {"Milestone created", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Mission not found", "application/json", %OpenApiSpex.Schema{type: :object}},
      unprocessable_entity: {"Validation error", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec add_milestone(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def add_milestone(conn, %{"id" => mission_id} = params) do
    attrs = Map.drop(params, ["id"])

    case Missions.add_milestone(mission_id, attrs) do
      {:ok, milestone} ->
        conn |> put_status(:created) |> json(%{data: milestone})

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # ---------------------------------------------------------------------------
  # POST /missions/:id/milestones/:mid/advance
  # ---------------------------------------------------------------------------

  operation :advance_milestone,
    summary: "Advance a milestone (check deps + run validation + complete)",
    parameters: [
      id: [in: :path, type: :string, required: true],
      mid: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Milestone advanced", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}},
      unprocessable_entity: {"Deps not met or validation failed", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec advance_milestone(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def advance_milestone(conn, %{"id" => _mission_id, "mid" => milestone_id}) do
    case Missions.advance_milestone(milestone_id) do
      {:ok, milestone} ->
        json(conn, %{data: milestone})

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, :deps_not_met} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "deps_not_met", message: "Blocking dependencies are not yet completed"})

      {:error, :validation_failed, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "validation_failed", message: reason})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # ---------------------------------------------------------------------------
  # GET /orchestrator/status
  # ---------------------------------------------------------------------------

  tags ["orchestrator"]

  operation :orchestrator_status,
    summary: "Orchestrator dispatch queue snapshot",
    responses: [ok: {"Status", "application/json", %OpenApiSpex.Schema{type: :object}}]

  @spec orchestrator_status(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def orchestrator_status(conn, _params) do
    json(conn, %{data: Orchestrator.status()})
  end

  # ---------------------------------------------------------------------------
  # POST /orchestrator/dispatch
  # ---------------------------------------------------------------------------

  operation :orchestrator_dispatch,
    summary: "Manually trigger an orchestrator dispatch sweep",
    responses: [ok: {"Dispatch result", "application/json", %OpenApiSpex.Schema{type: :object}}]

  @spec orchestrator_dispatch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def orchestrator_dispatch(conn, _params) do
    result = Orchestrator.auto_dispatch()
    json(conn, %{data: result})
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

  defp parse_int(nil), do: nil

  defp parse_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, ""} when n > 0 -> n
      _ -> nil
    end
  end

  defp parse_int(_), do: nil
end
