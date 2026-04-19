defmodule CanopyWeb.MiosaController do
  @moduledoc """
  HTTP API for MIOSA integration settings and reachability.

  Routes (mounted under /api/v1 in router.ex):
    GET /miosa/health   — reachability probe (configured? + optional ping)
    GET /miosa          — current config shape (api_key redacted)
    PUT /settings/miosa — save MIOSA credentials to application env
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Miosa
  alias CanopyWeb.Schemas.MiosaSchema

  action_fallback CanopyWeb.FallbackController

  tags ["miosa"]

  # ---------------------------------------------------------------------------
  # GET /miosa/health
  # ---------------------------------------------------------------------------

  operation :health,
    summary: "MIOSA reachability probe",
    description: """
    Returns whether MIOSA is configured and, if so, whether it is reachable.
    When not configured, `reachable` is `null` and no network call is made.
    """,
    responses: [
      ok: {"Health result", "application/json", MiosaSchema.MiosaHealth}
    ]

  @spec health(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def health(conn, _params) do
    configured = Miosa.configured?()

    if configured do
      case client().ping(timeout: 5_000) do
        {:ok, latency_ms} ->
          json(conn, %{configured: true, reachable: true, latency_ms: latency_ms, error: nil})

        {:error, reason} ->
          json(conn, %{
            configured: true,
            reachable: false,
            latency_ms: nil,
            error: inspect(reason)
          })
      end
    else
      json(conn, %{configured: false, reachable: nil, latency_ms: nil, error: nil})
    end
  end

  # ---------------------------------------------------------------------------
  # GET /miosa
  # ---------------------------------------------------------------------------

  operation :show,
    summary: "Get MIOSA configuration",
    description: """
    Returns the current MIOSA API configuration. The api_key is always redacted
    to a masked form — it is never returned in plaintext.
    """,
    responses: [
      ok: {"MIOSA config", "application/json", MiosaSchema.MiosaConfig}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _params) do
    api_url = Application.get_env(:canopy, :miosa_api_url, "")
    api_key = Application.get_env(:canopy, :miosa_api_key, "")
    configured = Miosa.configured?()

    json(conn, %{
      api_url: api_url,
      api_key_masked: mask_key(api_key),
      configured: configured
    })
  end

  # ---------------------------------------------------------------------------
  # PUT /settings/miosa
  # ---------------------------------------------------------------------------

  operation :update,
    summary: "Save MIOSA credentials",
    description: """
    Stores MIOSA API URL and key into application environment. Changes take
    effect immediately for subsequent requests. Note: in production these
    should be set via environment variables; this endpoint supports runtime
    override for local/dev use.
    """,
    request_body: {"MIOSA credentials", "application/json", MiosaSchema.MiosaUpdateBody},
    responses: [
      ok: {"Updated config", "application/json", MiosaSchema.MiosaConfig},
      unprocessable_entity:
        {"Validation error", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"api_url" => api_url} = params) when is_binary(api_url) and api_url != "" do
    api_key = Map.get(params, "api_key", "")

    Application.put_env(:canopy, :miosa_api_url, String.trim(api_url))
    Application.put_env(:canopy, :miosa_api_key, api_key)

    json(conn, %{
      api_url: String.trim(api_url),
      api_key_masked: mask_key(api_key),
      configured: Miosa.configured?()
    })
  end

  def update(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "missing_param", message: "api_url is required and must be non-empty"})
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Masks all but the prefix of an API key for safe display.
  # "sk-abc12345..." → "sk-...****"
  # "" or short strings → "****"
  @spec mask_key(String.t()) :: String.t()
  defp mask_key(""), do: "****"

  defp mask_key(key) when byte_size(key) <= 6, do: "****"

  defp mask_key(key) do
    prefix = binary_part(key, 0, min(6, byte_size(key)))
    "#{prefix}...****"
  end

  @spec client() :: module()
  defp client do
    Application.get_env(:canopy, :miosa_client, Canopy.Miosa.Client)
  end
end
