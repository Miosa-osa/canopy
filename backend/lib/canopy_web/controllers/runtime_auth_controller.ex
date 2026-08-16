defmodule CanopyWeb.RuntimeAuthController do
  @moduledoc """
  HTTP API for runtime authentication flows.

  Routes (all under `/api/v1/runtimes/:type/auth`):

    POST   /auth/start       — start device-code OAuth flow
    POST   /auth/poll        — poll device-code flow for token
    PUT    /credentials      — store API key
    DELETE /credentials      — revoke active credential
    POST   /test             — probe CLI binary with stored credential

  Business logic lives in `Canopy.Runtimes.Auth`. This controller
  does HTTP parsing and serialization only.
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Runtimes
  alias Canopy.Runtimes.Auth
  alias Canopy.Runtimes.Auth.Detector
  alias CanopyWeb.Schemas.RuntimeAuthSchema

  action_fallback CanopyWeb.FallbackController

  tags ["runtimes"]

  operation :auth_status,
    summary: "Get the current auth detection status for a runtime",
    description: """
    Runs per-method detection (subscription file, CLI login probe, stored API key)
    and returns which method is active. Use this to render the correct auth panel
    without guessing.

    Returns 404 if the runtime type is not found.
    """,
    parameters: [
      type: [in: :path, description: "Runtime type identifier", type: :string, required: true]
    ],
    responses: [
      ok: {"Auth status", "application/json", RuntimeAuthSchema.AuthStatusResponse},
      not_found:
        {"Runtime not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec auth_status(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def auth_status(conn, %{"type" => runtime_type}) do
    case Runtimes.get_by_type(runtime_type) do
      {:ok, runtime} ->
        status = Detector.detect(runtime)
        json(conn, status)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Runtime #{runtime_type} not found"})
    end
  end

  operation :start_flow,
    summary: "Start a device-code OAuth flow for a runtime",
    description: """
    Initiates RFC 8628 device authorization. Returns device_code, user_code,
    verification_url, expires_in, and interval. Returns 422 if the runtime
    does not support OAuth device flow (use PUT /credentials for API keys instead).
    """,
    parameters: [
      type: [in: :path, description: "Runtime type identifier", type: :string, required: true]
    ],
    responses: [
      ok: {"Flow parameters", "application/json", RuntimeAuthSchema.DeviceFlowResponse},
      unprocessable_entity:
        {"Not supported", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec start_flow(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def start_flow(conn, %{"type" => runtime_type}) do
    case Auth.start_device_flow(runtime_type) do
      {:ok, flow} ->
        json(conn, %{
          flow_type: "device_code",
          device_code: flow.device_code,
          user_code: flow.user_code,
          verification_url: flow.verification_url,
          expires_in: flow.expires_in,
          interval: flow.interval
        })

      {:error, :not_supported} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "oauth_not_supported",
          message:
            "This runtime does not support device-code OAuth. Use PUT /credentials to set an API key."
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "flow_start_failed", message: inspect(reason)})
    end
  end

  operation :poll_flow,
    summary: "Poll a device-code flow for token completion",
    description: """
    Polls the provider for a completed device-code authorization.
    Returns `{status: "active"}` when the user completes the browser step,
    `{status: "pending"}` while waiting, or `{status: "expired"}` on timeout.
    """,
    parameters: [
      type: [in: :path, description: "Runtime type identifier", type: :string, required: true]
    ],
    request_body: {"Poll request", "application/json", RuntimeAuthSchema.PollRequest},
    responses: [
      ok: {"Poll result", "application/json", RuntimeAuthSchema.PollResponse}
    ]

  @spec poll_flow(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def poll_flow(conn, %{"type" => runtime_type, "device_code" => device_code}) do
    case Auth.poll_device_flow(runtime_type, device_code) do
      {:ok, _cred} ->
        json(conn, %{status: "active"})

      {:error, :authorization_pending} ->
        json(conn, %{status: "pending"})

      {:error, :expired} ->
        json(conn, %{status: "expired"})

      {:error, :not_supported} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "oauth_not_supported", message: "Device-code flow not supported."})
    end
  end

  def poll_flow(_conn, _params), do: {:error, :bad_request}

  operation :store_credentials,
    summary: "Store an API key credential for a runtime",
    description: """
    Encrypts and persists an API key for the given runtime type.
    The credential is immediately active and will be used on next session spawn.
    Replaces any existing credential for this runtime.
    """,
    parameters: [
      type: [in: :path, description: "Runtime type identifier", type: :string, required: true]
    ],
    request_body:
      {"Credential body", "application/json", RuntimeAuthSchema.StoreCredentialRequest},
    responses: [
      ok: {"Credential stored", "application/json", RuntimeAuthSchema.CredentialStatusResponse},
      unprocessable_entity:
        {"Validation error", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec store_credentials(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def store_credentials(conn, %{"type" => runtime_type, "api_key" => api_key})
      when is_binary(api_key) and api_key != "" do
    case Auth.store_api_key(runtime_type, api_key) do
      {:ok, cred} ->
        json(conn, %{
          runtime_type: runtime_type,
          auth_type: cred.auth_type,
          status: cred.status
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def store_credentials(_conn, _params), do: {:error, :bad_request}

  operation :revoke_credentials,
    summary: "Revoke the active credential for a runtime",
    description: """
    Revokes the active credential (API key or OAuth token) for the given runtime.
    Calls the provider's remote revocation endpoint (best-effort), then marks
    the local record as revoked. Returns 204 regardless of prior state.
    """,
    parameters: [
      type: [in: :path, description: "Runtime type identifier", type: :string, required: true]
    ],
    responses: [
      no_content: "Credential revoked"
    ]

  @spec revoke_credentials(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def revoke_credentials(conn, %{"type" => runtime_type}) do
    :ok = Auth.revoke_credential(runtime_type)
    send_resp(conn, :no_content, "")
  end

  operation :test_credential,
    summary: "Test that the stored credential for a runtime is valid",
    description: """
    Invokes the runtime's CLI binary with the stored credential to confirm auth works.
    Returns ok: true with latency_ms on success, ok: false with an error message on failure.
    """,
    parameters: [
      type: [in: :path, description: "Runtime type identifier", type: :string, required: true]
    ],
    responses: [
      ok: {"Test result", "application/json", RuntimeAuthSchema.TestCredentialResponse}
    ]

  @spec test_credential(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def test_credential(conn, %{"type" => runtime_type}) do
    case Auth.test_credential(runtime_type) do
      {:ok, result} ->
        json(conn, result)

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "test_failed", message: inspect(reason)})
    end
  end
end
