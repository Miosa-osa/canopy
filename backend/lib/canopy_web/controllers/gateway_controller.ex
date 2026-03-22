defmodule CanopyWeb.GatewayController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.Gateway
  import Ecto.Query

  def index(conn, _params) do
    gateways = Repo.all(from g in Gateway, order_by: [desc: g.is_primary, asc: g.inserted_at])
    json(conn, %{gateways: Enum.map(gateways, &serialize/1)})
  end

  def create(conn, params) do
    changeset = Gateway.changeset(%Gateway{}, params)

    case Repo.insert(changeset) do
      {:ok, gateway} ->
        Canopy.EventBus.broadcast(
          Canopy.EventBus.activity_topic(),
          %{event: "gateway.added", gateway_id: gateway.id, url: gateway.url}
        )

        conn |> put_status(201) |> json(%{gateway: serialize(gateway)})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_failed", details: format_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repo.get(Gateway, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      gateway ->
        Repo.delete!(gateway)

        Canopy.EventBus.broadcast(
          Canopy.EventBus.activity_topic(),
          %{event: "gateway.removed", gateway_id: id}
        )

        json(conn, %{ok: true})
    end
  end

  def probe(conn, %{"gateway_id" => id}) do
    case Repo.get(Gateway, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      gateway ->
        probe_url = String.trim_trailing(gateway.url, "/") <> "/health"
        start_ms = System.monotonic_time(:millisecond)

        result =
          Req.get(probe_url,
            headers: build_auth_headers(gateway),
            receive_timeout: 10_000
          )

        elapsed_ms = System.monotonic_time(:millisecond) - start_ms

        {new_status, latency} =
          case result do
            {:ok, %{status: code}} when code in 200..299 ->
              {"connected", elapsed_ms}

            {:ok, %{status: _code}} ->
              {"error", elapsed_ms}

            {:error, _} ->
              {"error", nil}
          end

        {:ok, updated} =
          gateway
          |> Ecto.Changeset.change(
            status: new_status,
            latency_ms: latency,
            last_probe_at: DateTime.utc_now()
          )
          |> Repo.update()

        Canopy.EventBus.broadcast(
          Canopy.EventBus.activity_topic(),
          %{event: "gateway.probed", gateway_id: id, status: new_status, latency_ms: latency}
        )

        json(conn, %{gateway: serialize(updated)})
    end
  end

  defp build_auth_headers(%Gateway{token: nil}), do: []
  defp build_auth_headers(%Gateway{token: token}), do: [{"authorization", "Bearer #{token}"}]

  defp derive_provider(url) when is_binary(url) do
    cond do
      String.contains?(url, "anthropic") -> "Anthropic"
      String.contains?(url, "openai") -> "OpenAI"
      String.contains?(url, "localhost") or String.contains?(url, "127.0.0.1") -> "Local"
      true -> "Custom"
    end
  end

  defp derive_provider(_), do: "Custom"

  defp derive_name(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> host
      _ -> url
    end
  end

  defp derive_name(_), do: "Gateway"

  defp serialize(%Gateway{} = g) do
    %{
      id: g.id,
      name: derive_name(g.url),
      provider: derive_provider(g.url),
      endpoint: g.url,
      url: g.url,
      models: [],
      api_key_set: not is_nil(g.token) and g.token != "",
      status: g.status,
      latency_ms: g.latency_ms,
      is_primary: g.is_primary,
      last_probe_at: g.last_probe_at,
      inserted_at: g.inserted_at,
      updated_at: g.updated_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
