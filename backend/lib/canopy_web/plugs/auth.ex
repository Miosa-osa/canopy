defmodule CanopyWeb.Plugs.Auth do
  @moduledoc "JWT authentication plug."
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    token = extract_token(conn)

    case token do
      nil ->
        conn
        |> put_status(401)
        |> json(%{error: "unauthorized", code: "INVALID_TOKEN"})
        |> halt()

      token ->
        with {:ok, claims} <- Canopy.Guardian.decode_and_verify(token),
             {:ok, user} <- Canopy.Guardian.resource_from_claims(claims) do
          conn
          |> assign(:current_user, user)
          |> assign(:claims, claims)
        else
          _ ->
            conn
            |> put_status(401)
            |> json(%{error: "unauthorized", code: "INVALID_TOKEN"})
            |> halt()
        end
    end
  end

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        token

      _ ->
        # Fallback: query param token for SSE streaming routes only
        if is_streaming_request?(conn) do
          conn.params["token"]
        else
          nil
        end
    end
  end

  defp is_streaming_request?(conn) do
    path = conn.request_path || ""
    accept = get_req_header(conn, "accept") |> List.first() || ""
    String.contains?(path, "/stream") or String.contains?(accept, "text/event-stream")
  end
end
