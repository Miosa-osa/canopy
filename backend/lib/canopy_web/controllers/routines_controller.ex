defmodule CanopyWeb.RoutinesController do
  @moduledoc """
  HTTP API for routines.

  Routes:
    GET    /api/v1/routines             — list with filters
    POST   /api/v1/routines             — create
    GET    /api/v1/routines/:id         — get by short_id or uuid
    PATCH  /api/v1/routines/:id         — update
    POST   /api/v1/routines/:id/enable  — enable
    POST   /api/v1/routines/:id/disable — disable
    POST   /api/v1/routines/:id/fire    — fire manually
    DELETE /api/v1/routines/:id         — hard delete
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Routines
  alias CanopyWeb.Schemas.RoutinesSchema

  action_fallback CanopyWeb.FallbackController

  tags ["routines"]

  operation :index,
    summary: "List routines",
    parameters: [
      workspace_slug: [in: :query, type: :string, required: false],
      enabled: [in: :query, type: :boolean, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Routine list", "application/json", RoutinesSchema.RoutineList}]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    filters =
      %{}
      |> maybe_put(:workspace_slug, params["workspace_slug"])
      |> maybe_put(:enabled, parse_bool(params["enabled"]))
      |> maybe_put(:limit, parse_int(params["limit"]))

    routines = Routines.list(filters)
    json(conn, %{data: routines, count: length(routines)})
  end

  operation :create,
    summary: "Create a routine",
    request_body: {"Routine params", "application/json", RoutinesSchema.CreateRoutineRequest},
    responses: [
      created: {"Routine created", "application/json", RoutinesSchema.RoutineDetail},
      unprocessable_entity: {"Validation error", "application/json", RoutinesSchema.ErrorResponse}
    ]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    case Routines.create(params) do
      {:ok, routine} -> conn |> put_status(:created) |> json(%{data: routine})
      {:error, changeset} -> {:error, changeset}
    end
  end

  operation :show,
    summary: "Get a routine by short_id or uuid",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Routine", "application/json", RoutinesSchema.RoutineDetail},
      not_found: {"Not found", "application/json", RoutinesSchema.ErrorResponse}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    with {:ok, routine} <- Routines.get(id) do
      json(conn, %{data: routine})
    end
  end

  operation :update,
    summary: "Update a routine",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Update params", "application/json", RoutinesSchema.UpdateRoutineRequest},
    responses: [
      ok: {"Updated routine", "application/json", RoutinesSchema.RoutineDetail},
      not_found: {"Not found", "application/json", RoutinesSchema.ErrorResponse},
      unprocessable_entity: {"Validation error", "application/json", RoutinesSchema.ErrorResponse}
    ]

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    case Routines.update(id, params) do
      {:ok, routine} -> json(conn, %{data: routine})
      {:error, :not_found} -> {:error, :not_found}
      {:error, changeset} -> {:error, changeset}
    end
  end

  operation :enable,
    summary: "Enable a routine",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Enabled routine", "application/json", RoutinesSchema.RoutineDetail},
      not_found: {"Not found", "application/json", RoutinesSchema.ErrorResponse}
    ]

  @spec enable(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def enable(conn, %{"id" => id}) do
    case Routines.enable(id) do
      {:ok, routine} -> json(conn, %{data: routine})
      error -> error
    end
  end

  operation :disable,
    summary: "Disable a routine",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Disabled routine", "application/json", RoutinesSchema.RoutineDetail},
      not_found: {"Not found", "application/json", RoutinesSchema.ErrorResponse}
    ]

  @spec disable(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def disable(conn, %{"id" => id}) do
    case Routines.disable(id) do
      {:ok, routine} -> json(conn, %{data: routine})
      error -> error
    end
  end

  operation :fire,
    summary: "Fire a routine manually",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Fire result", "application/json", RoutinesSchema.FireResponse},
      not_found: {"Not found", "application/json", RoutinesSchema.ErrorResponse},
      unprocessable_entity: {"Creation failed", "application/json", RoutinesSchema.ErrorResponse}
    ]

  @spec fire(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def fire(conn, %{"id" => id}) do
    case Routines.fire(id) do
      {:ok, %{routine: routine, created: created}} ->
        json(conn, %{data: %{routine: routine, created: created}})

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  operation :delete,
    summary: "Hard-delete a routine",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      no_content: "Deleted",
      not_found: {"Not found", "application/json", RoutinesSchema.ErrorResponse}
    ]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    case Routines.delete(id) do
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

  defp parse_bool(nil), do: nil
  defp parse_bool("true"), do: true
  defp parse_bool("false"), do: false
  defp parse_bool(_), do: nil
end
