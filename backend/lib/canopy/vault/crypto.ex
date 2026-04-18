defmodule Canopy.Vault.Crypto do
  @moduledoc """
  AES-256-GCM encryption helpers for the credential vault.

  All values stored in the `credentials` table are encrypted at rest using
  AES-256-GCM with a random 12-byte nonce per record. The encryption key is
  derived from `SECRET_KEY_BASE` at runtime — rotating the key base invalidates
  all stored credentials.

  Key derivation: `SHA-256(SECRET_KEY_BASE <> "canopy-vault-v1")`

  The `aad` (Additional Authenticated Data) binds the ciphertext to the
  `(runtime_type, field_key)` pair so that a ciphertext cannot be relocated
  to a different slot without detection.
  """

  @nonce_bytes 12
  @key_suffix "canopy-vault-v1"

  @doc """
  Encrypts `plaintext` for the given `(runtime_type, field_key)` slot.

  Returns `{ciphertext, nonce}` where both are raw binaries. The nonce must be
  stored alongside the ciphertext and passed to `decrypt/4` for decryption.
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
  Decrypts `ciphertext` that was encrypted for the given `(runtime_type, field_key)` slot.

  Returns `{:ok, plaintext}` or `{:error, :decryption_failed}` when the tag
  does not authenticate (wrong key, tampered data, or wrong slot).
  """
  @spec decrypt(binary(), binary(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, :decryption_failed}
  def decrypt(ciphertext_with_tag, nonce, runtime_type, field_key)
      when is_binary(ciphertext_with_tag) and is_binary(nonce) do
    key = derive_key()
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

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec derive_key() :: binary()
  defp derive_key do
    base = Application.get_env(:canopy, CanopyWeb.Endpoint)[:secret_key_base] || ""
    :crypto.hash(:sha256, base <> @key_suffix)
  end

  @spec build_aad(String.t(), String.t()) :: binary()
  defp build_aad(runtime_type, field_key), do: "#{runtime_type}:#{field_key}"
end
