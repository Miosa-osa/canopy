defmodule Canopy.Runtimes.Auth.ApiKey do
  @moduledoc """
  Generic API-key authentication provider.

  Covers any runtime that authenticates via a single API key environment variable
  rather than OAuth. The user pastes the key; Canopy stores it encrypted in the
  vault. There is no flow to start — the credential is immediately `:active` once stored.

  Used for runtimes not covered by a dedicated OAuth provider, and as the
  fallback when a runtime's OAuth device flow is not yet implemented.
  """

  @behaviour Canopy.Runtimes.Auth.Provider

  @impl true
  def runtime_type, do: "api-key"

  @impl true
  def start_device_flow, do: {:error, :not_supported}

  @impl true
  def poll_token(_device_code), do: {:error, :not_supported}

  @impl true
  def refresh(_refresh_token), do: {:error, :not_supported}

  @impl true
  def revoke(_access_token), do: :ok

  @impl true
  def test(credential) do
    # API-key-only runtimes do not have a standard CLI probe.
    # Return ok: true if the key is present and non-empty.
    api_key = Map.get(credential, "api_key", "")

    if String.length(api_key) > 0 do
      {:ok, %{ok: true, model: nil, latency_ms: 0}}
    else
      {:ok, %{ok: false, model: nil, latency_ms: 0, error: "api_key is empty"}}
    end
  end
end
