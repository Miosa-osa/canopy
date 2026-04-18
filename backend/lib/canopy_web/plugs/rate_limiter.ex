defmodule CanopyWeb.Plugs.RateLimiter do
  @moduledoc """
  IP-based rate limiter using Hammer's ETS backend.

  Applied to the `:api` pipeline. Buckets requests by client IP, respecting the
  `X-Forwarded-For` header when present (first IP in the chain = original client).

  Default: 100 requests per 60-second window per IP.

  Configuration (application env under `:canopy`, `CanopyWeb.Plugs.RateLimiter`):
    - `enabled` — set to `false` in test env to bypass all limit checks.

  Router plug signature (merge into `:api` pipeline):

      plug CanopyWeb.Plugs.RateLimiter,
        scale_ms: 60_000,
        limit: Application.compile_env(:canopy, [CanopyWeb.Plugs.RateLimiter, :limit], 100),
        enabled: Application.compile_env(:canopy, [CanopyWeb.Plugs.RateLimiter, :enabled], true)

  Exceeded requests receive `429 Too Many Requests` with a `Retry-After` header
  (seconds until the current window expires).
  """

  import Plug.Conn

  require Logger

  @default_scale_ms 60_000
  @default_limit 100

  @type opts :: %{
          scale_ms: pos_integer(),
          limit: pos_integer(),
          enabled: boolean()
        }

  @spec init(keyword()) :: opts()
  def init(opts) do
    %{
      scale_ms: Keyword.get(opts, :scale_ms, @default_scale_ms),
      limit: Keyword.get(opts, :limit, @default_limit),
      enabled: Keyword.get(opts, :enabled, true)
    }
  end

  @spec call(Plug.Conn.t(), opts()) :: Plug.Conn.t()
  def call(conn, %{enabled: false}), do: conn

  def call(conn, %{scale_ms: scale_ms, limit: limit}) do
    bucket = "api:#{client_ip(conn)}"

    case Hammer.check_rate(bucket, scale_ms, limit) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        retry_after = div(scale_ms, 1_000)

        Logger.warning("Rate limit exceeded",
          ip: client_ip(conn),
          path: conn.request_path
        )

        body =
          Jason.encode!(%{
            error: "rate_limited",
            message: "Too many requests. Try again later."
          })

        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("retry-after", Integer.to_string(retry_after))
        |> send_resp(429, body)
        |> halt()
    end
  end

  @spec client_ip(Plug.Conn.t()) :: String.t()
  defp client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _rest] ->
        forwarded
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end
end
