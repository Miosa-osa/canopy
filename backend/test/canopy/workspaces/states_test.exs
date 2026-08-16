defmodule Canopy.Workspaces.StatesTest do
  @moduledoc """
  Integration tests for `Canopy.Workspaces.States` — the per-workspace
  key/value state store.

  Covers: get/put/delete/list, scope isolation across workspaces, value-size
  cap (1 MB), key-count cap (100/workspace), and `delete_all/1` cascade.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Workspaces
  alias Canopy.Workspaces.States

  defp create_ws(slug \\ nil) do
    slug = slug || "ws-#{System.unique_integer([:positive])}"

    tmp_dir =
      System.tmp_dir!()
      |> Path.join("canopy-states-test-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf(tmp_dir) end)

    {:ok, ws} = Workspaces.create(%{slug: slug, name: "WS #{slug}", root_path: tmp_dir})
    ws
  end

  describe "put/3" do
    test "inserts a new entry" do
      ws = create_ws()

      assert {:ok, state} = States.put(ws.slug, "mosaic.layout", %{"root" => "code"})
      assert state.workspace_slug == ws.slug
      assert state.key == "mosaic.layout"
      assert state.value == %{"root" => "code"}
    end

    test "updates an existing entry idempotently" do
      ws = create_ws()
      {:ok, _first} = States.put(ws.slug, "build.density", "comfortable")
      {:ok, second} = States.put(ws.slug, "build.density", "compact")
      assert second.value == "compact"

      assert {:ok, "compact"} = States.get(ws.slug, "build.density")
    end

    test "rejects values exceeding 1 MB cap" do
      ws = create_ws()
      huge_string = String.duplicate("x", 1_048_577)

      assert {:error, :value_too_large} = States.put(ws.slug, "big.blob", huge_string)
    end

    test "rejects insertion past the 100-keys-per-workspace cap" do
      ws = create_ws()

      for i <- 1..States.max_keys_per_workspace() do
        {:ok, _} = States.put(ws.slug, "k.#{i}", i)
      end

      assert {:error, :too_many_keys} = States.put(ws.slug, "one.too.many", 1)
    end

    test "allows updates to existing keys even when at cap" do
      ws = create_ws()

      for i <- 1..States.max_keys_per_workspace() do
        {:ok, _} = States.put(ws.slug, "k.#{i}", i)
      end

      assert {:ok, _} = States.put(ws.slug, "k.50", 999)
    end
  end

  describe "get/2" do
    test "returns :not_found for missing entries" do
      ws = create_ws()
      assert {:error, :not_found} = States.get(ws.slug, "no.such.key")
    end

    test "returns the stored value" do
      ws = create_ws()
      {:ok, _} = States.put(ws.slug, "files.recentPaths", ["a.md", "b.md"])
      assert {:ok, ["a.md", "b.md"]} = States.get(ws.slug, "files.recentPaths")
    end
  end

  describe "list/1" do
    test "returns empty map when no state exists" do
      ws = create_ws()
      assert States.list(ws.slug) == %{}
    end

    test "returns all key/value pairs for the workspace" do
      ws = create_ws()
      {:ok, _} = States.put(ws.slug, "a", 1)
      {:ok, _} = States.put(ws.slug, "b", 2)

      result = States.list(ws.slug)
      assert result["a"] == 1
      assert result["b"] == 2
      assert map_size(result) == 2
    end
  end

  describe "delete/2" do
    test "removes an existing entry" do
      ws = create_ws()
      {:ok, _} = States.put(ws.slug, "ephemeral", "value")
      assert {:ok, _} = States.delete(ws.slug, "ephemeral")
      assert {:error, :not_found} = States.get(ws.slug, "ephemeral")
    end

    test "returns :not_found if key is absent" do
      ws = create_ws()
      assert {:error, :not_found} = States.delete(ws.slug, "missing")
    end
  end

  describe "scope isolation" do
    test "state in one workspace is invisible to another" do
      a = create_ws("ws-alpha")
      b = create_ws("ws-bravo")

      {:ok, _} = States.put(a.slug, "shared.key", "from-alpha")
      {:ok, _} = States.put(b.slug, "shared.key", "from-bravo")

      assert {:ok, "from-alpha"} = States.get(a.slug, "shared.key")
      assert {:ok, "from-bravo"} = States.get(b.slug, "shared.key")
    end

    test "list/1 only returns entries for the requested workspace" do
      a = create_ws("scope-a")
      b = create_ws("scope-b")

      {:ok, _} = States.put(a.slug, "only.a", 1)
      {:ok, _} = States.put(b.slug, "only.b", 2)

      assert States.list(a.slug) == %{"only.a" => 1}
      assert States.list(b.slug) == %{"only.b" => 2}
    end
  end

  describe "delete_all/1" do
    test "removes every state row for the workspace" do
      ws = create_ws()
      {:ok, _} = States.put(ws.slug, "k1", 1)
      {:ok, _} = States.put(ws.slug, "k2", 2)

      assert {:ok, 2} = States.delete_all(ws.slug)
      assert States.list(ws.slug) == %{}
    end

    test "is a no-op for workspaces with no state" do
      ws = create_ws()
      assert {:ok, 0} = States.delete_all(ws.slug)
    end

    test "does not affect other workspaces" do
      a = create_ws("keep-a")
      b = create_ws("clear-b")

      {:ok, _} = States.put(a.slug, "keep", 1)
      {:ok, _} = States.put(b.slug, "drop", 2)

      assert {:ok, 1} = States.delete_all(b.slug)
      assert States.list(a.slug) == %{"keep" => 1}
    end
  end

  describe "Workspaces.delete_workspace/1 cascade" do
    test "removes the workspace row AND its state entries" do
      ws = create_ws("cascade-target")
      {:ok, _} = States.put(ws.slug, "mosaic.layout", %{"x" => 1})
      {:ok, _} = States.put(ws.slug, "build.density", "compact")

      assert {:ok, %{states_removed: 2}} = Workspaces.delete_workspace(ws.slug)
      assert States.list(ws.slug) == %{}
      assert {:error, :not_found} = Workspaces.get_by_slug(ws.slug)
    end

    test "returns :not_found for unknown workspace" do
      assert {:error, :not_found} = Workspaces.delete_workspace("does-not-exist")
    end
  end
end
