defmodule Canopy.Tools.BuiltInTest do
  @moduledoc """
  Tests for `Canopy.Tools.BuiltIn` — the 6 shipped tools.

  Covers: macro-generated `__canopy_tools__/0`, handler behavior for each
  tool including error cases, and path-traversal guards.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Tools.BuiltIn

  # ---------------------------------------------------------------------------
  # Macro introspection
  # ---------------------------------------------------------------------------

  describe "__canopy_tools__/0" do
    test "returns a list of Tool structs" do
      tools = BuiltIn.__canopy_tools__()
      assert is_list(tools)
      assert length(tools) >= 6
    end

    test "all tools have required fields populated" do
      for tool <- BuiltIn.__canopy_tools__() do
        assert is_binary(tool.name) and byte_size(tool.name) > 0,
               "tool #{inspect(tool.name)} missing name"

        assert is_binary(tool.description) and byte_size(tool.description) > 0,
               "tool #{tool.name} missing description"

        assert is_map(tool.parameters), "tool #{tool.name} parameters not a map"
        assert is_tuple(tool.handler), "tool #{tool.name} handler not a tuple"
      end
    end

    test "includes the 6 expected tool names" do
      names = BuiltIn.__canopy_tools__() |> Enum.map(& &1.name)
      assert "read_file" in names
      assert "list_directory" in names
      assert "search_workspace" in names
      assert "get_session_context" in names
      assert "log_message" in names
      assert "create_comment" in names
    end

    test "read_file and list_directory require :filesystem capability" do
      by_name = Map.new(BuiltIn.__canopy_tools__(), fn t -> {t.name, t} end)
      assert :filesystem in by_name["read_file"].requires
      assert :filesystem in by_name["list_directory"].requires
    end

    test "read_file schema declares workspace_slug as required" do
      by_name = Map.new(BuiltIn.__canopy_tools__(), fn t -> {t.name, t} end)
      required = get_in(by_name["read_file"].parameters, ["required"])
      assert "workspace_slug" in required
    end

    test "list_directory schema declares workspace_slug as required" do
      by_name = Map.new(BuiltIn.__canopy_tools__(), fn t -> {t.name, t} end)
      required = get_in(by_name["list_directory"].parameters, ["required"])
      assert "workspace_slug" in required
    end
  end

  # ---------------------------------------------------------------------------
  # read_file/1 — workspace-scoped
  # ---------------------------------------------------------------------------

  describe "read_file/1" do
    test "rejects call with missing workspace_slug" do
      assert {:error, :missing_workspace_slug} = BuiltIn.read_file(%{"path" => "README.md"})
    end

    test "rejects call with empty workspace_slug" do
      assert {:error, :missing_workspace_slug} =
               BuiltIn.read_file(%{"workspace_slug" => "", "path" => "README.md"})
    end

    test "returns workspace_not_found for an unknown slug" do
      assert {:error, :workspace_not_found} =
               BuiltIn.read_file(%{
                 "workspace_slug" => "no-such-workspace-xyz",
                 "path" => "file.txt"
               })
    end

    test "reads a file inside the workspace" do
      root = Path.join(System.tmp_dir!(), "canopy_ws_read_#{System.unique_integer([:positive])}")
      File.mkdir_p!(root)
      File.write!(Path.join(root, "hello.txt"), "workspace content")
      on_exit(fn -> File.rm_rf!(root) end)

      slug = "ws-read-#{System.unique_integer([:positive])}"

      {:ok, _ws} =
        Canopy.Workspaces.create(%{
          slug: slug,
          name: "Read Test Workspace",
          root_path: root
        })

      assert {:ok, "workspace content"} =
               BuiltIn.read_file(%{"workspace_slug" => slug, "path" => "hello.txt"})
    end

    test "rejects path traversal inside a valid workspace" do
      root = Path.join(System.tmp_dir!(), "canopy_ws_trav_#{System.unique_integer([:positive])}")
      File.mkdir_p!(root)
      on_exit(fn -> File.rm_rf!(root) end)

      slug = "ws-trav-#{System.unique_integer([:positive])}"

      {:ok, _ws} =
        Canopy.Workspaces.create(%{
          slug: slug,
          name: "Traversal Test Workspace",
          root_path: root
        })

      # Attempt to escape workspace root via ../
      assert {:error, :path_traversal} =
               BuiltIn.read_file(%{"workspace_slug" => slug, "path" => "../etc/passwd"})
    end

    test "rejects absolute path inside a valid workspace" do
      root = Path.join(System.tmp_dir!(), "canopy_ws_abs_#{System.unique_integer([:positive])}")
      File.mkdir_p!(root)
      on_exit(fn -> File.rm_rf!(root) end)

      slug = "ws-abs-#{System.unique_integer([:positive])}"

      {:ok, _ws} =
        Canopy.Workspaces.create(%{
          slug: slug,
          name: "Absolute Path Test Workspace",
          root_path: root
        })

      assert {:error, :path_traversal} =
               BuiltIn.read_file(%{"workspace_slug" => slug, "path" => "/etc/passwd"})
    end
  end

  # ---------------------------------------------------------------------------
  # list_directory/1 — workspace-scoped
  # ---------------------------------------------------------------------------

  describe "list_directory/1" do
    test "rejects call with missing workspace_slug" do
      assert {:error, :missing_workspace_slug} =
               BuiltIn.list_directory(%{"path" => "subdir"})
    end

    test "returns workspace_not_found for an unknown slug" do
      assert {:error, :workspace_not_found} =
               BuiltIn.list_directory(%{"workspace_slug" => "no-such-ws-xyz"})
    end

    test "lists files at the workspace root" do
      root = Path.join(System.tmp_dir!(), "canopy_ws_ls_#{System.unique_integer([:positive])}")
      File.mkdir_p!(root)
      File.write!(Path.join(root, "a.txt"), "")
      File.write!(Path.join(root, "b.txt"), "")
      on_exit(fn -> File.rm_rf!(root) end)

      slug = "ws-ls-#{System.unique_integer([:positive])}"

      {:ok, _ws} =
        Canopy.Workspaces.create(%{
          slug: slug,
          name: "List Test Workspace",
          root_path: root
        })

      {:ok, entries} = BuiltIn.list_directory(%{"workspace_slug" => slug})
      names = Enum.map(entries, & &1["name"])
      assert "a.txt" in names
      assert "b.txt" in names
    end

    test "entries have name, type, and size keys" do
      root = Path.join(System.tmp_dir!(), "canopy_ws_ls2_#{System.unique_integer([:positive])}")
      File.mkdir_p!(root)
      File.write!(Path.join(root, "file.txt"), "data")
      on_exit(fn -> File.rm_rf!(root) end)

      slug = "ws-ls2-#{System.unique_integer([:positive])}"

      {:ok, _ws} =
        Canopy.Workspaces.create(%{
          slug: slug,
          name: "List Entry Test",
          root_path: root
        })

      {:ok, entries} = BuiltIn.list_directory(%{"workspace_slug" => slug})
      entry = Enum.find(entries, &(&1["name"] == "file.txt"))
      assert entry["type"] == "file"
      assert is_integer(entry["size"])
    end

    test "excludes hidden files by default" do
      root = Path.join(System.tmp_dir!(), "canopy_ws_ls3_#{System.unique_integer([:positive])}")
      File.mkdir_p!(root)
      File.write!(Path.join(root, ".hidden"), "")
      File.write!(Path.join(root, "visible.txt"), "")
      on_exit(fn -> File.rm_rf!(root) end)

      slug = "ws-ls3-#{System.unique_integer([:positive])}"

      {:ok, _ws} =
        Canopy.Workspaces.create(%{
          slug: slug,
          name: "Hidden Test",
          root_path: root
        })

      {:ok, entries} = BuiltIn.list_directory(%{"workspace_slug" => slug})
      names = Enum.map(entries, & &1["name"])
      refute ".hidden" in names
      assert "visible.txt" in names
    end

    test "includes hidden files when include_hidden is true" do
      root = Path.join(System.tmp_dir!(), "canopy_ws_ls4_#{System.unique_integer([:positive])}")
      File.mkdir_p!(root)
      File.write!(Path.join(root, ".hidden"), "")
      on_exit(fn -> File.rm_rf!(root) end)

      slug = "ws-ls4-#{System.unique_integer([:positive])}"

      {:ok, _ws} =
        Canopy.Workspaces.create(%{
          slug: slug,
          name: "Include Hidden Test",
          root_path: root
        })

      {:ok, entries} =
        BuiltIn.list_directory(%{"workspace_slug" => slug, "include_hidden" => true})

      names = Enum.map(entries, & &1["name"])
      assert ".hidden" in names
    end

    test "rejects path traversal inside a valid workspace" do
      root = Path.join(System.tmp_dir!(), "canopy_ws_lt_#{System.unique_integer([:positive])}")
      File.mkdir_p!(root)
      on_exit(fn -> File.rm_rf!(root) end)

      slug = "ws-lt-#{System.unique_integer([:positive])}"

      {:ok, _ws} =
        Canopy.Workspaces.create(%{
          slug: slug,
          name: "List Traversal Test",
          root_path: root
        })

      assert {:error, :path_traversal} =
               BuiltIn.list_directory(%{"workspace_slug" => slug, "path" => "../etc"})
    end
  end

  # ---------------------------------------------------------------------------
  # search_workspace/1
  # ---------------------------------------------------------------------------

  describe "search_workspace/1" do
    test "returns {:ok, list} even when no workspaces match" do
      assert {:ok, results} = BuiltIn.search_workspace(%{"query" => "no-match-xyz-abc"})
      assert is_list(results)
    end

    test "returns matching workspaces by name" do
      {:ok, _ws} =
        Canopy.Workspaces.create(%{
          slug: "search-ws-#{System.unique_integer([:positive])}",
          name: "UniqueSearchName#{System.unique_integer([:positive])}",
          root_path: "/tmp/search-test-ws"
        })

      {:ok, results} = BuiltIn.search_workspace(%{"query" => "UniqueSearchName"})
      assert length(results) >= 1
      assert Enum.all?(results, fn r -> is_binary(r["slug"]) end)
    end

    test "respects limit parameter" do
      # Create 3 workspaces with the same pattern
      tag = "limittest#{System.unique_integer([:positive])}"

      for i <- 1..3 do
        Canopy.Workspaces.create(%{
          slug: "#{tag}-#{i}",
          name: "Limit Test Workspace #{tag} #{i}",
          root_path: "/tmp/limit-test-#{i}"
        })
      end

      {:ok, results} =
        BuiltIn.search_workspace(%{"query" => "Limit Test Workspace #{tag}", "limit" => 2})

      assert length(results) <= 2
    end
  end

  # ---------------------------------------------------------------------------
  # get_session_context/1
  # ---------------------------------------------------------------------------

  describe "get_session_context/1" do
    test "returns not_found for a missing session_id" do
      assert {:error, :not_found} =
               BuiltIn.get_session_context(%{
                 "session_id" => "00000000-0000-0000-0000-000000000000"
               })
    end

    test "returns session context for a real session" do
      {:ok, session} =
        Canopy.Sessions.create(%{
          runtime_type: "claude-local",
          cwd: "/tmp",
          status: "pending"
        })

      assert {:ok, ctx} = BuiltIn.get_session_context(%{"session_id" => session.id})
      assert ctx["session_id"] == session.id
      assert ctx["runtime_type"] == "claude-local"
      assert ctx["cwd"] == "/tmp"
    end
  end

  # ---------------------------------------------------------------------------
  # log_message/1
  # ---------------------------------------------------------------------------

  describe "log_message/1" do
    test "returns {:ok, map} with logged true for all valid levels" do
      for level <- ["debug", "info", "warning", "error"] do
        assert {:ok, result} = BuiltIn.log_message(%{"level" => level, "message" => "test log"})
        assert result["logged"] == true
        assert result["level"] == level
      end
    end

    test "accepts optional metadata map" do
      assert {:ok, _result} =
               BuiltIn.log_message(%{
                 "level" => "info",
                 "message" => "with metadata",
                 "metadata" => %{"key" => "value"}
               })
    end
  end

  # ---------------------------------------------------------------------------
  # create_comment/1
  # ---------------------------------------------------------------------------

  describe "create_comment/1" do
    test "returns {:ok, map} with resource_id and body" do
      assert {:ok, result} =
               BuiltIn.create_comment(%{"resource_id" => "res-123", "body" => "Nice work!"})

      assert result["resource_id"] == "res-123"
      assert result["body"] == "Nice work!"
      assert is_binary(result["created_at"])
    end
  end
end
