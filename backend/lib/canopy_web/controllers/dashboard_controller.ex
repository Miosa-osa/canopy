defmodule CanopyWeb.DashboardController do
  @moduledoc """
  HTTP API for the Canopy Command Center dashboard.

  Routes:
    GET /api/v1/dashboard/summary — active_agents, spend_this_month, recent_sessions
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Dashboard
  alias CanopyWeb.Schemas.DashboardSchema

  action_fallback CanopyWeb.FallbackController

  tags ["dashboard"]

  # ---------------------------------------------------------------------------
  # GET /api/v1/dashboard/summary
  # ---------------------------------------------------------------------------

  operation :summary,
    summary: "Dashboard summary",
    description: "Returns active_agents, spend_this_month, and recent_sessions in one response.",
    responses: [
      ok: {"Dashboard summary", "application/json", DashboardSchema.SummaryResponse}
    ]

  @spec summary(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def summary(conn, _params) do
    json(conn, Dashboard.summary())
  end
end
