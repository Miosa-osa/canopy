defmodule Canopy.VaultTest do
  @moduledoc """
  Integration tests for the Canopy.Vault credential store.

  Tests cover encryption/decryption round trips, CRUD semantics, and the
  `list_fields/1` helper. All tests run against the real Repo with the SQL
  sandbox so changes are rolled back after each test.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Vault

  # ---------------------------------------------------------------------------
  # put/3 and get/2 round trip
  # ---------------------------------------------------------------------------

  describe "put/3 and get/2" do
    test "stores and retrieves a credential" do
      assert {:ok, _cred} = Vault.put("claude-local", "api_key", "sk-ant-secret")
      assert {:ok, "sk-ant-secret"} = Vault.get("claude-local", "api_key")
    end

    test "round trips unicode plaintext" do
      assert {:ok, _cred} = Vault.put("claude-local", "api_key", "sk-🔐-unicode")
      assert {:ok, "sk-🔐-unicode"} = Vault.get("claude-local", "api_key")
    end

    test "round trips empty string" do
      assert {:ok, _cred} = Vault.put("gemini-local", "api_key", "")
      assert {:ok, ""} = Vault.get("gemini-local", "api_key")
    end

    test "put overwrites existing value for same slot" do
      assert {:ok, _first} = Vault.put("claude-local", "api_key", "first-value")
      assert {:ok, _second} = Vault.put("claude-local", "api_key", "second-value")
      assert {:ok, "second-value"} = Vault.get("claude-local", "api_key")
    end

    test "different field_keys are independent" do
      assert {:ok, _key_cred} = Vault.put("claude-local", "api_key", "key-1")
      assert {:ok, _model_cred} = Vault.put("claude-local", "model", "claude-sonnet-4-6")
      assert {:ok, "key-1"} = Vault.get("claude-local", "api_key")
      assert {:ok, "claude-sonnet-4-6"} = Vault.get("claude-local", "model")
    end

    test "different runtime_types are independent" do
      assert {:ok, _anthropic_cred} = Vault.put("claude-local", "api_key", "anthropic-key")
      assert {:ok, _openai_cred} = Vault.put("codex-local", "api_key", "openai-key")
      assert {:ok, "anthropic-key"} = Vault.get("claude-local", "api_key")
      assert {:ok, "openai-key"} = Vault.get("codex-local", "api_key")
    end

    test "stored bytes are not plaintext (encryption actually runs)" do
      import Ecto.Query
      alias Canopy.Vault.Credential

      Vault.put("claude-local", "api_key", "super-secret-value")

      cred = Canopy.Repo.one(from c in Credential, where: c.field_key == "api_key")
      assert cred != nil
      # The raw binary should not contain the plaintext
      refute cred.encrypted_value == "super-secret-value"
      refute String.contains?(cred.encrypted_value, "super-secret-value")
    end
  end

  # ---------------------------------------------------------------------------
  # get/2 — not found
  # ---------------------------------------------------------------------------

  describe "get/2" do
    test "returns not_found when no credential exists" do
      assert {:error, :not_found} = Vault.get("no-such-runtime", "api_key")
    end

    test "returns not_found for different field_key on same runtime" do
      Vault.put("claude-local", "api_key", "some-value")
      assert {:error, :not_found} = Vault.get("claude-local", "nonexistent_field")
    end
  end

  # ---------------------------------------------------------------------------
  # delete/2
  # ---------------------------------------------------------------------------

  describe "delete/2" do
    test "deletes an existing credential" do
      Vault.put("claude-local", "api_key", "to-be-deleted")
      assert {:ok, _plaintext} = Vault.get("claude-local", "api_key")
      assert :ok = Vault.delete("claude-local", "api_key")
      assert {:error, :not_found} = Vault.get("claude-local", "api_key")
    end

    test "is idempotent — deleting non-existent key returns :ok" do
      assert :ok = Vault.delete("claude-local", "nonexistent")
    end

    test "only deletes the targeted slot" do
      Vault.put("claude-local", "api_key", "keep-me")
      Vault.put("claude-local", "model", "also-keep")
      Vault.delete("claude-local", "model")
      assert {:ok, "keep-me"} = Vault.get("claude-local", "api_key")
    end
  end

  # ---------------------------------------------------------------------------
  # Decryption failure logging (audit fix #5)
  # ---------------------------------------------------------------------------

  describe "get/2 — decryption failure observability" do
    test "logs a warning when decryption fails (key rotation scenario)" do
      import Ecto.Query

      alias Canopy.Vault.Credential

      # Store a valid credential
      Vault.put("claude-local", "rotation_test_key", "original-secret")

      # Corrupt the nonce directly in the DB to simulate key rotation mismatch
      bad_nonce = :crypto.strong_rand_bytes(12)

      Canopy.Repo.update_all(
        from(c in Credential,
          where: c.runtime_type == "claude-local" and c.field_key == "rotation_test_key"
        ),
        set: [nonce: bad_nonce]
      )

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          result = Vault.get("claude-local", "rotation_test_key")
          assert result == {:error, :not_found}
        end)

      assert log =~ "[Vault]"
      assert log =~ "Decryption failed"
      assert log =~ "rotation_test_key"
      assert log =~ "SECRET_KEY_BASE rotation"
    end
  end

  # ---------------------------------------------------------------------------
  # list_fields/1
  # ---------------------------------------------------------------------------

  describe "list_fields/1" do
    test "returns empty list when no credentials exist" do
      assert [] = Vault.list_fields("claude-local")
    end

    test "returns field keys for the given runtime in alphabetical order" do
      Vault.put("claude-local", "model", "claude-opus")
      Vault.put("claude-local", "api_key", "sk-ant-1")
      fields = Vault.list_fields("claude-local")
      assert fields == ["api_key", "model"]
    end

    test "only returns fields for the requested runtime" do
      Vault.put("claude-local", "api_key", "anthropic")
      Vault.put("codex-local", "api_key", "openai")
      assert Vault.list_fields("claude-local") == ["api_key"]
      assert Vault.list_fields("codex-local") == ["api_key"]
    end

    test "does not return plaintext values — only keys" do
      Vault.put("claude-local", "api_key", "secret-value")
      fields = Vault.list_fields("claude-local")
      refute "secret-value" in fields
      assert "api_key" in fields
    end
  end
end
