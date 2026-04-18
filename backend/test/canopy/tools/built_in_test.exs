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
  end

  # ---------------------------------------------------------------------------
  # read_file/1
  # ---------------------------------------------------------------------------

  describe "read_file/1" do
    test "reads a file that exists" do
      path =
        Path.join(System.tmp_dir!(), "canopy_test_read_#{System.unique_integer([:positive])}")

      content = "hello from read_file test"
      File.write!(path, content)
      on_exit(fn -> File.rm(path) end)

      assert {:ok, ^content} = BuiltIn.read_file(%{"path" => path})
    end

    test "returns an error for a missing file" do
      assert {:error, _reason} = BuiltIn.read_file(%{"path" => "/no/such/file/xyz"})
    end

    test "rejects path traversal (contains ..)" do
      assert {:error, :path_traversal} = BuiltIn.read_file(%{"path" => "/tmp/../etc/passwd"})
    end
  end

  # ---------------------------------------------------------------------------
  # list_directory/1
  # ---------------------------------------------------------------------------

  describe "list_directory/1" do
    test "lists files in an existing directory" do
      dir = Path.join(System.tmp_dir!(), "canopy_ls_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "a.txt"), "")
      File.write!(Path.join(dir, "b.txt"), "")
      on_exit(fn -> File.rm_rf!(dir) end)

      assert {:ok, entries} = BuiltIn.list_directory(%{"path" => dir})
      names = Enum.map(entries, & &1["name"])
      assert "a.txt" in names
      assert "b.txt" in names
    end

    test "entries have name, type, and size keys" do
      dir = Path.join(System.tmp_dir!(), "canopy_ls2_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "file.txt"), "data")
      on_exit(fn -> File.rm_rf!(dir) end)

      {:ok, entries} = BuiltIn.list_directory(%{"path" => dir})
      entry = Enum.find(entries, &(&1["name"] == "file.txt"))
      assert entry["type"] == "file"
      assert is_integer(entry["size"])
    end

    test "excludes hidden files by default" do
      dir = Path.join(System.tmp_dir!(), "canopy_ls3_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, ".hidden"), "")
      File.write!(Path.join(dir, "visible.txt"), "")
      on_exit(fn -> File.rm_rf!(dir) end)

      {:ok, entries} = BuiltIn.list_directory(%{"path" => dir})
      names = Enum.map(entries, & &1["name"])
      refute ".hidden" in names
      assert "visible.txt" in names
    end

    test "includes hidden files when include_hidden is true" do
      dir = Path.join(System.tmp_dir!(), "canopy_ls4_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, ".hidden"), "")
      File.write!(Path.join(dir, "visible.txt"), "")
      on_exit(fn -> File.rm_rf!(dir) end)

      {:ok, entries} = BuiltIn.list_directory(%{"path" => dir, "include_hidden" => true})
      names = Enum.map(entries, & &1["name"])
      assert ".hidden" in names
    end

    test "returns error for missing directory" do
      assert {:error, _} = BuiltIn.list_directory(%{"path" => "/no/such/dir/xyz"})
    end

    test "rejects path traversal" do
      assert {:error, :path_traversal} =
               BuiltIn.list_directory(%{"path" => "/tmp/../etc"})
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
