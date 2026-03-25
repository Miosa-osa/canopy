defmodule CanopyWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Adds OWASP-recommended security headers to all API responses.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-xss-protection", "0")
    |> put_resp_header("strict-transport-security", "max-age=31536000; includeSubDomains")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", "camera=(), microphone=(), geolocation=()")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'none'; frame-ancestors 'none'"
    )
  end
end
