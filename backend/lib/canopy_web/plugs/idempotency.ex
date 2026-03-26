defmodule CanopyWeb.Plugs.Idempotency do
  @moduledoc """
  Idempotency plug using ETS cache.
  For mutating requests (POST, PATCH, PUT, DELETE), checks Idempotency-Key header.
  If a cached response exists for that key, returns it immediately.
  Otherwise, proceeds with the request and caches the response.
  """
  import Plug.Conn

  @table :canopy_idempotency_cache
  @ttl_seconds 86_400

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.method in ["POST", "PATCH", "PUT", "DELETE"] do
      case get_req_header(conn, "idempotency-key") do
        [key] when key != "" -> handle_idempotency(conn, key)
        _ -> conn
      end
    else
      conn
    end
  end

  defp handle_idempotency(conn, key) do
    user_id = conn.assigns[:current_user] && conn.assigns[:current_user].id
    cache_key = {user_id, key}

    case :ets.lookup(@table, cache_key) do
      [{^cache_key, {status, body, _timestamp}}] ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(status, body)
        |> halt()

      [] ->
        register_before_send(conn, fn conn ->
          if conn.status in 200..299 do
            body =
              if is_binary(conn.resp_body),
                do: conn.resp_body,
                else: IO.iodata_to_binary(conn.resp_body)

            :ets.insert(@table, {cache_key, {conn.status, body, System.system_time(:second)}})
          end

          conn
        end)
    end
  end

  @doc "Run expired entry cleanup. Called by Canopy.IdempotencyCleanup or manually."
  def cleanup_expired do
    cutoff = System.system_time(:second) - @ttl_seconds

    :ets.select_delete(@table, [
      {{:"$1", {:"$2", :"$3", :"$4"}}, [{:<, :"$4", cutoff}], [true]}
    ])
  rescue
    _ -> :ok
  end
end
