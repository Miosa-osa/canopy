defmodule Canopy.Runtimes.GeminiLocal.EnvTest do
  @moduledoc """
  Tests for Canopy.Runtimes.GeminiLocal.Env.build/2.

  Covers vault-based GEMINI_API_KEY / GOOGLE_API_KEY injection.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Runtimes.GeminiLocal.Env
  alias Canopy.Vault

  defp env_map(env) do
    Map.new(env, fn {k, v} -> {to_string(k), to_string(v)} end)
  end

  describe "build/2 — GEMINI_API_KEY from vault" do
    test "omits both API key vars when vault has no entry" do
      {:ok, env} = Env.build(%{}, "s1")
      map = env_map(env)
      refute Map.has_key?(map, "GEMINI_API_KEY")
      refute Map.has_key?(map, "GOOGLE_API_KEY")
    end

    test "injects both GEMINI_API_KEY and GOOGLE_API_KEY when vault has a stored key" do
      Vault.put("gemini-local", "api_key", "AIza-gemini-vault")
      {:ok, env} = Env.build(%{}, "s2")
      map = env_map(env)
      assert map["GEMINI_API_KEY"] == "AIza-gemini-vault"
      assert map["GOOGLE_API_KEY"] == "AIza-gemini-vault"
    end

    test "does not inject from context api_key when vault is empty" do
      # Old context-based injection is removed — vault is the source of truth
      {:ok, env} = Env.build(%{"api_key" => "context-key"}, "s3")
      map = env_map(env)
      refute Map.has_key?(map, "GEMINI_API_KEY")
    end
  end

  describe "build/2 — base variables" do
    test "always includes CANOPY_SESSION_ID" do
      {:ok, env} = Env.build(%{}, "gemini-session")
      map = env_map(env)
      assert map["CANOPY_SESSION_ID"] == "gemini-session"
    end
  end
end
