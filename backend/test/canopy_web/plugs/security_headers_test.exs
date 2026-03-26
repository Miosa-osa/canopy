defmodule CanopyWeb.Plugs.SecurityHeadersTest do
  use CanopyWeb.ConnCase

  test "GET /health returns OWASP security headers", %{conn: conn} do
    conn = get(conn, "/api/v1/health")

    assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    assert get_resp_header(conn, "x-frame-options") == ["DENY"]
    assert get_resp_header(conn, "x-xss-protection") == ["0"]
    assert get_resp_header(conn, "strict-transport-security") == ["max-age=31536000; includeSubDomains"]
    assert get_resp_header(conn, "referrer-policy") == ["strict-origin-when-cross-origin"]
    assert get_resp_header(conn, "permissions-policy") == ["camera=(), microphone=(), geolocation=()"]
    assert get_resp_header(conn, "content-security-policy") == ["default-src 'none'; frame-ancestors 'none'"]
  end
end
