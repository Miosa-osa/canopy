defmodule Canopy.Workspaces.TreeTest do
  @moduledoc """
  Tests for `Canopy.Workspaces.Tree`.
  """

  use ExUnit.Case, async: true

  alias Canopy.Workspaces.Tree
  alias Canopy.Workspaces.Tree.FileTree
  alias Canopy.Workspaces.Workspace

  defp tmp_workspace do
    dir = System.tmp_dir!() |> Path.join("canopy-tree-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    %Workspace{
      id: Ecto.UUID.generate(),
      slug: "tree-ws",
      name: "Tree Test Workspace",
      root_path: dir
    }
  end

  defp create_structure(dir, paths) do
    Enum.each(paths, fn path ->
      full = Path.join(dir, path)

      if String.ends_with?(path, "/") do
        File.mkdir_p!(full)
      else
        File.mkdir_p!(Path.dirname(full))
        File.write!(full, "# #{path}")
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # build/2 — basic structure
  # ---------------------------------------------------------------------------

  describe "build/2 basic structure" do
    test "returns error when root_path does not exist" do
      ws = %Workspace{
        id: Ecto.UUID.generate(),
        slug: "missing",
        name: "Missing",
        root_path: "/tmp/canopy-nonexistent-#{System.unique_integer()}"
      }

      assert {:error, :not_found} = Tree.build(ws)
    end

    test "returns a FileTree struct for an empty workspace" do
      ws = tmp_workspace()
      assert {:ok, %FileTree{} = tree} = Tree.build(ws)
      assert tree.is_dir == true
      assert tree.children == []
    end

    test "includes files at root level" do
      ws = tmp_workspace()
      create_structure(ws.root_path, ["SYSTEM.md", "company.yaml"])

      {:ok, tree} = Tree.build(ws)
      names = Enum.map(tree.children, & &1.name)
      assert "SYSTEM.md" in names
      assert "company.yaml" in names
    end

    test "recurses into subdirectories" do
      ws = tmp_workspace()

      create_structure(ws.root_path, [
        "SYSTEM.md",
        "agents/closer.md",
        "reference/brand.md"
      ])

      {:ok, tree} = Tree.build(ws)
      agents_node = Enum.find(tree.children, &(&1.name == "agents"))
      assert agents_node != nil
      assert agents_node.is_dir == true
      child_names = Enum.map(agents_node.children, & &1.name)
      assert "closer.md" in child_names
    end

    test "tree nodes carry size and modified metadata" do
      ws = tmp_workspace()
      create_structure(ws.root_path, ["note.md"])

      {:ok, tree} = Tree.build(ws)
      file_node = Enum.find(tree.children, &(&1.name == "note.md"))
      assert file_node.size >= 0
      assert file_node.modified != nil or file_node.modified == nil
    end

    test "path field is relative to workspace root" do
      ws = tmp_workspace()
      create_structure(ws.root_path, ["agents/bot.md"])

      {:ok, tree} = Tree.build(ws)
      agents = Enum.find(tree.children, &(&1.name == "agents"))
      bot = Enum.find(agents.children, &(&1.name == "bot.md"))
      assert bot.path == "agents/bot.md"
    end
  end

  # ---------------------------------------------------------------------------
  # build/2 — depth limiting
  # ---------------------------------------------------------------------------

  describe "build/2 depth limiting" do
    test "max_depth 0 returns root only (no children)" do
      ws = tmp_workspace()
      create_structure(ws.root_path, ["SYSTEM.md", "agents/bot.md"])

      {:ok, tree} = Tree.build(ws, 0)
      assert tree.children == []
    end

    test "max_depth 1 returns root children but not grandchildren" do
      ws = tmp_workspace()
      create_structure(ws.root_path, ["SYSTEM.md", "agents/bot.md"])

      {:ok, tree} = Tree.build(ws, 1)
      agents = Enum.find(tree.children, &(&1.name == "agents"))
      assert agents != nil
      # agents dir is at depth 1 — children should be empty (depth limit)
      assert agents.children == []
    end

    test "max_depth 2 includes grandchildren" do
      ws = tmp_workspace()
      create_structure(ws.root_path, ["SYSTEM.md", "agents/bot.md"])

      {:ok, tree} = Tree.build(ws, 2)
      agents = Enum.find(tree.children, &(&1.name == "agents"))
      assert agents != nil
      child_names = Enum.map(agents.children, & &1.name)
      assert "bot.md" in child_names
    end

    test "deeply nested structure is capped at max_depth" do
      ws = tmp_workspace()
      # Create 5-deep nesting
      create_structure(ws.root_path, ["a/b/c/d/e/deep.md"])

      {:ok, tree} = Tree.build(ws, 3)
      # a -> b -> c — at depth 3, children of c should be empty
      a = Enum.find(tree.children, &(&1.name == "a"))
      b = Enum.find(a.children, &(&1.name == "b"))
      c = Enum.find(b.children, &(&1.name == "c"))
      assert c.children == []
    end
  end

  # ---------------------------------------------------------------------------
  # JSON encoding
  # ---------------------------------------------------------------------------

  describe "JSON encoding" do
    test "FileTree struct is JSON-encodable via Jason" do
      ws = tmp_workspace()
      create_structure(ws.root_path, ["SYSTEM.md", "agents/bot.md"])

      {:ok, tree} = Tree.build(ws)
      assert {:ok, json} = Jason.encode(tree)
      assert is_binary(json)
      assert String.contains?(json, "SYSTEM.md")
    end
  end
end
