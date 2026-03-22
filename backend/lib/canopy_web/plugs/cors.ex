defmodule CanopyWeb.Plugs.CORS do
  @moduledoc "CORS plug for the Canopy API."
  import Plug.Conn

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
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
    |> put_resp_header(
      "access-control-allow-headers",
      "authorization, content-type, accept, cache-control, x-accel-buffering, idempotency-key"
    )
    |> put_resp_header("access-control-max-age", "86400")
  end
end
