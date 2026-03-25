defmodule CanopyWeb.Plugs.CORSTest do
  use CanopyWeb.ConnCase

  test "OPTIONS preflight returns 204 with CORS headers", %{conn: conn} do
    conn =
      conn
      |> put_req_header("origin", "http://localhost:5200")
      |> put_req_header("access-control-request-method", "POST")
      |> options("/api/v1/health")

    assert conn.status == 204
    assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:5200"]
    assert get_resp_header(conn, "access-control-allow-methods") != []
    assert get_resp_header(conn, "vary") == ["Origin"]
  end

  test "allowed origin is echoed back", %{conn: conn} do
    conn =
      conn
      |> put_req_header("origin", "http://localhost:5200")
      |> get("/api/v1/health")

    assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:5200"]
  end

  test "disallowed origin gets default fallback", %{conn: conn} do
    conn =
      conn
      |> put_req_header("origin", "http://evil.com")
      |> get("/api/v1/health")

    [origin] = get_resp_header(conn, "access-control-allow-origin")
    # Should NOT echo back evil.com
    refute origin == "http://evil.com"
  end

  test "Vary: Origin header is always set", %{conn: conn} do
    conn = get(conn, "/api/v1/health")
    assert get_resp_header(conn, "vary") == ["Origin"]
  end
end
