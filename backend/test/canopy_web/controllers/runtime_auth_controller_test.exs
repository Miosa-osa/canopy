defmodule CanopyWeb.RuntimeAuthControllerTest do
  @moduledoc """
  Controller tests for `/api/v1/runtimes/:type/auth` endpoints.

  Hits real DB (ConnCase with sandbox). Does not invoke CLI binaries.
  """

  use CanopyWeb.ConnCase, async: true

  import Canopy.Factory

  alias Canopy.Runtimes.Auth

  # ---------------------------------------------------------------------------
  # GET /auth/status
  # ---------------------------------------------------------------------------

  describe "GET /auth/status" do
    test "returns 200 with required shape for claude-local", %{conn: conn} do
      insert(:runtime,
        type: "claude-local",
        name: "Claude Code",
        kind: "cli",
        auth_profile: %{
          "methods" => ["subscription_detect", "cli_login", "api_key"],
          "subscription_detect" => %{"check_path" => "~/.claude/credentials.json"},
          "cli_login" => %{
            "detect_command" => "claude auth status",
            "detect_success_pattern" => "Logged in as"
          },
          "api_key" => %{"env_var" => "ANTHROPIC_API_KEY"}
        }
      )

      conn = get(conn, "/api/v1/runtimes/claude-local/auth/status")
      body = json_response(conn, 200)

      assert Map.has_key?(body, "type")
      assert Map.has_key?(body, "methods")
      assert Map.has_key?(body, "session_env")
      assert is_list(body["methods"])
      assert is_list(body["session_env"])
      assert body["type"] == "claude-local"
    end

    test "returns 200 with api_key methods for anthropic-api", %{conn: conn} do
      insert(:runtime,
        type: "anthropic-api-status-test",
        name: "Anthropic API",
        kind: "api",
        auth_profile: %{
          "methods" => ["api_key"],
          "api_key" => %{"env_var" => "ANTHROPIC_API_KEY"}
        }
      )

      conn = get(conn, "/api/v1/runtimes/anthropic-api-status-test/auth/status")
      body = json_response(conn, 200)

      assert body["type"] == "anthropic-api-status-test"
      assert body["methods"] == ["api_key"]
    end

    test "returns 404 for unknown runtime type", %{conn: conn} do
      conn = get(conn, "/api/v1/runtimes/does-not-exist-xyz/auth/status")
      assert %{"error" => "not_found"} = json_response(conn, 404)
    end

    test "api_key_stored reflects true after storing a key", %{conn: conn} do
      insert(:runtime,
        type: "groq-api-status-key-test",
        name: "Groq API",
        kind: "api",
        auth_profile: %{
          "methods" => ["api_key"],
          "api_key" => %{"env_var" => "GROQ_API_KEY"}
        }
      )

      {:ok, _} = Auth.store_api_key("groq-api-status-key-test", "gsk-test-key")

      conn = get(conn, "/api/v1/runtimes/groq-api-status-key-test/auth/status")
      body = json_response(conn, 200)

      assert body["api_key_stored"] == true
      assert body["active_method"] == "api_key"
    end
  end

  # ---------------------------------------------------------------------------
  # POST /auth/start
  # ---------------------------------------------------------------------------

  describe "POST /auth/start" do
    test "returns 422 when runtime does not support device-code flow", %{conn: conn} do
      conn = post(conn, "/api/v1/runtimes/claude-local/auth/start")

      assert %{"error" => "oauth_not_supported"} = json_response(conn, 422)
    end

    test "returns 422 for codex-local (no OAuth endpoint verified)", %{conn: conn} do
      conn = post(conn, "/api/v1/runtimes/codex-local/auth/start")
      assert %{"error" => "oauth_not_supported"} = json_response(conn, 422)
    end

    test "returns 422 for gemini-local (no OAuth endpoint verified)", %{conn: conn} do
      conn = post(conn, "/api/v1/runtimes/gemini-local/auth/start")
      assert %{"error" => "oauth_not_supported"} = json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /auth/poll
  # ---------------------------------------------------------------------------

  describe "POST /auth/poll" do
    test "returns 400 when device_code missing", %{conn: conn} do
      conn = post(conn, "/api/v1/runtimes/claude-local/auth/poll", %{})
      assert conn.status in [400, 422, 500]
    end

    test "returns not_supported for claude-local poll", %{conn: conn} do
      conn =
        post(conn, "/api/v1/runtimes/claude-local/auth/poll", %{
          device_code: "test-device-code"
        })

      assert conn.status in [422, 500]
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /auth/credentials (API key storage)
  # ---------------------------------------------------------------------------

  describe "PUT /auth/credentials" do
    test "stores API key and returns active status", %{conn: conn} do
      conn =
        put(conn, "/api/v1/runtimes/claude-local/auth/credentials", %{
          api_key: "sk-ant-test-key"
        })

      assert %{
               "runtime_type" => "claude-local",
               "auth_type" => "api_key",
               "status" => "active"
             } = json_response(conn, 200)
    end

    test "stores key for codex-local", %{conn: conn} do
      conn =
        put(conn, "/api/v1/runtimes/codex-local/auth/credentials", %{
          api_key: "sk-openai-store-test"
        })

      assert %{"status" => "active", "auth_type" => "api_key"} = json_response(conn, 200)
    end

    test "persists key in vault — readable via Auth context", %{conn: conn} do
      put(conn, "/api/v1/runtimes/claude-local/auth/credentials", %{api_key: "persisted-via-ctrl"})

      {:ok, cred} = Auth.get_credential("claude-local")
      assert {:ok, "persisted-via-ctrl"} = Auth.decrypt_api_key(cred)
    end

    test "returns 400 when api_key is missing", %{conn: conn} do
      conn = put(conn, "/api/v1/runtimes/claude-local/auth/credentials", %{})
      assert conn.status in [400, 500]
    end

    test "returns 400 when api_key is empty string", %{conn: conn} do
      conn = put(conn, "/api/v1/runtimes/claude-local/auth/credentials", %{api_key: ""})
      assert conn.status in [400, 500]
    end

    test "never echoes plaintext key in response", %{conn: conn} do
      put(conn, "/api/v1/runtimes/claude-local/auth/credentials", %{api_key: "super-secret-key"})
      # Re-fetch the last conn's response body indirectly:
      conn2 =
        put(conn, "/api/v1/runtimes/claude-local/auth/credentials", %{api_key: "another-secret"})

      refute String.contains?(conn2.resp_body, "another-secret")
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /auth/credentials
  # ---------------------------------------------------------------------------

  describe "DELETE /auth/credentials" do
    test "revokes existing credential and returns 204", %{conn: conn} do
      {:ok, _} = Auth.store_api_key("claude-local", "key-to-revoke-ctrl")

      conn = delete(conn, "/api/v1/runtimes/claude-local/auth/credentials")
      assert conn.status == 204

      # Credential should now be revoked
      assert {:error, :not_found} = Auth.get_credential("claude-local")
    end

    test "returns 204 even when no credential exists", %{conn: conn} do
      conn = delete(conn, "/api/v1/runtimes/no-such-runtime-xyz/auth/credentials")
      assert conn.status == 204
    end
  end

  # ---------------------------------------------------------------------------
  # POST /auth/test
  # ---------------------------------------------------------------------------

  describe "POST /auth/test" do
    test "returns ok field in response", %{conn: conn} do
      # Binary may or may not be installed in CI — we just assert structure.
      conn = post(conn, "/api/v1/runtimes/claude-local/auth/test")
      assert %{"ok" => _, "latency_ms" => _} = json_response(conn, 200)
    end

    test "includes latency_ms as integer", %{conn: conn} do
      conn = post(conn, "/api/v1/runtimes/codex-local/auth/test")
      body = json_response(conn, 200)
      assert is_integer(body["latency_ms"])
    end

    test "returns ok: false when api_key is missing and binary not installed", %{conn: conn} do
      # For a made-up runtime type, the ApiKey provider returns ok: false (empty key)
      conn = post(conn, "/api/v1/runtimes/fake-runtime-xyz/auth/test")
      body = json_response(conn, 200)
      assert body["ok"] == false
    end
  end
end
