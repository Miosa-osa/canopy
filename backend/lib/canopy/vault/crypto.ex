defmodule Canopy.Vault.Crypto do
  @moduledoc """
  AES-256-GCM encryption helpers for the credential vault.

  All values stored in the `credentials` table are encrypted at rest using
  AES-256-GCM with a random 12-byte nonce per record. The encryption key is
  derived from `SECRET_KEY_BASE` at runtime using HKDF-SHA256.

  ## Key derivation (v2 — HKDF-SHA256)

  HKDF extract+expand (RFC 5869, single output block):

      PRK = HMAC-SHA256(salt="canopy-vault-v1-salt-2026-hkdf32", IKM=SECRET_KEY_BASE)
      key = HMAC-SHA256(PRK, info="canopy-vault-v1" || 0x01)[:32]

  The 32-byte salt is fixed and documented here. Rotating `SECRET_KEY_BASE`
  produces a new key and invalidates all stored credentials.

  Raises at runtime if `SECRET_KEY_BASE` is not set — the vault cannot operate
  without a real key material source.

  ## Legacy key derivation (v1 — SHA-256, pre-2026-04-18)

  The old derivation was `SHA-256(SECRET_KEY_BASE <> "canopy-vault-v1")`.
  `decrypt_legacy/4` is retained so `Canopy.Vault.do_get/2` can attempt
  transparent re-encryption of rows written before this migration.

  The `aad` (Additional Authenticated Data) binds the ciphertext to the
  `(runtime_type, field_key)` pair so that a ciphertext cannot be relocated
  to a different slot without detection.
  """

  @nonce_bytes 12

  # HKDF-SHA256 parameters (v2 key derivation)
  # Salt: fixed 32-byte literal — "canopy-vault-v1-salt-2026-hkdf32"
  @kdf_salt "canopy-vault-v1-salt-2026-hkdf32"
  @kdf_info "canopy-vault-v1"
  @key_bytes 32

  # Legacy key suffix (v1 SHA-256 derivation — kept for migration reads only)
  @legacy_key_suffix "canopy-vault-v1"

  @doc """
  Encrypts `plaintext` for the given `(runtime_type, field_key)` slot.

  Returns `{ciphertext, nonce}` where both are raw binaries. The nonce must be
  stored alongside the ciphertext and passed to `decrypt/4` for decryption.

  Raises if `SECRET_KEY_BASE` is not configured.
  """
  @spec encrypt(String.t(), String.t(), String.t()) :: {binary(), binary()}
  def encrypt(plaintext, runtime_type, field_key) when is_binary(plaintext) do
    key = derive_key()
    nonce = :crypto.strong_rand_bytes(@nonce_bytes)
    aad = build_aad(runtime_type, field_key)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, plaintext, aad, true)

    {ciphertext <> tag, nonce}
  end

  @doc """
  Decrypts `ciphertext` that was encrypted for the given `(runtime_type, field_key)` slot
  using the current HKDF-SHA256 key.

  Returns `{:ok, plaintext}` or `{:error, :decryption_failed}` when the tag
  does not authenticate (wrong key, tampered data, or wrong slot).
  """
  @spec decrypt(binary(), binary(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, :decryption_failed}
  def decrypt(ciphertext_with_tag, nonce, runtime_type, field_key)
      when is_binary(ciphertext_with_tag) and is_binary(nonce) do
    key = derive_key()
    do_decrypt(ciphertext_with_tag, nonce, runtime_type, field_key, key)
  end

  @doc """
  Attempts decryption using the legacy SHA-256 key (pre-2026-04-18).

  Used only by `Canopy.Vault.do_get/2` for transparent migration: if the
  current-key decrypt fails, the vault tries this function. On success, the
  caller re-encrypts the plaintext with the new key (write-on-read migration).

  Returns `{:ok, plaintext}` or `{:error, :decryption_failed}`.
  """
  @spec decrypt_legacy(binary(), binary(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, :decryption_failed}
  def decrypt_legacy(ciphertext_with_tag, nonce, runtime_type, field_key)
      when is_binary(ciphertext_with_tag) and is_binary(nonce) do
    key = derive_legacy_key()
    do_decrypt(ciphertext_with_tag, nonce, runtime_type, field_key, key)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  # HKDF-SHA256 key derivation (RFC 5869, single output block).
  # Raises if SECRET_KEY_BASE is absent — the vault cannot operate without IKM.
  @spec derive_key() :: binary()
  defp derive_key do
    ikm =
      Application.get_env(:canopy, CanopyWeb.Endpoint)[:secret_key_base] ||
        raise "SECRET_KEY_BASE is not set — Vault.Crypto cannot derive an encryption key"

    # HKDF-Extract: PRK = HMAC-SHA256(salt, IKM)
    prk = :crypto.mac(:hmac, :sha256, @kdf_salt, ikm)

    # HKDF-Expand (single block T(1)): HMAC-SHA256(PRK, info || 0x01)
    t1 = :crypto.mac(:hmac, :sha256, prk, @kdf_info <> <<1>>)
    binary_part(t1, 0, @key_bytes)
  end

  # Legacy SHA-256 derivation — retained for transparent migration reads only.
  # Do NOT use for new encryptions.
  @spec derive_legacy_key() :: binary()
  defp derive_legacy_key do
    base = Application.get_env(:canopy, CanopyWeb.Endpoint)[:secret_key_base] || ""
    :crypto.hash(:sha256, base <> @legacy_key_suffix)
  end

  # Core AES-256-GCM decryption shared by both decrypt/4 and decrypt_legacy/4.
  @spec do_decrypt(binary(), binary(), String.t(), String.t(), binary()) ::
          {:ok, String.t()} | {:error, :decryption_failed}
  defp do_decrypt(ciphertext_with_tag, nonce, runtime_type, field_key, key) do
    aad = build_aad(runtime_type, field_key)

    # AES-GCM tag is always 16 bytes
    tag_size = 16
    ciphertext_size = byte_size(ciphertext_with_tag) - tag_size

    if ciphertext_size < 0 do
      {:error, :decryption_failed}
    else
      <<ciphertext::binary-size(ciphertext_size), tag::binary-size(tag_size)>> =
        ciphertext_with_tag

      case :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, ciphertext, aad, tag, false) do
        plaintext when is_binary(plaintext) -> {:ok, plaintext}
        :error -> {:error, :decryption_failed}
      end
    end
  end

  @spec build_aad(String.t(), String.t()) :: binary()
  defp build_aad(runtime_type, field_key), do: "#{runtime_type}:#{field_key}"
end
