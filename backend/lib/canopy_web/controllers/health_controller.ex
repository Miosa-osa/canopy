defmodule CanopyWeb.HealthController do
  @moduledoc """
  Health check endpoint for Canopy.

  Used by load balancers, Tauri app startup checks, and CI smoke tests to
  verify the backend is responding. Returns the application version from mix.exs
  so clients can verify they are talking to the expected release.
  """

  use CanopyWeb, :controller

  action_fallback CanopyWeb.FallbackController

  @doc "GET /api/v1/health — returns status and version."
  def index(conn, _params) do
    json(conn, %{
      status: "ok",
      version: Application.spec(:canopy, :vsn) |> to_string()
    })
  end
end
