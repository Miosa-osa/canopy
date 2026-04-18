defmodule Canopy.Runtimes.ClaudeLocal.EnvTest do
  @moduledoc """
  Tests for Canopy.Runtimes.ClaudeLocal.Env.build/2.

  Covers credential injection from the vault and context variable mapping.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Runtimes.ClaudeLocal.Env
  alias Canopy.Vault

  defp env_map(env) do
    Map.new(env, fn {k, v} -> {to_string(k), to_string(v)} end)
  end

  describe "build/2 — base variables" do
    test "always includes CANOPY_SESSION_ID" do
      {:ok, env} = Env.build(%{}, "session-abc")
      map = env_map(env)
      assert map["CANOPY_SESSION_ID"] == "session-abc"
    end

    test "always includes nesting guard variables as empty strings" do
      {:ok, env} = Env.build(%{}, "s1")
      map = env_map(env)
      assert Map.has_key?(map, "CLAUDECODE")
      assert Map.has_key?(map, "CLAUDE_CODE_ENTRYPOINT")
      assert Map.has_key?(map, "CLAUDE_CODE_SESSION")
      assert map["CLAUDECODE"] == ""
    end
  end

  describe "build/2 — ANTHROPIC_API_KEY from vault" do
    test "omits ANTHROPIC_API_KEY when vault has no entry" do
      {:ok, env} = Env.build(%{}, "session-1")
      map = env_map(env)
      refute Map.has_key?(map, "ANTHROPIC_API_KEY")
    end

    test "injects ANTHROPIC_API_KEY when vault has a stored key" do
      Vault.put("claude-local", "api_key", "sk-ant-from-vault")
      {:ok, env} = Env.build(%{}, "session-2")
      map = env_map(env)
      assert map["ANTHROPIC_API_KEY"] == "sk-ant-from-vault"
    end

    test "vault key does not appear in context — vault wins over context" do
      Vault.put("claude-local", "api_key", "vault-key")
      # Even if context has something, the vault key is what ends up in env
      {:ok, env} = Env.build(%{"api_key" => "context-key"}, "session-3")
      map = env_map(env)
      assert map["ANTHROPIC_API_KEY"] == "vault-key"
    end
  end

  describe "build/2 — optional context variables" do
    test "injects CANOPY_TASK_ID when present in context" do
      {:ok, env} = Env.build(%{"task_id" => "task-42"}, "s")
      map = env_map(env)
      assert map["CANOPY_TASK_ID"] == "task-42"
    end

    test "omits CANOPY_TASK_ID when absent from context" do
      {:ok, env} = Env.build(%{}, "s")
      map = env_map(env)
      refute Map.has_key?(map, "CANOPY_TASK_ID")
    end

    test "injects CANOPY_WORKSPACE_CWD when cwd is set" do
      {:ok, env} = Env.build(%{"cwd" => "/home/user/project"}, "s")
      map = env_map(env)
      assert map["CANOPY_WORKSPACE_CWD"] == "/home/user/project"
    end

    test "injects CANOPY_MIOSA_SANDBOX_URL when miosa_sandbox_url is set" do
      {:ok, env} = Env.build(%{"miosa_sandbox_url" => "http://sandbox.local"}, "s")
      map = env_map(env)
      assert map["CANOPY_MIOSA_SANDBOX_URL"] == "http://sandbox.local"
    end

    test "env variables are charlist tuples" do
      {:ok, env} = Env.build(%{}, "session-id")

      Enum.each(env, fn {k, v} ->
        assert is_list(k), "key #{inspect(k)} should be a charlist"
        assert is_list(v), "value #{inspect(v)} should be a charlist"
      end)
    end
  end
end
