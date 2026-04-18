defmodule Canopy.Vault do
  @moduledoc """
  Public API for the Canopy credential vault.

  Secrets (API keys, tokens) are encrypted with AES-256-GCM and stored in the
  `credentials` database table. The encryption key is derived from
  `SECRET_KEY_BASE` at runtime. Plaintext values never leave this module — all
  public functions that accept plaintext encrypt immediately; all functions that
  retrieve credentials decrypt before returning.

  ## Design constraints

  - `list_fields/1` returns field keys only, never values.
  - `get/2` returns the decrypted plaintext or `{:error, :not_found}`.
  - `put/3` upserts — calling it again with the same `(runtime_type, field_key)`
    overwrites the previous ciphertext.
  - `delete/2` is idempotent — deleting a non-existent key returns `:ok`.

  ## Future migration

  This module's public API is stable. When Canopy ships the Tauri keyring
  integration (macOS Keychain / Windows Credential Store), this module becomes
  a thin shim that routes to the OS keyring instead of Postgres. Callers are
  not affected.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Repo
  alias Canopy.Vault.{Credential, Crypto}

  @doc """
  Stores an encrypted credential for the given runtime type and field key.

  If a credential for `(runtime_type, field_key)` already exists, it is
  replaced atomically via upsert.

  Returns `{:ok, credential}` or `{:error, changeset}`.
  """
  @spec put(String.t(), String.t(), String.t()) ::
          {:ok, Credential.t()} | {:error, Ecto.Changeset.t()}
  def put(runtime_type, field_key, plaintext)
      when is_binary(runtime_type) and is_binary(field_key) and is_binary(plaintext) do
    {ciphertext, nonce} = Crypto.encrypt(plaintext, runtime_type, field_key)

    attrs = %{
      runtime_type: runtime_type,
      field_key: field_key,
      encrypted_value: ciphertext,
      nonce: nonce
    }

    %Credential{}
    |> Credential.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:encrypted_value, :nonce, :updated_at]},
      conflict_target: [:runtime_type, :field_key]
    )
  end

  @doc """
  Retrieves and decrypts a stored credential.

  Returns `{:ok, plaintext}` or `{:error, :not_found}`.

  If the database is unavailable (e.g. during tests without a sandbox checkout)
  the function returns `{:error, :not_found}` rather than raising. This allows
  adapter env builders to degrade gracefully — the CLI binary falls back to its
  own stored credentials when the env var is absent.
  """
  @spec get(String.t(), String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get(runtime_type, field_key)
      when is_binary(runtime_type) and is_binary(field_key) do
    do_get(runtime_type, field_key)
  rescue
    _err -> {:error, :not_found}
  end

  @doc """
  Deletes a stored credential.

  Returns `:ok` regardless of whether the credential existed.
  """
  @spec delete(String.t(), String.t()) :: :ok
  def delete(runtime_type, field_key)
      when is_binary(runtime_type) and is_binary(field_key) do
    Repo.delete_all(
      from(c in Credential,
        where: c.runtime_type == ^runtime_type and c.field_key == ^field_key
      )
    )

    :ok
  end

  @doc """
  Returns the list of field keys stored for a given runtime type.

  Plaintext values are never returned. Useful for telling the UI which
  fields have been configured without exposing the secrets.
  """
  @spec list_fields(String.t()) :: [String.t()]
  def list_fields(runtime_type) when is_binary(runtime_type) do
    Repo.all(
      from(c in Credential,
        where: c.runtime_type == ^runtime_type,
        select: c.field_key,
        order_by: [asc: c.field_key]
      )
    )
  end

  @spec do_get(String.t(), String.t()) :: {:ok, String.t()} | {:error, :not_found}
  defp do_get(runtime_type, field_key) do
    case Repo.get_by(Credential, runtime_type: runtime_type, field_key: field_key) do
      nil ->
        {:error, :not_found}

      %Credential{encrypted_value: ciphertext, nonce: nonce} ->
        case Crypto.decrypt(ciphertext, nonce, runtime_type, field_key) do
          {:ok, plaintext} -> {:ok, plaintext}
          {:error, :decryption_failed} -> {:error, :not_found}
        end
    end
  end
end
