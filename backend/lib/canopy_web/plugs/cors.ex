defmodule CanopyWeb.Plugs.CORS do
  @moduledoc """
  CORS plug for the Canopy API.

  Allowed origins are configurable via the :canopy, :cors_origins application env.
  Defaults to localhost development ports. In production, set to your actual domain.
  """
  import Plug.Conn

  @default_origins [
    "http://localhost:5200",
    "http://localhost:8089",
    "http://127.0.0.1:5200",
    "http://127.0.0.1:8089",
    "tauri://localhost"
  ]

  def init(opts), do: opts

  def call(%{method: "OPTIONS"} = conn, _opts) do
    conn
    |> put_cors_headers()
    |> send_resp(204, "")
    |> halt()
  end

  def call(conn, _opts) do
    put_cors_headers(conn)
  end

  defp put_cors_headers(conn) do
    origin = get_req_header(conn, "origin") |> List.first()
    allowed_origins = Application.get_env(:canopy, :cors_origins, @default_origins)

    allow_origin =
      cond do
        origin in allowed_origins -> origin
        "*" in allowed_origins -> "*"
        true -> List.first(allowed_origins) || "http://localhost:5200"
      end

    conn
    |> put_resp_header("access-control-allow-origin", allow_origin)
    |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
    |> put_resp_header(
      "access-control-allow-headers",
      "authorization, content-type, accept, cache-control, x-accel-buffering, idempotency-key"
    )
    |> put_resp_header("access-control-max-age", "86400")
    |> put_resp_header("vary", "Origin")
  end
end
