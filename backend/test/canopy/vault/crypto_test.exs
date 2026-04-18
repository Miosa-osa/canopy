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
end
