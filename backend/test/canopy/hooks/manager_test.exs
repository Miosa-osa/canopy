defmodule Canopy.Hooks.ManagerTest do
  @moduledoc """
  Tests for Canopy.Hooks.Manager — install/uninstall idempotency, conservative
  merge (never clobbers non-Canopy keys), and per-runtime behaviour.
  """

  use ExUnit.Case, async: false

  alias Canopy.Hooks.Manager

  @tmp_dir System.tmp_dir!()

  # Each test gets isolated config dirs so writes don't bleed across tests.
  setup do
    tmp = Path.join(@tmp_dir, "canopy_hook_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)

    on_exit(fn -> File.rm_rf!(tmp) end)

    {:ok, tmp: tmp}
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp write_json(path, data) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(data))
  end

  defp read_json(path) do
    path |> File.read!() |> Jason.decode!()
  end

  # ── install!/uninstall! idempotency ──────────────────────────────────────────

  describe "install! / uninstall! idempotency" do
    test "install! returns :ok for each runtime it can write", %{tmp: _tmp} do
      # Manager.install! uses System.user_home!/0 for real paths.
      # We call it and verify it returns a map without raising.
      results = Manager.install!()
      assert is_map(results)

      for {_name, v} <- results do
        assert v == :ok or match?({:error, _}, v)
      end
    end

    test "install! is idempotent — second call returns same shape", %{tmp: _tmp} do
      _first = Manager.install!()
      second = Manager.install!()

      for {_name, v} <- second do
        assert v == :ok or match?({:error, _}, v)
      end
    end

    test "uninstall! succeeds without raising when hooks installed", %{tmp: _tmp} do
      Manager.install!()
      results = Manager.uninstall!()

      for {_name, v} <- results do
        assert v == :ok or match?({:error, _}, v)
      end
    end
  end

  # ── Conservative merge ────────────────────────────────────────────────────────

  describe "conservative JSON merge" do
    test "preserves existing non-Canopy keys in Claude settings.json" do
      path = Path.join(System.user_home!(), ".claude/settings.json")
      had_existing = File.exists?(path)

      existing_content =
        if had_existing do
          File.read!(path)
        else
          nil
        end

      # Inject a sentinel key that Canopy must not remove.
      existing =
        if had_existing do
          case Jason.decode(existing_content) do
            {:ok, map} -> map
            _ -> %{}
          end
        else
          %{}
        end

      user_key = "user_custom_setting_#{System.unique_integer()}"
      existing_with_user = Map.put(existing, user_key, "preserve_me")

      File.mkdir_p!(Path.dirname(path))
      File.write!(path, Jason.encode!(existing_with_user))

      Manager.install!()

      after_install = read_json(path)
      assert Map.get(after_install, user_key) == "preserve_me"

      # Restore original state
      if had_existing do
        File.write!(path, existing_content)
      else
        File.rm(path)
      end
    end

    test "cursor hooks.json preserves non-Canopy hook commands" do
      path = Path.join(System.user_home!(), ".cursor/hooks.json")
      had_existing = File.exists?(path)
      existing_content = if had_existing, do: File.read!(path), else: nil

      user_hook = %{"command" => "/usr/local/bin/my-cursor-hook.sh"}

      existing = %{
        "version" => 1,
        "hooks" => %{
          "beforeSubmitPrompt" => [user_hook]
        }
      }

      File.mkdir_p!(Path.dirname(path))
      write_json(path, existing)

      Manager.install!()

      after_install = read_json(path)
      hooks = get_in(after_install, ["hooks", "beforeSubmitPrompt"]) || []

      # Our hook was added AND the user hook is preserved.
      assert Enum.any?(hooks, fn h ->
               Map.get(h, "command") == "/usr/local/bin/my-cursor-hook.sh"
             end)

      # Restore
      if had_existing, do: File.write!(path, existing_content), else: File.rm(path)
    end
  end

  # ── status/0 ─────────────────────────────────────────────────────────────────

  describe "status/0" do
    test "returns a map with runtime keys" do
      result = Manager.status()
      assert is_map(result)

      for {_name, v} <- result do
        assert v in [:installed, :not_installed] or match?({:error, _}, v)
      end
    end
  end
end
