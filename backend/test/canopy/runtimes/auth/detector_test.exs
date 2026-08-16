defmodule Canopy.Runtimes.Auth.DetectorTest do
  @moduledoc """
  Unit tests for Canopy.Runtimes.Auth.Detector.

  Injectable checkers let us test all detection branches without touching the FS
  or running real CLI commands.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Runtimes.Auth.Detector
  alias Canopy.Runtimes.Runtime

  # ── Helpers ─────────────────────────────────────────────────────────────────

  defp build_runtime(type, auth_profile) do
    %Runtime{
      id: Ecto.UUID.generate(),
      type: type,
      kind: "cli",
      name: type,
      enabled: true,
      auth_profile: auth_profile
    }
  end

  defp claude_profile do
    %{
      "methods" => ["subscription_detect", "cli_login", "api_key"],
      "subscription_detect" => %{
        "check_path" => "~/.claude/credentials.json",
        "alt_env_var" => "ANTHROPIC_API_KEY"
      },
      "cli_login" => %{
        "command" => "claude auth login",
        "detect_command" => "claude auth status",
        "detect_success_pattern" => "Logged in as"
      },
      "api_key" => %{
        "env_var" => "ANTHROPIC_API_KEY",
        "signup_url" => "https://console.anthropic.com/settings/keys",
        "placeholder" => "sk-ant-..."
      }
    }
  end

  defp api_only_profile do
    %{
      "methods" => ["api_key"],
      "api_key" => %{
        "env_var" => "GROQ_API_KEY",
        "signup_url" => "https://console.groq.com/keys",
        "placeholder" => "gsk_..."
      }
    }
  end

  # ── Tests ────────────────────────────────────────────────────────────────────

  describe "detect/2 with subscription_detect" do
    test "returns subscription_detected: true when file exists" do
      runtime = build_runtime("claude-local", claude_profile())
      file_checker = fn _path -> true end
      cmd_runner = fn _bin, _args -> :error end

      result = Detector.detect(runtime, file_checker: file_checker, cmd_runner: cmd_runner)

      assert result.subscription_detected == true
      assert result.active_method == "subscription_detect"
    end

    test "returns subscription_detected: false when file does not exist and no env var" do
      runtime = build_runtime("claude-local", claude_profile())
      file_checker = fn _path -> false end
      cmd_runner = fn _bin, _args -> :error end

      result = Detector.detect(runtime, file_checker: file_checker, cmd_runner: cmd_runner)

      assert result.subscription_detected == false
    end

    test "returns nil for subscription_detected when profile has no subscription_detect key" do
      runtime = build_runtime("groq-api", api_only_profile())
      file_checker = fn _path -> false end
      cmd_runner = fn _bin, _args -> :error end

      result = Detector.detect(runtime, file_checker: file_checker, cmd_runner: cmd_runner)

      assert is_nil(result.subscription_detected)
    end
  end

  describe "detect/2 with cli_login" do
    test "returns cli_logged_in: true when command output contains success pattern" do
      runtime = build_runtime("claude-local", claude_profile())
      file_checker = fn _path -> false end

      cmd_runner = fn "claude", ["auth", "status"] ->
        {:ok, "Logged in as roberto@example.com"}
      end

      result = Detector.detect(runtime, file_checker: file_checker, cmd_runner: cmd_runner)

      assert result.cli_logged_in == true
      assert result.active_method == "cli_login"
    end

    test "returns cli_logged_in: false when command output does not match pattern" do
      runtime = build_runtime("claude-local", claude_profile())
      file_checker = fn _path -> false end
      cmd_runner = fn "claude", ["auth", "status"] -> {:ok, "Not logged in"} end

      result = Detector.detect(runtime, file_checker: file_checker, cmd_runner: cmd_runner)

      assert result.cli_logged_in == false
    end

    test "returns cli_logged_in: false when command runner returns :error" do
      runtime = build_runtime("claude-local", claude_profile())
      file_checker = fn _path -> false end
      cmd_runner = fn _bin, _args -> :error end

      result = Detector.detect(runtime, file_checker: file_checker, cmd_runner: cmd_runner)

      assert result.cli_logged_in == false
    end

    test "returns nil for cli_logged_in when profile has no cli_login key" do
      runtime = build_runtime("groq-api", api_only_profile())
      file_checker = fn _path -> false end
      cmd_runner = fn _bin, _args -> :error end

      result = Detector.detect(runtime, file_checker: file_checker, cmd_runner: cmd_runner)

      assert is_nil(result.cli_logged_in)
    end
  end

  describe "detect/2 active_method priority" do
    test "prefers subscription_detect over cli_login when both succeed" do
      runtime = build_runtime("claude-local", claude_profile())
      file_checker = fn _path -> true end

      cmd_runner = fn "claude", ["auth", "status"] ->
        {:ok, "Logged in as roberto@example.com"}
      end

      result = Detector.detect(runtime, file_checker: file_checker, cmd_runner: cmd_runner)

      assert result.active_method == "subscription_detect"
      assert result.subscription_detected == true
      assert result.cli_logged_in == true
    end

    test "falls back to cli_login when subscription not detected" do
      runtime = build_runtime("claude-local", claude_profile())
      file_checker = fn _path -> false end

      cmd_runner = fn "claude", ["auth", "status"] ->
        {:ok, "Logged in as roberto@example.com"}
      end

      result = Detector.detect(runtime, file_checker: file_checker, cmd_runner: cmd_runner)

      assert result.active_method == "cli_login"
    end

    test "returns nil active_method when nothing is detected" do
      runtime = build_runtime("claude-local", claude_profile())
      file_checker = fn _path -> false end
      cmd_runner = fn _bin, _args -> :error end

      result = Detector.detect(runtime, file_checker: file_checker, cmd_runner: cmd_runner)

      assert is_nil(result.active_method)
    end
  end

  describe "detect/2 session_env" do
    test "returns empty session_env when active_method is nil" do
      runtime = build_runtime("claude-local", claude_profile())
      file_checker = fn _path -> false end
      cmd_runner = fn _bin, _args -> :error end

      result = Detector.detect(runtime, file_checker: file_checker, cmd_runner: cmd_runner)

      assert result.session_env == []
    end

    test "returns alt_env_var in session_env when subscription_detect is active" do
      runtime = build_runtime("claude-local", claude_profile())
      file_checker = fn _path -> true end
      cmd_runner = fn _bin, _args -> :error end

      result = Detector.detect(runtime, file_checker: file_checker, cmd_runner: cmd_runner)

      assert result.active_method == "subscription_detect"
      assert "ANTHROPIC_API_KEY" in result.session_env
    end
  end

  describe "detect/2 with nil auth_profile" do
    test "returns empty methods and nil active_method" do
      runtime = %Runtime{
        id: Ecto.UUID.generate(),
        type: "unknown-runtime",
        kind: "cli",
        name: "Unknown",
        enabled: true,
        auth_profile: nil
      }

      result = Detector.detect(runtime)

      assert result.methods == []
      assert is_nil(result.active_method)
      assert result.session_env == []
    end
  end

  describe "detect/2 response shape" do
    test "always includes required keys" do
      runtime = build_runtime("claude-local", claude_profile())

      result =
        Detector.detect(runtime,
          file_checker: fn _ -> false end,
          cmd_runner: fn _, _ -> :error end
        )

      assert Map.has_key?(result, :type)
      assert Map.has_key?(result, :methods)
      assert Map.has_key?(result, :subscription_detected)
      assert Map.has_key?(result, :cli_logged_in)
      assert Map.has_key?(result, :api_key_stored)
      assert Map.has_key?(result, :active_method)
      assert Map.has_key?(result, :session_env)
      assert is_list(result.methods)
      assert is_list(result.session_env)
    end
  end
end
