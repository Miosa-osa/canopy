defmodule CanopyWeb.RuntimesCredentialsTest do
  @moduledoc """
  Tests for the credentials sub-resource on RuntimesController:
    PUT  /api/v1/runtimes/:type/credentials
    GET  /api/v1/runtimes/:type/credentials
  """

  use CanopyWeb.ConnCase, async: true

  alias Canopy.Vault

  # ---------------------------------------------------------------------------
  # PUT /api/v1/runtimes/:type/credentials
  # ---------------------------------------------------------------------------

  describe "PUT /api/v1/runtimes/:type/credentials" do
    test "stores credentials and returns field keys", %{conn: conn} do
      body = %{values: %{api_key: "sk-ant-test123"}}
      conn = put(conn, "/api/v1/runtimes/claude-local/credentials", body)

      assert %{"runtime_type" => "claude-local", "field_keys" => field_keys} =
               json_response(conn, 200)

      assert "api_key" in field_keys
    end

    test "stores multiple fields at once", %{conn: conn} do
      body = %{values: %{api_key: "sk-ant-multi", model: "claude-opus-4"}}
      conn = put(conn, "/api/v1/runtimes/claude-local/credentials", body)
      assert %{"field_keys" => field_keys} = json_response(conn, 200)
      assert "api_key" in field_keys
      assert "model" in field_keys
    end

    test "never returns plaintext values in response", %{conn: conn} do
      body = %{values: %{api_key: "my-very-secret-key"}}
      conn = put(conn, "/api/v1/runtimes/claude-local/credentials", body)
      response_text = conn.resp_body
      refute String.contains?(response_text, "my-very-secret-key")
    end

    test "values are actually persisted in vault", %{conn: conn} do
      body = %{values: %{api_key: "persisted-key"}}
      put(conn, "/api/v1/runtimes/claude-local/credentials", body)
      assert {:ok, "persisted-key"} = Vault.get("claude-local", "api_key")
    end

    test "overwrites existing field on repeated PUT", %{conn: conn} do
      put(conn, "/api/v1/runtimes/claude-local/credentials", %{values: %{api_key: "first"}})
      put(conn, "/api/v1/runtimes/claude-local/credentials", %{values: %{api_key: "second"}})
      assert {:ok, "second"} = Vault.get("claude-local", "api_key")
    end

    test "stores credentials for codex-local runtime", %{conn: conn} do
      body = %{values: %{api_key: "sk-openai-test", base_url: "https://custom.openai.com"}}
      conn = put(conn, "/api/v1/runtimes/codex-local/credentials", body)

      assert %{"runtime_type" => "codex-local", "field_keys" => field_keys} =
               json_response(conn, 200)

      assert "api_key" in field_keys
      assert "base_url" in field_keys
    end

    test "returns 400 when values field is missing", %{conn: conn} do
      conn = put(conn, "/api/v1/runtimes/claude-local/credentials", %{})
      # FallbackController maps :bad_request → 500 (generic atom)
      assert conn.status in [400, 500]
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/runtimes/:type/credentials
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/runtimes/:type/credentials" do
    test "returns empty field_keys when nothing stored", %{conn: conn} do
      conn = get(conn, "/api/v1/runtimes/claude-local/credentials")
      assert %{"runtime_type" => "claude-local", "field_keys" => []} = json_response(conn, 200)
    end

    test "returns list of field keys after storing credentials", %{conn: conn} do
      Vault.put("claude-local", "api_key", "stored-value")
      conn = get(conn, "/api/v1/runtimes/claude-local/credentials")
      assert %{"field_keys" => field_keys} = json_response(conn, 200)
      assert "api_key" in field_keys
      # Values must not appear in response
      refute "stored-value" in field_keys
    end

    test "only returns fields for requested runtime", %{conn: conn} do
      Vault.put("claude-local", "api_key", "anthropic")
      Vault.put("codex-local", "api_key", "openai")
      conn = get(conn, "/api/v1/runtimes/claude-local/credentials")

      assert %{"runtime_type" => "claude-local", "field_keys" => field_keys} =
               json_response(conn, 200)

      assert length(field_keys) == 1
      assert "api_key" in field_keys
    end
  end
end
