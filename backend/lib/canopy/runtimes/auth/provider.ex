defmodule Canopy.Runtimes.Auth.Provider do
  @moduledoc """
  Behaviour contract for runtime authentication providers.

  Each OAuth-capable runtime implements this behaviour. API-key-only runtimes
  use `Canopy.Runtimes.Auth.ApiKey`, which skips the device-flow callbacks.

  ## Device-code flow (RFC 8628)

  1. Frontend calls `POST /auth/start` → backend calls `start_device_flow/0`
  2. Backend returns `device_code`, `user_code`, `verification_url`, `expires_in`,
     `interval` to the frontend.
  3. Frontend polls `POST /auth/poll` with the opaque `device_code` value.
  4. Backend calls `poll_token/1` until `{:ok, tokens}` or `{:error, :expired}`.
  5. Backend stores tokens via `Canopy.Runtimes.Auth.store_tokens/2`.

  ## Credential test

  `test/1` receives the decrypted token map and calls the runtime's binary
  with a minimal prompt to prove auth works end-to-end. Returns latency in ms.
  """

  @type device_flow_result :: %{
          device_code: String.t(),
          user_code: String.t(),
          verification_url: String.t(),
          expires_in: pos_integer(),
          interval: pos_integer()
        }

  @type tokens :: %{
          access_token: String.t(),
          refresh_token: String.t() | nil,
          expires_in: pos_integer() | nil,
          scopes: [String.t()]
        }

  @type test_result :: %{ok: boolean(), model: String.t() | nil, latency_ms: non_neg_integer()}

  @doc "Returns the runtime type string this provider handles."
  @callback runtime_type() :: String.t()

  @doc """
  Initiates a device-code authorization flow (RFC 8628).

  Returns the flow parameters to show to the user. If the provider does not
  support device-code flow (e.g. API-key-only), return `{:error, :not_supported}`.
  """
  @callback start_device_flow() :: {:ok, device_flow_result()} | {:error, term()}

  @doc """
  Polls the token endpoint during a device-code flow.

  Returns `{:ok, tokens}` when the user completes authorization,
  `{:error, :authorization_pending}` while waiting, or `{:error, :expired}`.
  """
  @callback poll_token(device_code :: String.t()) ::
              {:ok, tokens()}
              | {:error, :authorization_pending}
              | {:error, :expired}
              | {:error, term()}

  @doc """
  Exchanges a refresh token for a new access token.

  Returns `{:error, :not_supported}` for providers without refresh semantics.
  """
  @callback refresh(refresh_token :: String.t()) :: {:ok, tokens()} | {:error, term()}

  @doc "Revokes the given access token at the provider's revocation endpoint."
  @callback revoke(access_token :: String.t()) :: :ok | {:error, term()}

  @doc """
  Tests that the stored credential actually works by running a minimal CLI probe.

  Receives the decrypted token or API key, invokes the binary with a no-op prompt,
  and returns the latency. Used by `POST /api/v1/runtimes/:type/auth/test`.
  """
  @callback test(credential :: map()) :: {:ok, test_result()} | {:error, term()}
end
