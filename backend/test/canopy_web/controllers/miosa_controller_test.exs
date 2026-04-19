defmodule CanopyWeb.MiosaControllerTest do
  @moduledoc """
  Controller tests for /api/v1/miosa/health, /api/v1/miosa, and
  /api/v1/settings/miosa endpoints.
  """

  use CanopyWeb.ConnCase, async: false

  import Mox

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # GET /api/v1/miosa/health — configured + reachable
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/miosa/health — when MIOSA is configured" do
    setup do
      Application.put_env(:canopy, :miosa_api_url, "http://miosa.test")
      Application.put_env(:canopy, :miosa_api_key, "test-key-12345")
      on_exit(fn -> clear_miosa_config() end)
      :ok
    end

    test "returns configured: true, reachable: true on successful ping", %{conn: conn} do
      Mox.expect(Canopy.Miosa.MockClient, :ping, fn _opts -> {:ok, 42} end)

      conn = get(conn, "/api/v1/miosa/health")
      body = json_response(conn, 200)

      assert body["configured"] == true
      assert body["reachable"] == true
      assert is_integer(body["latency_ms"])
      assert body["error"] == nil
    end

    test "returns configured: true, reachable: false on ping failure", %{conn: conn} do
      Mox.expect(Canopy.Miosa.MockClient, :ping, fn _opts ->
        {:error, :connection_refused}
      end)

      conn = get(conn, "/api/v1/miosa/health")
      body = json_response(conn, 200)

      assert body["configured"] == true
      assert body["reachable"] == false
      assert body["latency_ms"] == nil
      assert is_binary(body["error"])
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/miosa/health — not configured
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/miosa/health — when MIOSA is not configured" do
    setup do
      Application.put_env(:canopy, :miosa_api_url, "")
      Application.put_env(:canopy, :miosa_api_key, "")
      on_exit(fn -> clear_miosa_config() end)
      :ok
    end

    test "returns configured: false without calling ping", %{conn: conn} do
      # No Mox expectation — ping must NOT be called when not configured.
      conn = get(conn, "/api/v1/miosa/health")
      body = json_response(conn, 200)

      assert body["configured"] == false
      assert body["reachable"] == nil
      assert body["latency_ms"] == nil
      assert body["error"] == nil
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/miosa — config read with redacted key
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/miosa" do
    setup do
      Application.put_env(:canopy, :miosa_api_url, "http://miosa.example.com")
      Application.put_env(:canopy, :miosa_api_key, "sk-secretkey9999")
      on_exit(fn -> clear_miosa_config() end)
      :ok
    end

    test "returns api_url plaintext and api_key_masked redacted", %{conn: conn} do
      conn = get(conn, "/api/v1/miosa")
      body = json_response(conn, 200)

      assert body["api_url"] == "http://miosa.example.com"
      assert body["configured"] == true
      # Key must not be returned in plaintext
      refute body["api_key_masked"] == "sk-secretkey9999"
      # Must have masked form
      assert String.contains?(body["api_key_masked"], "****")
    end

    test "returns empty api_url and configured: false when not configured", %{conn: conn} do
      Application.put_env(:canopy, :miosa_api_url, "")
      Application.put_env(:canopy, :miosa_api_key, "")

      conn = get(conn, "/api/v1/miosa")
      body = json_response(conn, 200)

      assert body["configured"] == false
      assert body["api_url"] == ""
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /api/v1/settings/miosa
  # ---------------------------------------------------------------------------

  describe "PUT /api/v1/settings/miosa" do
    setup do
      on_exit(fn -> clear_miosa_config() end)
      :ok
    end

    test "saves credentials and returns masked config", %{conn: conn} do
      params = %{api_url: "https://api.miosa.io", api_key: "sk-newkey12345"}

      conn = put(conn, "/api/v1/settings/miosa", params)
      body = json_response(conn, 200)

      assert body["api_url"] == "https://api.miosa.io"
      assert body["configured"] == true
      refute body["api_key_masked"] == "sk-newkey12345"
      assert String.contains?(body["api_key_masked"], "****")
    end

    test "trims whitespace from api_url", %{conn: conn} do
      params = %{api_url: "  https://api.miosa.io  ", api_key: "sk-key"}

      conn = put(conn, "/api/v1/settings/miosa", params)
      body = json_response(conn, 200)

      assert body["api_url"] == "https://api.miosa.io"
    end

    test "returns 422 when api_url is missing", %{conn: conn} do
      conn = put(conn, "/api/v1/settings/miosa", %{api_key: "sk-key"})
      assert json_response(conn, 422)
    end

    test "returns 422 when api_url is empty string", %{conn: conn} do
      conn = put(conn, "/api/v1/settings/miosa", %{api_url: "", api_key: "sk-key"})
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp clear_miosa_config do
    Application.put_env(:canopy, :miosa_api_url, "")
    Application.put_env(:canopy, :miosa_api_key, "")
  end
end
