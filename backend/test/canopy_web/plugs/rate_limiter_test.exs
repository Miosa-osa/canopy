defmodule CanopyWeb.Plugs.RateLimiterTest do
  use CanopyWeb.ConnCase, async: false

  alias CanopyWeb.Plugs.RateLimiter

  # async: false because Hammer's ETS store is shared global state.
  # Each test uses a unique IP so Hammer buckets never bleed between tests.

  describe "init/1" do
    test "uses defaults when no opts given" do
      opts = RateLimiter.init([])
      assert opts.scale_ms == 60_000
      assert opts.limit == 100
      assert opts.enabled == true
    end

    test "accepts custom opts" do
      opts = RateLimiter.init(scale_ms: 5_000, limit: 10, enabled: false)
      assert opts.scale_ms == 5_000
      assert opts.limit == 10
      assert opts.enabled == false
    end
  end

  describe "call/2 with enabled: false" do
    test "passes conn through unconditionally regardless of limit" do
      conn = build_conn({203, 0, 113, 1})
      # limit: 0 would deny every request if enabled
      opts = RateLimiter.init(enabled: false, limit: 0)

      result = RateLimiter.call(conn, opts)

      refute result.halted
    end
  end

  describe "call/2 within limit" do
    test "allows request and does not halt conn" do
      conn = build_conn({203, 0, 113, 10})
      opts = RateLimiter.init(scale_ms: 60_000, limit: 100, enabled: true)

      result = RateLimiter.call(conn, opts)

      refute result.halted
    end
  end

  describe "call/2 over limit" do
    test "returns 429 with retry-after header when limit exceeded" do
      ip = {203, 0, 113, 20}
      opts = RateLimiter.init(scale_ms: 60_000, limit: 3, enabled: true)

      # Exhaust the bucket: 3 allowed
      for _ <- 1..3 do
        result = RateLimiter.call(build_conn(ip), opts)
        refute result.halted
      end

      # 4th request — denied
      result = RateLimiter.call(build_conn(ip), opts)

      assert result.halted
      assert result.status == 429
      assert get_resp_header(result, "retry-after") == ["60"]
    end

    test "response body is machine-readable JSON with error code" do
      ip = {203, 0, 113, 21}
      opts = RateLimiter.init(scale_ms: 60_000, limit: 1, enabled: true)

      # Consume the bucket
      RateLimiter.call(build_conn(ip), opts)

      conn = RateLimiter.call(build_conn(ip), opts)

      assert conn.halted
      assert conn.status == 429
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "rate_limited"
      assert is_binary(body["message"])
    end

    test "response content-type is application/json" do
      ip = {203, 0, 113, 22}
      opts = RateLimiter.init(scale_ms: 60_000, limit: 1, enabled: true)

      RateLimiter.call(build_conn(ip), opts)
      conn = RateLimiter.call(build_conn(ip), opts)

      assert conn.halted
      [content_type | _] = get_resp_header(conn, "content-type")
      assert String.starts_with?(content_type, "application/json")
    end
  end

  describe "call/2 IP isolation" do
    test "different IPs are bucketed independently" do
      ip_a = {203, 0, 113, 30}
      ip_b = {203, 0, 113, 31}
      opts = RateLimiter.init(scale_ms: 60_000, limit: 1, enabled: true)

      # Exhaust ip_a's bucket
      RateLimiter.call(build_conn(ip_a), opts)
      denied = RateLimiter.call(build_conn(ip_a), opts)
      assert denied.halted

      # ip_b untouched — must still be allowed
      allowed = RateLimiter.call(build_conn(ip_b), opts)
      refute allowed.halted
    end
  end

  describe "call/2 x-forwarded-for" do
    test "uses first IP in x-forwarded-for chain as the bucket key" do
      original_ip = "203.0.113.40"
      opts = RateLimiter.init(scale_ms: 60_000, limit: 1, enabled: true)

      # First request through proxy 1 — consumes the bucket for original_ip
      conn_1 =
        build_conn({10, 0, 0, 1})
        |> Plug.Conn.put_req_header("x-forwarded-for", "#{original_ip}, 10.0.0.1")

      RateLimiter.call(conn_1, opts)

      # Same original_ip through a different proxy — must be denied
      conn_2 =
        build_conn({10, 0, 0, 2})
        |> Plug.Conn.put_req_header("x-forwarded-for", "#{original_ip}, 10.0.0.2")

      result = RateLimiter.call(conn_2, opts)
      assert result.halted
    end

    test "falls back to remote_ip when x-forwarded-for header is absent" do
      ip = {203, 0, 113, 50}
      opts = RateLimiter.init(scale_ms: 60_000, limit: 1, enabled: true)

      # Consume the bucket via remote_ip
      RateLimiter.call(build_conn(ip), opts)

      result = RateLimiter.call(build_conn(ip), opts)
      assert result.halted
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Builds a bare Plug.Conn with remote_ip set to the given 4-tuple.
  # No router/endpoint pipeline — the plug must work standalone.
  defp build_conn(remote_ip) when is_tuple(remote_ip) do
    Phoenix.ConnTest.build_conn()
    |> Map.put(:remote_ip, remote_ip)
    |> Plug.Conn.put_req_header("accept", "application/json")
  end
end
