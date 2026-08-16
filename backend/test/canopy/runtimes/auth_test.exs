defmodule Canopy.Runtimes.AuthTest do
  @moduledoc """
  Integration tests for `Canopy.Runtimes.Auth`.

  Hits the real database (no mocks). Tests cover:
  - API key storage, retrieval, and vault round-trip
  - Credential status transitions
  - Revocation
  - Session env construction
  - Provider resolution
  """

  use Canopy.DataCase, async: true

  alias Canopy.Runtimes.Auth
  alias Canopy.Runtimes.RuntimeCredential
  alias Canopy.Repo

  # ---------------------------------------------------------------------------
  # Provider resolution
  # ---------------------------------------------------------------------------

  describe "provider_for/1" do
    test "returns ClaudeCode for claude-local" do
      assert Auth.provider_for("claude-local") == Canopy.Runtimes.Auth.ClaudeCode
    end

    test "returns Codex for codex-local" do
      assert Auth.provider_for("codex-local") == Canopy.Runtimes.Auth.Codex
    end

    test "returns Gemini for gemini-local" do
      assert Auth.provider_for("gemini-local") == Canopy.Runtimes.Auth.Gemini
    end

    test "returns ApiKey for unknown runtime" do
      assert Auth.provider_for("unknown-runtime") == Canopy.Runtimes.Auth.ApiKey
    end
  end

  # ---------------------------------------------------------------------------
  # API key storage + vault round-trip
  # ---------------------------------------------------------------------------

  describe "store_api_key/2" do
    test "stores a key, credential is active" do
      assert {:ok, cred} = Auth.store_api_key("claude-local", "sk-ant-test")
      assert cred.runtime_type == "claude-local"
      assert cred.auth_type == "api_key"
      assert cred.status == "active"
    end

    test "encrypted key round-trips correctly" do
      {:ok, _cred} = Auth.store_api_key("codex-local", "sk-openai-round-trip")
      {:ok, cred} = Auth.get_credential("codex-local")
      assert {:ok, "sk-openai-round-trip"} = Auth.decrypt_api_key(cred)
    end

    test "overwrites previous credential for same runtime" do
      {:ok, _} = Auth.store_api_key("gemini-local", "first-key")
      {:ok, _} = Auth.store_api_key("gemini-local", "second-key")

      {:ok, cred} = Auth.get_credential("gemini-local")
      assert {:ok, "second-key"} = Auth.decrypt_api_key(cred)
    end

    test "stored key is never returned as plaintext from get_credential" do
      {:ok, _} = Auth.store_api_key("claude-local", "secret-plaintext")
      {:ok, cred} = Auth.get_credential("claude-local")

      # The struct should not contain the plaintext
      refute cred.api_key_enc == "secret-plaintext"
      # Raw binary only
      assert is_binary(cred.api_key_enc)
    end

    test "ciphertext differs across different runtime types (AAD binding)" do
      {:ok, _} = Auth.store_api_key("claude-local", "same-key")
      {:ok, _} = Auth.store_api_key("codex-local", "same-key")

      {:ok, claude_cred} = Auth.get_credential("claude-local")
      {:ok, codex_cred} = Auth.get_credential("codex-local")

      # Different AADs produce different ciphertexts even for identical plaintexts.
      refute claude_cred.api_key_enc == codex_cred.api_key_enc
    end
  end

  # ---------------------------------------------------------------------------
  # Credential retrieval
  # ---------------------------------------------------------------------------

  describe "get_credential/1" do
    test "returns not_found when no credential exists" do
      assert {:error, :not_found} = Auth.get_credential("no-such-runtime")
    end

    test "returns active credential after store_api_key" do
      {:ok, _} = Auth.store_api_key("aider-local", "aider-key")
      assert {:ok, cred} = Auth.get_credential("aider-local")
      assert cred.status == "active"
    end

    test "returns not_found after revocation" do
      {:ok, _} = Auth.store_api_key("windsurf-local", "ws-key")
      :ok = Auth.revoke_credential("windsurf-local")
      assert {:error, :not_found} = Auth.get_credential("windsurf-local")
    end
  end

  # ---------------------------------------------------------------------------
  # Revocation
  # ---------------------------------------------------------------------------

  describe "revoke_credential/1" do
    test "marks credential as revoked" do
      {:ok, _} = Auth.store_api_key("claude-local", "key-to-revoke")
      :ok = Auth.revoke_credential("claude-local")

      cred = Repo.get_by(RuntimeCredential, runtime_type: "claude-local")
      assert cred.status == "revoked"
    end

    test "returns :ok when no credential exists" do
      assert :ok = Auth.revoke_credential("does-not-exist-xyz")
    end

    test "is idempotent — second revoke is a no-op" do
      {:ok, _} = Auth.store_api_key("claude-local", "key")
      :ok = Auth.revoke_credential("claude-local")
      assert :ok = Auth.revoke_credential("claude-local")
    end
  end

  # ---------------------------------------------------------------------------
  # Device flow (not-supported paths)
  # ---------------------------------------------------------------------------

  describe "start_device_flow/1" do
    test "returns not_supported for claude-local (no published endpoint)" do
      assert {:error, :not_supported} = Auth.start_device_flow("claude-local")
    end

    test "returns not_supported for codex-local" do
      assert {:error, :not_supported} = Auth.start_device_flow("codex-local")
    end

    test "returns not_supported for gemini-local" do
      assert {:error, :not_supported} = Auth.start_device_flow("gemini-local")
    end
  end

  # ---------------------------------------------------------------------------
  # Session env construction
  # ---------------------------------------------------------------------------

  describe "session_env_for/1" do
    test "returns empty map when no credential exists" do
      assert {:ok, %{}} = Auth.session_env_for("no-cred-runtime-abc")
    end

    test "injects ANTHROPIC_API_KEY for claude-local" do
      {:ok, _} = Auth.store_api_key("claude-local", "sk-ant-session-test")
      assert {:ok, env} = Auth.session_env_for("claude-local")
      assert env["ANTHROPIC_API_KEY"] == "sk-ant-session-test"
    end

    test "injects OPENAI_API_KEY for codex-local" do
      {:ok, _} = Auth.store_api_key("codex-local", "sk-openai-session")
      assert {:ok, env} = Auth.session_env_for("codex-local")
      assert env["OPENAI_API_KEY"] == "sk-openai-session"
    end

    test "injects GEMINI_API_KEY for gemini-local" do
      {:ok, _} = Auth.store_api_key("gemini-local", "gemini-key-session")
      assert {:ok, env} = Auth.session_env_for("gemini-local")
      assert env["GEMINI_API_KEY"] == "gemini-key-session"
    end

    test "does not include revoked credentials in session env" do
      {:ok, _} = Auth.store_api_key("claude-local", "revoked-key")
      :ok = Auth.revoke_credential("claude-local")
      assert {:ok, env} = Auth.session_env_for("claude-local")
      refute Map.has_key?(env, "ANTHROPIC_API_KEY")
    end
  end

  # ---------------------------------------------------------------------------
  # RuntimeCredential schema validation
  # ---------------------------------------------------------------------------

  describe "RuntimeCredential.changeset/2" do
    test "requires runtime_type and auth_type" do
      cs = RuntimeCredential.changeset(%RuntimeCredential{}, %{})
      refute cs.valid?
      assert :runtime_type in Keyword.keys(cs.errors)
      assert :auth_type in Keyword.keys(cs.errors)
    end

    test "rejects invalid auth_type" do
      cs =
        RuntimeCredential.changeset(%RuntimeCredential{}, %{
          runtime_type: "claude-local",
          auth_type: "magic_link"
        })

      refute cs.valid?
      assert {:error, _} = Ecto.Changeset.apply_action(cs, :insert)
    end

    test "accepts valid oauth auth_type" do
      cs =
        RuntimeCredential.changeset(%RuntimeCredential{}, %{
          runtime_type: "claude-local",
          auth_type: "oauth"
        })

      assert cs.valid?
    end

    test "accepts valid api_key auth_type" do
      cs =
        RuntimeCredential.changeset(%RuntimeCredential{}, %{
          runtime_type: "claude-local",
          auth_type: "api_key"
        })

      assert cs.valid?
    end
  end
end
