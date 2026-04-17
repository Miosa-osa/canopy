defmodule Canopy.RuntimesTest do
  @moduledoc """
  Integration tests for the Canopy.Runtimes context module.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Runtimes
  alias Canopy.Runtimes.Runtime

  defp valid_runtime_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        type: "claude-local-#{System.unique_integer([:positive])}",
        kind: "cli",
        name: "Claude Code"
      },
      overrides
    )
  end

  describe "list_adapters/0" do
    test "returns the built-in adapters registered at boot" do
      # RegistryServer auto-registers ClaudeLocal, CodexLocal, GeminiLocal on init.
      # This test verifies the Registry is running and the built-ins are live.
      adapters = Runtimes.list_adapters()
      assert Canopy.Runtimes.ClaudeLocal in adapters
      assert Canopy.Runtimes.CodexLocal in adapters
      assert Canopy.Runtimes.GeminiLocal in adapters
    end
  end

  describe "list/0" do
    test "returns empty list when no runtimes exist" do
      assert {:ok, []} = Runtimes.list()
    end

    test "returns all runtimes" do
      {:ok, _inserted} = Canopy.Repo.insert(Runtime.changeset(%Runtime{}, valid_runtime_attrs()))
      assert {:ok, runtimes} = Runtimes.list()
      assert runtimes != []
    end
  end

  describe "get!/1" do
    test "returns runtime by id" do
      {:ok, r} = Canopy.Repo.insert(Runtime.changeset(%Runtime{}, valid_runtime_attrs()))
      assert Runtimes.get!(r.id).id == r.id
    end

    test "raises on missing id" do
      assert_raise Ecto.NoResultsError, fn ->
        Runtimes.get!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_by_type/1" do
    test "returns runtime by type" do
      {:ok, r} =
        Canopy.Repo.insert(
          Runtime.changeset(%Runtime{}, valid_runtime_attrs(%{type: "aider-local-unique"}))
        )

      assert {:ok, found} = Runtimes.get_by_type("aider-local-unique")
      assert found.id == r.id
    end

    test "returns error when type not found" do
      assert {:error, :not_found} = Runtimes.get_by_type("no-such-type")
    end
  end

  describe "upsert_from_detection/1" do
    test "inserts new runtime on first detection" do
      attrs = %{
        type: "windsurf-local-new",
        kind: "cli",
        name: "Windsurf",
        installed: true,
        version: "0.9.0",
        binary_path: "/usr/local/bin/windsurf"
      }

      assert {:ok, runtime} = Runtimes.upsert_from_detection(attrs)
      assert runtime.installed == true
      assert runtime.version == "0.9.0"
    end

    test "updates existing runtime on re-detection" do
      {:ok, _existing} =
        Canopy.Repo.insert(
          Runtime.changeset(%Runtime{}, %{
            type: "windsurf-local-update",
            kind: "cli",
            name: "Windsurf",
            installed: false,
            version: "0.8.0"
          })
        )

      {:ok, updated} =
        Runtimes.upsert_from_detection(%{
          type: "windsurf-local-update",
          kind: "cli",
          name: "Windsurf",
          installed: true,
          version: "0.9.1"
        })

      assert updated.installed == true
      assert updated.version == "0.9.1"
    end
  end
end
