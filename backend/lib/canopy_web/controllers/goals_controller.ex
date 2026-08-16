defmodule CanopyWeb.GoalsController do
  @moduledoc """
  HTTP API for orchestrator goals.

  Routes:
    GET    /api/v1/goals                — list with filters
    POST   /api/v1/goals                — create
    GET    /api/v1/goals/:id            — get by short_id or uuid
    PATCH  /api/v1/goals/:id            — update
    POST   /api/v1/goals/:id/progress   — update progress_pct
    POST   /api/v1/goals/:id/achieve    — mark achieved
    POST   /api/v1/goals/:id/cancel     — mark cancelled
    DELETE /api/v1/goals/:id            — hard delete
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Goals
  alias CanopyWeb.Schemas.GoalsSchema

  action_fallback CanopyWeb.FallbackController

  tags ["goals"]

  operation :index,
    summary: "List goals",
    parameters: [
      status: [in: :query, type: :string, required: false],
      workspace_slug: [in: :query, type: :string, required: false],
      owner_id: [in: :query, type: :string, required: false],
      owner_type: [in: :query, type: :string, required: false],
      q: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Goal list", "application/json", GoalsSchema.GoalList}]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    filters =
      %{}
      |> maybe_put(:status, params["status"])
      |> maybe_put(:workspace_slug, params["workspace_slug"])
      |> maybe_put(:owner_type, params["owner_type"])
      |> maybe_put(:owner_id, params["owner_id"])
      |> maybe_put(:q, params["q"])
      |> maybe_put(:limit, parse_int(params["limit"]))

    goals = Goals.list(filters)
    json(conn, %{data: goals, count: length(goals)})
  end

  operation :create,
    summary: "Create a goal",
    request_body: {"Goal params", "application/json", GoalsSchema.CreateGoalRequest},
    responses: [
      created: {"Goal created", "application/json", GoalsSchema.GoalDetail},
      unprocessable_entity: {"Validation error", "application/json", GoalsSchema.ErrorResponse}
    ]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    case Goals.create(params) do
      {:ok, goal} -> conn |> put_status(:created) |> json(%{data: goal})
      {:error, changeset} -> {:error, changeset}
    end
  end

  operation :show,
    summary: "Get a goal by short_id or uuid",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Goal", "application/json", GoalsSchema.GoalDetail},
      not_found: {"Not found", "application/json", GoalsSchema.ErrorResponse}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    with {:ok, goal} <- Goals.get(id) do
      json(conn, %{data: goal})
    end
  end

  operation :update,
    summary: "Update a goal",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Update params", "application/json", GoalsSchema.UpdateGoalRequest},
    responses: [
      ok: {"Updated goal", "application/json", GoalsSchema.GoalDetail},
      not_found: {"Not found", "application/json", GoalsSchema.ErrorResponse},
      unprocessable_entity: {"Validation error", "application/json", GoalsSchema.ErrorResponse}
    ]

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    case Goals.update(id, params) do
      {:ok, goal} -> json(conn, %{data: goal})
      {:error, :not_found} -> {:error, :not_found}
      {:error, changeset} -> {:error, changeset}
    end
  end

  operation :progress,
    summary: "Set goal progress percentage",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Progress params", "application/json", GoalsSchema.SetProgressRequest},
    responses: [
      ok: {"Updated goal", "application/json", GoalsSchema.GoalDetail},
      not_found: {"Not found", "application/json", GoalsSchema.ErrorResponse},
      unprocessable_entity: {"Validation error", "application/json", GoalsSchema.ErrorResponse}
    ]

  @spec progress(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def progress(conn, %{"id" => id, "progress_pct" => pct}) when is_integer(pct) do
    case Goals.set_progress(id, pct) do
      {:ok, goal} -> json(conn, %{data: goal})
      error -> error
    end
  end

  def progress(conn, %{"id" => id, "progress_pct" => pct}) when is_binary(pct) do
    case Integer.parse(pct) do
      {n, ""} ->
        case Goals.set_progress(id, n) do
          {:ok, goal} -> json(conn, %{data: goal})
          error -> error
        end

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "invalid_param", message: "progress_pct must be an integer 0–100."})
    end
  end

  def progress(conn, _) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_params", message: "progress_pct is required."})
  end

  operation :achieve,
    summary: "Mark a goal as achieved",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Achieved goal", "application/json", GoalsSchema.GoalDetail},
      not_found: {"Not found", "application/json", GoalsSchema.ErrorResponse}
    ]

  @spec achieve(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def achieve(conn, %{"id" => id}) do
    case Goals.achieve(id) do
      {:ok, goal} -> json(conn, %{data: goal})
      error -> error
    end
  end

  operation :cancel,
    summary: "Cancel a goal",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Cancelled goal", "application/json", GoalsSchema.GoalDetail},
      not_found: {"Not found", "application/json", GoalsSchema.ErrorResponse}
    ]

  @spec cancel(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def cancel(conn, %{"id" => id}) do
    case Goals.cancel(id) do
      {:ok, goal} -> json(conn, %{data: goal})
      error -> error
    end
  end

  operation :delete,
    summary: "Hard-delete a goal",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      no_content: "Deleted",
      not_found: {"Not found", "application/json", GoalsSchema.ErrorResponse}
    ]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    case Goals.delete(id) do
      :ok -> send_resp(conn, :no_content, "")
      error -> error
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
