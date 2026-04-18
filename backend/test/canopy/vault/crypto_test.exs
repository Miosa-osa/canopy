defmodule Canopy.Vault.CryptoTest do
  @moduledoc """
  Unit tests for Canopy.Vault.Crypto encryption helpers.

  Tests run without a database — pure crypto logic.
  """

  use ExUnit.Case, async: true

  alias Canopy.Vault.Crypto

  describe "encrypt/3 and decrypt/4" do
    test "round trips a short string" do
      {ciphertext, nonce} = Crypto.encrypt("hello", "claude-local", "api_key")
      assert {:ok, "hello"} = Crypto.decrypt(ciphertext, nonce, "claude-local", "api_key")
    end

    test "round trips an empty string" do
      {ciphertext, nonce} = Crypto.encrypt("", "runtime", "field")
      assert {:ok, ""} = Crypto.decrypt(ciphertext, nonce, "runtime", "field")
    end

    test "round trips a long string (> 4KB)" do
      plaintext = String.duplicate("x", 5000)
      {ciphertext, nonce} = Crypto.encrypt(plaintext, "runtime", "key")
      assert {:ok, ^plaintext} = Crypto.decrypt(ciphertext, nonce, "runtime", "key")
    end

    test "ciphertext is different from plaintext" do
      {ciphertext, _nonce} = Crypto.encrypt("secret", "runtime", "key")
      refute ciphertext == "secret"
    end

    test "two encryptions of the same plaintext produce different ciphertexts (random nonce)" do
      {ct1, _nonce1} = Crypto.encrypt("same", "runtime", "key")
      {ct2, _nonce2} = Crypto.encrypt("same", "runtime", "key")
      # Random nonce means different ciphertext
      refute ct1 == ct2
    end

    test "fails decryption with wrong nonce" do
      {ciphertext, _nonce} = Crypto.encrypt("secret", "runtime", "key")
      bad_nonce = :crypto.strong_rand_bytes(12)

      assert {:error, :decryption_failed} =
               Crypto.decrypt(ciphertext, bad_nonce, "runtime", "key")
    end

    test "fails decryption when runtime_type differs (AAD mismatch)" do
      {ciphertext, nonce} = Crypto.encrypt("secret", "claude-local", "api_key")

      assert {:error, :decryption_failed} =
               Crypto.decrypt(ciphertext, nonce, "codex-local", "api_key")
    end

    test "fails decryption when field_key differs (AAD mismatch)" do
      {ciphertext, nonce} = Crypto.encrypt("secret", "claude-local", "api_key")

      assert {:error, :decryption_failed} =
               Crypto.decrypt(ciphertext, nonce, "claude-local", "other_key")
    end

    test "fails decryption with truncated ciphertext" do
      {ciphertext, nonce} = Crypto.encrypt("hello world", "runtime", "key")
      truncated = binary_part(ciphertext, 0, max(0, byte_size(ciphertext) - 5))
      result = Crypto.decrypt(truncated, nonce, "runtime", "key")
      assert result == {:error, :decryption_failed}
    end
  end

  # ---------------------------------------------------------------------------
  # HKDF vs legacy key independence
  # ---------------------------------------------------------------------------

  describe "HKDF key and legacy key produce different keys" do
    test "ciphertext encrypted with encrypt/3 cannot be decrypted by decrypt_legacy/4" do
      {ciphertext, nonce} = Crypto.encrypt("secret-value", "runtime", "key")

      # The HKDF and legacy SHA-256 keys differ, so cross-decryption must fail.
      assert {:error, :decryption_failed} =
               Crypto.decrypt_legacy(ciphertext, nonce, "runtime", "key")
    end
  end

  # ---------------------------------------------------------------------------
  # decrypt_legacy/4 -- round trips using the old SHA-256 derivation
  # ---------------------------------------------------------------------------

  describe "decrypt_legacy/4" do
    test "can decrypt a ciphertext produced by the legacy SHA-256 key" do
      ikm = Application.get_env(:canopy, CanopyWeb.Endpoint)[:secret_key_base] || ""
      legacy_key = :crypto.hash(:sha256, ikm <> "canopy-vault-v1")

      nonce = :crypto.strong_rand_bytes(12)
      aad = "claude-local:api_key"
      plaintext = "legacy-secret"

      {ciphertext, tag} =
        :crypto.crypto_one_time_aead(:aes_256_gcm, legacy_key, nonce, plaintext, aad, true)

      legacy_ciphertext = ciphertext <> tag

      assert {:ok, "legacy-secret"} =
               Crypto.decrypt_legacy(legacy_ciphertext, nonce, "claude-local", "api_key")
    end

    test "decrypt_legacy/4 fails on ciphertext produced by the new HKDF key" do
      {ciphertext, nonce} = Crypto.encrypt("new-key-value", "runtime", "field")

      assert {:error, :decryption_failed} =
               Crypto.decrypt_legacy(ciphertext, nonce, "runtime", "field")
    end

    test "decrypt_legacy/4 fails decryption with wrong nonce" do
      ikm = Application.get_env(:canopy, CanopyWeb.Endpoint)[:secret_key_base] || ""
      legacy_key = :crypto.hash(:sha256, ikm <> "canopy-vault-v1")

      nonce = :crypto.strong_rand_bytes(12)
      bad_nonce = :crypto.strong_rand_bytes(12)
      aad = "r:k"

      {ct, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, legacy_key, nonce, "x", aad, true)

      assert {:error, :decryption_failed} =
               Crypto.decrypt_legacy(ct <> tag, bad_nonce, "r", "k")
    end
  end
end
