defmodule Canopy.Runtimes.Auth do
  @moduledoc """
  Public API for runtime authentication credential management.

  Orchestrates device-code flows, API-key storage, credential retrieval, and
  credential testing. All encryption/decryption goes through `Canopy.Vault.Crypto`
  (HKDF-SHA256 + AES-256-GCM) — this module does not implement crypto directly.

  ## Provider resolution

  Each runtime type maps to a provider module implementing `Canopy.Runtimes.Auth.Provider`.
  Unknown runtime types fall back to `Canopy.Runtimes.Auth.ApiKey`.

  ## Credential storage layout

  Access tokens, refresh tokens, and API keys are encrypted individually.
  Each gets its own `(ciphertext, nonce)` column pair in `runtime_credentials`.
  The AAD for each field is `"runtime_cred:<runtime_type>:<field>"`, binding
  ciphertext to its logical slot.
  """

  import Ecto.Query, only: [from: 2]

  require Logger

  alias Canopy.Repo
  alias Canopy.Runtimes.RuntimeCredential
  alias Canopy.Vault.Crypto

  @provider_registry %{
    "claude-local" => Canopy.Runtimes.Auth.ClaudeCode,
    "codex-local" => Canopy.Runtimes.Auth.Codex,
    "gemini-local" => Canopy.Runtimes.Auth.Gemini
  }

  # ---------------------------------------------------------------------------
  # Provider lookup
  # ---------------------------------------------------------------------------

  @doc "Returns the provider module for the given runtime type, or ApiKey as fallback."
  @spec provider_for(String.t()) :: module()
  def provider_for(runtime_type),
    do: Map.get(@provider_registry, runtime_type, Canopy.Runtimes.Auth.ApiKey)

  # ---------------------------------------------------------------------------
  # Credential retrieval
  # ---------------------------------------------------------------------------

  @doc """
  Returns the active RuntimeCredential for the given runtime type, or `{:error, :not_found}`.
  """
  @spec get_credential(String.t()) ::
          {:ok, RuntimeCredential.t()} | {:error, :not_found}
  def get_credential(runtime_type) do
    case Repo.get_by(RuntimeCredential, runtime_type: runtime_type, status: "active") do
      nil -> {:error, :not_found}
      cred -> {:ok, cred}
    end
  end

  @doc """
  Decrypts and returns the access token from a credential record.

  Returns `{:ok, plaintext}` or `{:error, :not_found}`.
  """
  @spec decrypt_access_token(RuntimeCredential.t()) :: {:ok, String.t()} | {:error, :not_found}
  def decrypt_access_token(%RuntimeCredential{access_token: nil}), do: {:error, :not_found}

  def decrypt_access_token(%RuntimeCredential{
        runtime_type: rt,
        access_token: ct,
        access_token_nonce: nonce
      }) do
    case Crypto.decrypt(ct, nonce, "runtime_cred:#{rt}", "access_token") do
      {:ok, plaintext} -> {:ok, plaintext}
      {:error, :decryption_failed} -> {:error, :not_found}
    end
  end

  @doc """
  Decrypts and returns the API key from a credential record.

  Returns `{:ok, plaintext}` or `{:error, :not_found}`.
  """
  @spec decrypt_api_key(RuntimeCredential.t()) :: {:ok, String.t()} | {:error, :not_found}
  def decrypt_api_key(%RuntimeCredential{api_key_enc: nil}), do: {:error, :not_found}

  def decrypt_api_key(%RuntimeCredential{
        runtime_type: rt,
        api_key_enc: ct,
        api_key_nonce: nonce
      }) do
    case Crypto.decrypt(ct, nonce, "runtime_cred:#{rt}", "api_key") do
      {:ok, plaintext} -> {:ok, plaintext}
      {:error, :decryption_failed} -> {:error, :not_found}
    end
  end

  @doc """
  Returns a decrypted credential map suitable for passing to `Provider.test/1`
  or for injecting into a session's environment.

  Keys present: `"api_key"` and/or `"access_token"` depending on what is stored.
  """
  @spec decrypted_map(RuntimeCredential.t()) :: map()
  def decrypted_map(cred) do
    %{}
    |> maybe_put("api_key", decrypt_api_key(cred))
    |> maybe_put("access_token", decrypt_access_token(cred))
  end

  # ---------------------------------------------------------------------------
  # OAuth device flow
  # ---------------------------------------------------------------------------

  @doc """
  Initiates a device-code flow for the given runtime type.

  Returns the flow parameters or `{:error, :not_supported}` if the provider
  does not implement device-code OAuth.
  """
  @spec start_device_flow(String.t()) ::
          {:ok, Canopy.Runtimes.Auth.Provider.device_flow_result()} | {:error, term()}
  def start_device_flow(runtime_type) do
    provider = provider_for(runtime_type)

    case provider.start_device_flow() do
      {:ok, flow} ->
        # Upsert a pending credential record to track this flow.
        upsert_pending(runtime_type, %{
          auth_type: "oauth",
          meta: %{device_code: flow.device_code, interval: flow.interval}
        })

        {:ok, flow}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Polls the provider for a completed device-code flow.

  On success, stores the tokens and marks the credential `:active`.
  Returns `{:ok, %{status: "active"}}` or `{:error, :authorization_pending}`.
  """
  @spec poll_device_flow(String.t(), String.t()) ::
          {:ok, map()} | {:error, :authorization_pending} | {:error, :expired} | {:error, term()}
  def poll_device_flow(runtime_type, device_code) do
    provider = provider_for(runtime_type)

    case provider.poll_token(device_code) do
      {:ok, tokens} ->
        result = store_oauth_tokens(runtime_type, tokens)
        {:ok, result}

      {:error, :authorization_pending} ->
        {:error, :authorization_pending}

      {:error, :expired} ->
        mark_expired(runtime_type)
        {:error, :expired}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # API key storage
  # ---------------------------------------------------------------------------

  @doc """
  Stores an API key for the given runtime type.

  Encrypts the key, upserts the `runtime_credentials` row, and marks it `:active`.
  Returns the updated credential (without plaintext).
  """
  @spec store_api_key(String.t(), String.t()) ::
          {:ok, RuntimeCredential.t()} | {:error, Ecto.Changeset.t()}
  def store_api_key(runtime_type, plaintext_key) when is_binary(plaintext_key) do
    {ct, nonce} = Crypto.encrypt(plaintext_key, "runtime_cred:#{runtime_type}", "api_key")

    upsert_credential(runtime_type, %{
      auth_type: "api_key",
      status: "active",
      api_key_enc: ct,
      api_key_nonce: nonce
    })
  end

  # ---------------------------------------------------------------------------
  # Revocation
  # ---------------------------------------------------------------------------

  @doc """
  Revokes the active credential for the given runtime type.

  Calls the provider's `revoke/1` callback (best-effort), then marks the row `:revoked`.
  Returns `:ok` regardless of whether a credential existed.
  """
  @spec revoke_credential(String.t()) :: :ok
  def revoke_credential(runtime_type) do
    case get_credential(runtime_type) do
      {:ok, cred} ->
        provider = provider_for(runtime_type)

        # Best-effort remote revocation — log and continue if it fails.
        case decrypt_access_token(cred) do
          {:ok, token} ->
            case provider.revoke(token) do
              :ok ->
                :ok

              {:error, reason} ->
                Logger.warning("[Auth] revoke remote token failed: #{inspect(reason)}")
            end

          {:error, :not_found} ->
            :ok
        end

        mark_revoked(runtime_type)

      {:error, :not_found} ->
        :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Test (probe CLI binary with credential)
  # ---------------------------------------------------------------------------

  @doc """
  Tests whether the stored credential for the given runtime type is valid.

  Decrypts the credential and passes it to the provider's `test/1` callback,
  which invokes the CLI binary. Updates `last_used_at` on success.
  """
  @spec test_credential(String.t()) ::
          {:ok, Canopy.Runtimes.Auth.Provider.test_result()} | {:error, term()}
  def test_credential(runtime_type) do
    provider = provider_for(runtime_type)

    # Build credential map — may be empty if nothing stored yet (test can still probe binary).
    cred_map =
      case get_credential(runtime_type) do
        {:ok, cred} -> decrypted_map(cred)
        {:error, :not_found} -> %{}
      end

    case provider.test(cred_map) do
      {:ok, result} ->
        if result.ok, do: touch_last_used(runtime_type)
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Session integration — called by SessionsController.create/2
  # ---------------------------------------------------------------------------

  @doc """
  Fetches the active credential for a runtime and returns a map of env vars
  to inject when spawning a session subprocess.

  Behavior depends on the runtime's `auth_profile`:
  - `cli_login` or `subscription_detect` as active method → spawn with no injected env key
    (the CLI manages its own credentials and browser auth flow)
  - `api_key` as active method → inject the stored key as an env var
  - No active method and runtime has no auth_profile → degrade gracefully with empty env
  - No active method and runtime requires auth → return `{:error, :runtime_unauthenticated}`

  The env var map uses string keys matching what the adapter Env modules expect.
  Callers may merge this into the context before calling `adapter.execute/1`.
  """
  @spec session_env_for(String.t()) :: {:ok, map()} | {:error, :runtime_unauthenticated}
  def session_env_for(runtime_type) do
    alias Canopy.Runtimes
    alias Canopy.Runtimes.Auth.Detector

    case Runtimes.get_by_type(runtime_type) do
      {:ok, runtime} when not is_nil(runtime.auth_profile) ->
        status = Detector.detect(runtime)

        case status.active_method do
          method when method in ["subscription_detect", "cli_login"] ->
            # CLI is authenticated natively — don't inject env vars
            {:ok, %{}}

          "api_key" ->
            case get_credential(runtime_type) do
              {:ok, cred} -> {:ok, build_session_env(runtime_type, cred)}
              {:error, :not_found} -> {:error, :runtime_unauthenticated}
            end

          nil ->
            # No auth detected — runtimes with no auth_profile methods degrade gracefully
            methods = Map.get(runtime.auth_profile, "methods", [])
            if methods == [], do: {:ok, %{}}, else: {:error, :runtime_unauthenticated}
        end

      {:ok, _runtime} ->
        # Runtime with no auth_profile — legacy path: try stored credential, degrade gracefully
        case get_credential(runtime_type) do
          {:ok, cred} -> {:ok, build_session_env(runtime_type, cred)}
          {:error, :not_found} -> {:ok, %{}}
        end

      {:error, :not_found} ->
        # Runtime not in DB — fall back to direct credential lookup (legacy path)
        case get_credential(runtime_type) do
          {:ok, cred} -> {:ok, build_session_env(runtime_type, cred)}
          {:error, :not_found} -> {:ok, %{}}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Private — encryption helpers
  # ---------------------------------------------------------------------------

  @spec store_oauth_tokens(String.t(), Canopy.Runtimes.Auth.Provider.tokens()) ::
          RuntimeCredential.t()
  defp store_oauth_tokens(runtime_type, tokens) do
    {at_ct, at_nonce} =
      Crypto.encrypt(tokens.access_token, "runtime_cred:#{runtime_type}", "access_token")

    {rt_ct, rt_nonce} =
      if tokens.refresh_token do
        Crypto.encrypt(tokens.refresh_token, "runtime_cred:#{runtime_type}", "refresh_token")
      else
        {nil, nil}
      end

    expires_at =
      if tokens.expires_in do
        DateTime.utc_now()
        |> DateTime.add(tokens.expires_in, :second)
        |> DateTime.truncate(:second)
      end

    {:ok, cred} =
      upsert_credential(runtime_type, %{
        auth_type: "oauth",
        status: "active",
        access_token: at_ct,
        access_token_nonce: at_nonce,
        refresh_token: rt_ct,
        refresh_token_nonce: rt_nonce,
        expires_at: expires_at,
        scopes: tokens.scopes || []
      })

    cred
  end

  @spec upsert_pending(String.t(), map()) ::
          {:ok, RuntimeCredential.t()} | {:error, Ecto.Changeset.t()}
  defp upsert_pending(runtime_type, attrs) do
    upsert_credential(runtime_type, Map.put(attrs, :status, "pending"))
  end

  @spec upsert_credential(String.t(), map()) ::
          {:ok, RuntimeCredential.t()} | {:error, Ecto.Changeset.t()}
  defp upsert_credential(runtime_type, attrs) do
    base_attrs = Map.put(attrs, :runtime_type, runtime_type)

    %RuntimeCredential{}
    |> RuntimeCredential.changeset(base_attrs)
    |> Repo.insert(
      on_conflict: {:replace, conflict_fields(base_attrs)},
      conflict_target: :runtime_type,
      returning: true
    )
  end

  # Only replace fields that are present in the attrs — don't wipe encrypted
  # columns that weren't part of this particular update.
  @spec conflict_fields(map()) :: [atom()]
  defp conflict_fields(attrs) do
    possible = [
      :auth_type,
      :status,
      :access_token,
      :access_token_nonce,
      :refresh_token,
      :refresh_token_nonce,
      :api_key_enc,
      :api_key_nonce,
      :expires_at,
      :scopes,
      :last_used_at,
      :meta,
      :updated_at
    ]

    Enum.filter(possible, &Map.has_key?(attrs, &1))
  end

  @spec mark_expired(String.t()) :: :ok
  defp mark_expired(runtime_type) do
    Repo.update_all(
      from(c in RuntimeCredential, where: c.runtime_type == ^runtime_type),
      set: [status: "expired", updated_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)]
    )

    :ok
  end

  @spec mark_revoked(String.t()) :: :ok
  defp mark_revoked(runtime_type) do
    Repo.update_all(
      from(c in RuntimeCredential, where: c.runtime_type == ^runtime_type),
      set: [status: "revoked", updated_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)]
    )

    :ok
  end

  @spec touch_last_used(String.t()) :: :ok
  defp touch_last_used(runtime_type) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.update_all(
      from(c in RuntimeCredential, where: c.runtime_type == ^runtime_type),
      set: [last_used_at: now, updated_at: now]
    )

    :ok
  end

  @spec build_session_env(String.t(), RuntimeCredential.t()) :: map()
  defp build_session_env(runtime_type, cred) do
    api_key = decrypt_api_key(cred)
    access_token = decrypt_access_token(cred)

    case runtime_type do
      "claude-local" ->
        case api_key do
          {:ok, key} -> %{"ANTHROPIC_API_KEY" => key}
          {:error, _} -> %{}
        end

      "codex-local" ->
        case api_key do
          {:ok, key} -> %{"OPENAI_API_KEY" => key}
          {:error, _} -> %{}
        end

      "gemini-local" ->
        case api_key do
          {:ok, key} ->
            %{"GEMINI_API_KEY" => key}

          {:error, _} ->
            case access_token do
              {:ok, token} -> %{"GEMINI_OAUTH_TOKEN" => token}
              {:error, _} -> %{}
            end
        end

      _ ->
        case api_key do
          {:ok, key} -> %{"API_KEY" => key}
          {:error, _} -> %{}
        end
    end
  end

  @spec maybe_put(map(), String.t(), {:ok, term()} | {:error, term()}) :: map()
  defp maybe_put(map, _key, {:error, _}), do: map
  defp maybe_put(map, key, {:ok, value}), do: Map.put(map, key, value)
end
