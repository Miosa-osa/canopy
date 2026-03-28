defmodule CanopyWeb.Plugs.RateLimiter do
  @moduledoc """
  Token-bucket rate limiter using ETS.

  Limits requests per IP (or per user for authenticated routes).
  Default: 120 requests per minute for API, 10 per minute for auth endpoints.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @table :canopy_rate_limiter
  @default_limit 120
  @default_window_ms 60_000
  @auth_limit 10

  def init(opts), do: opts

  def call(conn, opts) do
    if opts[:disabled] || Application.get_env(:canopy, :disable_rate_limiter, false) do
      conn
    else
      do_rate_limit(conn, opts)
    end
  end

  defp do_rate_limit(conn, opts) do
    limit = opts[:limit] || rate_limit_for(conn)
    window_ms = opts[:window_ms] || @default_window_ms
    key = bucket_key(conn)

    case check_rate(key, limit, window_ms) do
      {:ok, remaining} ->
        conn
        |> put_resp_header("x-ratelimit-limit", to_string(limit))
        |> put_resp_header("x-ratelimit-remaining", to_string(remaining))

      {:error, retry_after_ms} ->
        retry_after = max(1, div(retry_after_ms, 1000))

        conn
        |> put_resp_header("x-ratelimit-limit", to_string(limit))
        |> put_resp_header("x-ratelimit-remaining", "0")
        |> put_resp_header("retry-after", to_string(retry_after))
        |> put_status(429)
        |> json(%{error: "rate_limited", message: "Too many requests", retry_after: retry_after})
        |> halt()
    end
  end

  defp bucket_key(conn) do
    identifier =
      case conn.assigns[:current_user] do
        %{id: user_id} -> "user:#{user_id}"
        _ -> "ip:#{format_ip(conn.remote_ip)}"
      end

    path_prefix =
      case conn.path_info do
        ["api", "v1", "auth" | _] -> "auth"
        ["api", "v1", resource | _] -> resource
        _ -> "global"
      end

    "#{identifier}:#{path_prefix}"
  end

  defp rate_limit_for(conn) do
    case conn.path_info do
      ["api", "v1", "auth" | _] -> @auth_limit
      _ -> @default_limit
    end
  end

  defp check_rate(key, limit, window_ms) do
    now = System.monotonic_time(:millisecond)
    window_start = now - window_ms

    # Clean old entries and count current
    :ets.select_delete(@table, [
      {{key, :"$1"}, [{:<, :"$1", window_start}], [true]}
    ])

    count = :ets.select_count(@table, [{{key, :"$1"}, [], [true]}])

    if count < limit do
      :ets.insert(@table, {key, now})
      {:ok, limit - count - 1}
    else
      # Find oldest entry in window to calculate retry-after
      oldest =
        case :ets.select(@table, [{{key, :"$1"}, [], [:"$1"]}]) do
          [first | _] -> first
          [] -> now
        end

      {:error, oldest + window_ms - now}
    end
  rescue
    _ -> {:ok, limit}
  end

  defp format_ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
  defp format_ip(ip), do: to_string(:inet.ntoa(ip))
end
