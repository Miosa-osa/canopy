defmodule CanopyWeb.Plugs.RateLimiterTest do
  use CanopyWeb.ConnCase

  setup do
    # Re-enable rate limiter for these specific tests
    prev = Application.get_env(:canopy, :disable_rate_limiter, false)
    Application.put_env(:canopy, :disable_rate_limiter, false)
    on_exit(fn -> Application.put_env(:canopy, :disable_rate_limiter, prev) end)
    :ok
  end

  test "GET /health returns rate limit headers", %{conn: conn} do
    conn = get(conn, "/api/v1/health")

    assert conn.status == 200
    assert get_resp_header(conn, "x-ratelimit-limit") != []
    assert get_resp_header(conn, "x-ratelimit-remaining") != []
  end

  test "rate limit headers include numeric values", %{conn: conn} do
    conn = get(conn, "/api/v1/health")

    [limit] = get_resp_header(conn, "x-ratelimit-limit")
    [remaining] = get_resp_header(conn, "x-ratelimit-remaining")

    assert String.to_integer(limit) > 0
    assert String.to_integer(remaining) >= 0
  end
end
