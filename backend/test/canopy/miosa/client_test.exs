defmodule Canopy.Miosa.ClientTest do
  @moduledoc """
  Tests for Canopy.Miosa.Client.

  Uses Req.Test to intercept HTTP calls without a real MIOSA server.
  We inject the plug adapter via `config :canopy, :miosa_req_options` — the
  production key is absent, so no test branches exist in the real client.
  """

  use ExUnit.Case, async: true

  alias Canopy.Miosa.Client

  # Register a unique stub name per test to allow async: true
  setup do
    stub_name = :"miosa_stub_#{System.unique_integer([:positive])}"

    Application.put_env(:canopy, :miosa_api_url, "http://miosa.test")
    Application.put_env(:canopy, :miosa_api_key, "test-key-abc123")
    Application.put_env(:canopy, :miosa_req_options, plug: {Req.Test, stub_name})

    on_exit(fn ->
      Application.put_env(:canopy, :miosa_api_url, "")
      Application.put_env(:canopy, :miosa_api_key, "")
      Application.delete_env(:canopy, :miosa_req_options)
    end)

    {:ok, stub_name: stub_name}
  end

  # ---------------------------------------------------------------------------
  # provision_sandbox/1
  # ---------------------------------------------------------------------------

  describe "provision_sandbox/1" do
    test "returns {:ok, sandbox_result} on 201 response", %{stub_name: name} do
      Req.Test.stub(name, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/sandboxes"

        response = %{
          "sandbox_id" => "sbx-abc123",
          "url" => "https://sbx.miosa.dev/abc123",
          "status" => "provisioning"
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(response))
      end)

      assert {:ok, result} = Client.provision_sandbox(template: "default")
      assert result.sandbox_id == "sbx-abc123"
      assert result.url == "https://sbx.miosa.dev/abc123"
      assert result.status == "provisioning"
    end

    test "sends correct JSON body", %{stub_name: name} do
      Req.Test.stub(name, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["template"] == "gpu-vm"
        assert decoded["ttl_seconds"] == 7200

        response = %{
          "sandbox_id" => "sbx-gpu",
          "url" => "https://sbx.miosa.dev/gpu",
          "status" => "provisioning"
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(response))
      end)

      assert {:ok, _} = Client.provision_sandbox(template: "gpu-vm", ttl_seconds: 7200)
    end

    test "returns {:error, {status, body}} on 422", %{stub_name: name} do
      Req.Test.stub(name, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(422, Jason.encode!(%{"error" => "invalid_template"}))
      end)

      assert {:error, {422, _body}} = Client.provision_sandbox([])
    end

    test "returns {:error, :unexpected_response} when sandbox_id missing", %{stub_name: name} do
      Req.Test.stub(name, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"oops" => "no fields"}))
      end)

      assert {:error, {:unexpected_response, _}} = Client.provision_sandbox([])
    end
  end

  # ---------------------------------------------------------------------------
  # get_sandbox/1
  # ---------------------------------------------------------------------------

  describe "get_sandbox/1" do
    test "returns {:ok, sandbox_result} on 200", %{stub_name: name} do
      Req.Test.stub(name, fn conn ->
        assert conn.method == "GET"
        assert String.ends_with?(conn.request_path, "/sbx-get-test")

        response = %{
          "sandbox_id" => "sbx-get-test",
          "url" => "https://sbx.miosa.dev/get",
          "status" => "ready"
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(response))
      end)

      assert {:ok, result} = Client.get_sandbox("sbx-get-test")
      assert result.sandbox_id == "sbx-get-test"
      assert result.status == "ready"
    end

    test "returns {:error, :not_found} on 404", %{stub_name: name} do
      Req.Test.stub(name, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"error" => "not_found"}))
      end)

      assert {:error, :not_found} = Client.get_sandbox("sbx-missing")
    end

    test "returns {:error, {500, _}} on server error", %{stub_name: name} do
      Req.Test.stub(name, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "internal"}))
      end)

      assert {:error, {500, _}} = Client.get_sandbox("sbx-broken")
    end
  end

  # ---------------------------------------------------------------------------
  # exec/3
  # ---------------------------------------------------------------------------

  describe "exec/3" do
    test "returns {:ok, result} on 200", %{stub_name: name} do
      Req.Test.stub(name, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/exec")

        result = %{"exit_code" => 0, "stdout" => "hello\n", "stderr" => ""}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(result))
      end)

      assert {:ok, result} = Client.exec("sbx-exec", "echo hello")
      assert result["exit_code"] == 0
      assert result["stdout"] == "hello\n"
    end

    test "sends command and env in request body", %{stub_name: name} do
      Req.Test.stub(name, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["command"] == "ls -la"
        assert decoded["env"] == %{"MY_VAR" => "value"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{"exit_code" => 0, "stdout" => "", "stderr" => ""})
        )
      end)

      assert {:ok, _} = Client.exec("sbx-env", "ls -la", env: %{"MY_VAR" => "value"})
    end

    test "returns {:error, :not_found} on 404", %{stub_name: name} do
      Req.Test.stub(name, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"error" => "not_found"}))
      end)

      assert {:error, :not_found} = Client.exec("sbx-gone", "ls")
    end
  end

  # ---------------------------------------------------------------------------
  # destroy_sandbox/1
  # ---------------------------------------------------------------------------

  describe "destroy_sandbox/1" do
    test "returns :ok on 204", %{stub_name: name} do
      Req.Test.stub(name, fn conn ->
        assert conn.method == "DELETE"
        assert String.ends_with?(conn.request_path, "/sbx-del")

        Plug.Conn.send_resp(conn, 204, "")
      end)

      assert :ok = Client.destroy_sandbox("sbx-del")
    end

    test "returns :ok on 200 with body", %{stub_name: name} do
      Req.Test.stub(name, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"deleted" => true}))
      end)

      assert :ok = Client.destroy_sandbox("sbx-del-200")
    end

    test "returns {:error, :not_found} on 404", %{stub_name: name} do
      Req.Test.stub(name, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"error" => "not_found"}))
      end)

      assert {:error, :not_found} = Client.destroy_sandbox("sbx-missing")
    end

    test "returns {:error, {500, _}} on server error", %{stub_name: name} do
      Req.Test.stub(name, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "boom"}))
      end)

      assert {:error, {500, _}} = Client.destroy_sandbox("sbx-err")
    end
  end
end
