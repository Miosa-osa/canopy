defmodule CanopyWeb.FallbackController do
  @moduledoc """
  Phoenix fallback controller for unified JSON error responses.

  Mounted via `action_fallback CanopyWeb.FallbackController` in controllers.
  Converts tagged error tuples from the domain layer into consistent JSON error
  responses with appropriate HTTP status codes.

  Handled errors:
  - `{:error, :not_found}` → 404
  - `{:error, :not_implemented}` → 501
  - `{:error, %Ecto.Changeset{}}` → 422
  - `{:error, :unauthorized}` → 401
  - `{:error, :forbidden}` → 403
  - `{:error, atom}` → 500 (catch-all)

  Add new clauses here as new domain error types are introduced in Week 1+.
  """

  use CanopyWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: CanopyWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :not_implemented}) do
    conn
    |> put_status(:not_implemented)
    |> json(%{error: "not_implemented", message: "This endpoint is not yet implemented."})
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: CanopyWeb.ErrorJSON)
    |> render(:"422", changeset: changeset)
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "unauthorized", message: "Authentication required."})
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "forbidden", message: "You do not have permission to perform this action."})
  end

  def call(conn, {:error, reason}) when is_atom(reason) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{error: to_string(reason), message: "An unexpected error occurred."})
  end
end
