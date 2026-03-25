defmodule CanopyWeb.AdapterController do
  use CanopyWeb, :controller

  @doc "GET /api/v1/adapters — list all adapters with health status."
  def index(conn, _params) do
    adapters =
      Canopy.Adapter.health_all()
      |> Enum.map(fn adapter ->
        health =
          case adapter.health do
            :ok -> %{status: "ok"}
            {:error, reason} -> %{status: "error", reason: reason}
          end

        %{
          type: adapter.type,
          name: adapter.name,
          supports_session: adapter.supports_session,
          supports_concurrent: adapter.supports_concurrent,
          capabilities: adapter.capabilities,
          health: health
        }
      end)

    json(conn, %{adapters: adapters})
  end
end
