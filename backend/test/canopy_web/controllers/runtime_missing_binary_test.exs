defmodule CanopyWeb.RuntimeMissingBinaryTest do
  use CanopyWeb.ConnCase, async: false

  test "credential checks report unavailable CLIs without crashing", %{conn: conn} do
    previous = System.get_env("PATH")
    System.put_env("PATH", "/canopy-test-no-executables")

    previous_adapter = Canopy.Runtimes.lookup_adapter("claude-local")
    Canopy.Runtimes.RegistryServer.register(Canopy.Runtimes.ClaudeLocal)

    try do
      response = conn |> post("/api/v1/runtimes/claude-local/test") |> json_response(200)
      assert [%{"level" => "error", "message" => message}] = response["checks"]
      assert message =~ "not installed"

      for type <- ["claude-local", "codex-local", "gemini-local"] do
        response = conn |> post("/api/v1/runtimes/#{type}/auth/test") |> json_response(200)
        assert response["ok"] == false
        assert is_integer(response["latency_ms"])
        assert is_binary(response["error"])
      end
    after
      case previous_adapter do
        {:ok, adapter} -> Canopy.Runtimes.RegistryServer.register(adapter)
        _ -> Canopy.Runtimes.RegistryServer.unregister("claude-local")
      end

      if previous, do: System.put_env("PATH", previous), else: System.delete_env("PATH")
    end
  end
end
