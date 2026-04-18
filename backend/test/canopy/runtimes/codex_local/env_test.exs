defmodule Canopy.Runtimes.CodexLocal.EnvTest do
  @moduledoc """
  Tests for Canopy.Runtimes.CodexLocal.Env.build/2.

  Covers vault-based credential injection (api_key and base_url).
  """

  use Canopy.DataCase, async: true

  alias Canopy.Runtimes.CodexLocal.Env
  alias Canopy.Vault

  defp env_map(env) do
    Map.new(env, fn {k, v} -> {to_string(k), to_string(v)} end)
  end

  describe "build/2 — OPENAI_API_KEY from vault" do
    test "omits OPENAI_API_KEY when vault has no entry" do
      {:ok, env} = Env.build(%{}, "s1")
      map = env_map(env)
      refute Map.has_key?(map, "OPENAI_API_KEY")
    end

    test "injects OPENAI_API_KEY when vault has a stored key" do
      Vault.put("codex-local", "api_key", "sk-openai-vault")
      {:ok, env} = Env.build(%{}, "s2")
      map = env_map(env)
      assert map["OPENAI_API_KEY"] == "sk-openai-vault"
    end
  end

  describe "build/2 — OPENAI_BASE_URL from vault" do
    test "omits OPENAI_BASE_URL when vault has no entry" do
      {:ok, env} = Env.build(%{}, "s3")
      map = env_map(env)
      refute Map.has_key?(map, "OPENAI_BASE_URL")
    end

    test "injects OPENAI_BASE_URL when vault has a stored url" do
      Vault.put("codex-local", "base_url", "https://custom-openai.example.com")
      {:ok, env} = Env.build(%{}, "s4")
      map = env_map(env)
      assert map["OPENAI_BASE_URL"] == "https://custom-openai.example.com"
    end

    test "injects both api_key and base_url when both are stored" do
      Vault.put("codex-local", "api_key", "sk-openai-both")
      Vault.put("codex-local", "base_url", "https://my-proxy.com")
      {:ok, env} = Env.build(%{}, "s5")
      map = env_map(env)
      assert map["OPENAI_API_KEY"] == "sk-openai-both"
      assert map["OPENAI_BASE_URL"] == "https://my-proxy.com"
    end
  end

  describe "build/2 — base variables" do
    test "always includes CANOPY_SESSION_ID and CODEX_HOME" do
      {:ok, env} = Env.build(%{}, "session-codex")
      map = env_map(env)
      assert map["CANOPY_SESSION_ID"] == "session-codex"
      assert Map.has_key?(map, "CODEX_HOME")
    end
  end
end
