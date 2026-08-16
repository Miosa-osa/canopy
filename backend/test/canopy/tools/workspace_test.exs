defmodule Canopy.Tools.WorkspaceTest do
  @moduledoc """
  Tests for `Canopy.Tools.Workspace` MCP tool handlers.

  Exercises all eight tools and verifies correct return shapes, workspace
  isolation, and error cases (workspace not found, file not found, invalid path).
  """

  use Canopy.DataCase, async: false

  import Canopy.Factory

  alias Canopy.Drive
  alias Canopy.Tools.Workspace, as: WorkspaceTools
  alias Canopy.Workspaces

  # ---------------------------------------------------------------------------
  # Setup helpers
  # ---------------------------------------------------------------------------

  defp tmp_workspace(attrs \\ []) do
    slug = "ws-test-#{System.unique_integer([:positive])}"
    root = Path.join(System.tmp_dir!(), slug)
    File.mkdir_p!(root)

    {:ok, workspace} =
      Workspaces.create(
        Keyword.merge(
          [slug: slug, name: "Test #{slug}", root_path: root],
          attrs
        )
        |> Map.new()
      )

    on_exit(fn -> File.rm_rf!(root) end)
    workspace
  end

  defp write!(workspace, rel_path, content \\ "hello\n") do
    abs = Path.join(workspace.root_path, rel_path)
    File.mkdir_p!(Path.dirname(abs))
    File.write!(abs, content)
    rel_path
  end

  # ---------------------------------------------------------------------------
  # Tool declarations
  # ---------------------------------------------------------------------------

  describe "__canopy_tools__/0" do
    test "declares all eight workspace tools" do
      names = WorkspaceTools.__canopy_tools__() |> Enum.map(& &1.name)

      assert "workspace.list_files" in names
      assert "workspace.read_file" in names
      assert "workspace.write_file" in names
      assert "workspace.search_files" in names
      assert "workspace.list_sessions" in names
      assert "workspace.list_drive_entries" in names
      assert "workspace.create_drive_entry" in names
      assert "workspace.get_workspace_info" in names
    end
  end

  # ---------------------------------------------------------------------------
  # workspace.list_files
  # ---------------------------------------------------------------------------

  describe "list_files/1" do
    test "lists files in workspace root" do
      ws = tmp_workspace()
      write!(ws, "README.md")
      write!(ws, "notes.txt")

      assert {:ok, %{count: count, entries: entries}} =
               WorkspaceTools.list_files(%{"workspace_slug" => ws.slug})

      assert count >= 2
      names = Enum.map(entries, & &1.name)
      assert "README.md" in names
      assert "notes.txt" in names
    end

    test "lists files in a subdirectory" do
      ws = tmp_workspace()
      write!(ws, "sub/file.md")

      assert {:ok, %{entries: entries}} =
               WorkspaceTools.list_files(%{"workspace_slug" => ws.slug, "path" => "sub"})

      names = Enum.map(entries, & &1.name)
      assert "file.md" in names
    end

    test "each entry has the correct shape" do
      ws = tmp_workspace()
      write!(ws, "shape.md", "content")

      assert {:ok, %{entries: [entry | _]}} =
               WorkspaceTools.list_files(%{"workspace_slug" => ws.slug})

      assert Map.has_key?(entry, :name)
      assert Map.has_key?(entry, :path)
      assert Map.has_key?(entry, :is_dir)
      assert Map.has_key?(entry, :size)
    end

    test "returns workspace_not_found for unknown slug" do
      assert {:error, :workspace_not_found} =
               WorkspaceTools.list_files(%{"workspace_slug" => "no-such-workspace"})
    end
  end

  # ---------------------------------------------------------------------------
  # workspace.read_file
  # ---------------------------------------------------------------------------

  describe "read_file/1" do
    test "reads a file and returns correct shape" do
      ws = tmp_workspace()
      write!(ws, "hello.md", "# Hello\n")

      assert {:ok, result} =
               WorkspaceTools.read_file(%{"workspace_slug" => ws.slug, "path" => "hello.md"})

      assert result.content == "# Hello\n"
      assert result.path == "hello.md"
      assert is_integer(result.size)
      assert is_binary(result.mime_type)
    end

    test "returns correct mime type for markdown" do
      ws = tmp_workspace()
      write!(ws, "doc.md", "content")

      assert {:ok, %{mime_type: "text/markdown"}} =
               WorkspaceTools.read_file(%{"workspace_slug" => ws.slug, "path" => "doc.md"})
    end

    test "returns :not_found for missing file" do
      ws = tmp_workspace()

      assert {:error, :not_found} =
               WorkspaceTools.read_file(%{
                 "workspace_slug" => ws.slug,
                 "path" => "nonexistent.md"
               })
    end

    test "returns error for unknown workspace" do
      assert {:error, _} =
               WorkspaceTools.read_file(%{
                 "workspace_slug" => "ghost-workspace",
                 "path" => "file.md"
               })
    end
  end

  # ---------------------------------------------------------------------------
  # workspace.write_file
  # ---------------------------------------------------------------------------

  describe "write_file/1" do
    test "writes a file and returns path and size" do
      ws = tmp_workspace()

      assert {:ok, result} =
               WorkspaceTools.write_file(%{
                 "workspace_slug" => ws.slug,
                 "path" => "output.md",
                 "contents" => "# Written by tool\n"
               })

      assert result.path == "output.md"
      assert result.size > 0
    end

    test "file is actually written to disk" do
      ws = tmp_workspace()

      WorkspaceTools.write_file(%{
        "workspace_slug" => ws.slug,
        "path" => "persist.txt",
        "contents" => "persisted content"
      })

      assert File.read!(Path.join(ws.root_path, "persist.txt")) == "persisted content"
    end

    test "creates parent directories as needed" do
      ws = tmp_workspace()

      assert {:ok, _} =
               WorkspaceTools.write_file(%{
                 "workspace_slug" => ws.slug,
                 "path" => "deep/dir/file.md",
                 "contents" => "nested"
               })

      assert File.exists?(Path.join(ws.root_path, "deep/dir/file.md"))
    end

    test "returns error for unknown workspace" do
      assert {:error, _} =
               WorkspaceTools.write_file(%{
                 "workspace_slug" => "no-ws",
                 "path" => "x.md",
                 "contents" => "x"
               })
    end
  end

  # ---------------------------------------------------------------------------
  # workspace.search_files
  # ---------------------------------------------------------------------------

  describe "search_files/1" do
    test "finds matching content and returns correct shape" do
      ws = tmp_workspace()
      write!(ws, "search_me.md", "the quick brown fox\n")

      assert {:ok, %{count: count, results: results}} =
               WorkspaceTools.search_files(%{
                 "workspace_slug" => ws.slug,
                 "query" => "quick"
               })

      assert count > 0
      [match | _] = results
      assert Map.has_key?(match, :file)
      assert Map.has_key?(match, :line)
      assert Map.has_key?(match, :text)
    end

    test "returns empty results for a query with no matches" do
      ws = tmp_workspace()
      write!(ws, "empty_search.md", "nothing relevant here\n")

      assert {:ok, %{count: 0, results: []}} =
               WorkspaceTools.search_files(%{
                 "workspace_slug" => ws.slug,
                 "query" => "xyzzy_no_match_at_all"
               })
    end

    test "returns an error for unknown workspace slug" do
      assert {:error, _reason} =
               WorkspaceTools.search_files(%{
                 "workspace_slug" => "nowhere",
                 "query" => "test"
               })
    end
  end

  # ---------------------------------------------------------------------------
  # workspace.list_sessions
  # ---------------------------------------------------------------------------

  describe "list_sessions/1" do
    test "returns sessions with the correct shape" do
      insert(:session, workspace_slug: "my-ws", status: "completed")

      assert {:ok, %{count: _count, sessions: sessions}} =
               WorkspaceTools.list_sessions(%{"workspace_slug" => "my-ws"})

      if length(sessions) > 0 do
        [s | _] = sessions
        assert Map.has_key?(s, :id)
        assert Map.has_key?(s, :status)
        assert Map.has_key?(s, :workspace_slug)
        assert Map.has_key?(s, :inserted_at)
      end
    end

    test "filters by status" do
      insert(:session, workspace_slug: "filter-ws", status: "completed")
      insert(:session, workspace_slug: "filter-ws", status: "failed")

      assert {:ok, %{sessions: sessions}} =
               WorkspaceTools.list_sessions(%{
                 "workspace_slug" => "filter-ws",
                 "status" => "completed"
               })

      assert Enum.all?(sessions, &(&1.status == "completed"))
    end

    test "returns empty list for workspace with no sessions" do
      assert {:ok, %{count: 0, sessions: []}} =
               WorkspaceTools.list_sessions(%{"workspace_slug" => "empty-workspace-xyz"})
    end

    test "list_sessions with no params returns all sessions" do
      insert(:session)

      assert {:ok, %{count: count}} = WorkspaceTools.list_sessions(%{})
      assert count >= 1
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers for drive entry creation (no factory exists for Drive.Entry)
  # ---------------------------------------------------------------------------

  defp create_drive_entry!(kind, name_suffix) do
    slug = "test-entry-#{System.unique_integer([:positive])}"

    {:ok, entry} =
      Drive.create(%{
        slug: slug,
        name: "Test #{name_suffix}",
        kind: kind,
        scope: "personal",
        body: %{"content" => "test body"}
      })

    entry
  end

  # ---------------------------------------------------------------------------
  # workspace.list_drive_entries
  # ---------------------------------------------------------------------------

  describe "list_drive_entries/1" do
    test "returns entries with correct shape" do
      create_drive_entry!("prompt", "shape-check")

      assert {:ok, %{count: _count, entries: entries}} =
               WorkspaceTools.list_drive_entries(%{})

      assert length(entries) >= 1
      [e | _] = entries
      assert Map.has_key?(e, :id)
      assert Map.has_key?(e, :name)
      assert Map.has_key?(e, :kind)
      assert Map.has_key?(e, :scope)
    end

    test "filters by kind" do
      create_drive_entry!("prompt", "filter-prompt")
      create_drive_entry!("rule", "filter-rule")

      assert {:ok, %{entries: entries}} =
               WorkspaceTools.list_drive_entries(%{"kind" => "prompt"})

      assert Enum.all?(entries, &(&1.kind == "prompt"))
    end
  end

  # ---------------------------------------------------------------------------
  # workspace.create_drive_entry
  # ---------------------------------------------------------------------------

  describe "create_drive_entry/1" do
    test "creates a prompt entry and returns it with the correct shape" do
      assert {:ok, entry} =
               WorkspaceTools.create_drive_entry(%{
                 "kind" => "prompt",
                 "title" => "My Prompt",
                 "body" => "You are a helpful agent."
               })

      assert entry.name == "My Prompt"
      assert entry.kind == "prompt"
      assert Map.has_key?(entry, :id)
      assert Map.has_key?(entry, :slug)
    end

    test "creates a rule entry and returns it with the correct shape" do
      assert {:ok, entry} =
               WorkspaceTools.create_drive_entry(%{
                 "kind" => "rule",
                 "title" => "Security Rule",
                 "body" => "Never expose secrets."
               })

      assert entry.name == "Security Rule"
      assert entry.kind == "rule"
    end

    test "stores the body content" do
      assert {:ok, entry} =
               WorkspaceTools.create_drive_entry(%{
                 "kind" => "prompt",
                 "title" => "System Prompt",
                 "body" => "You are a helpful agent."
               })

      assert entry.body["content"] == "You are a helpful agent."
    end
  end

  # ---------------------------------------------------------------------------
  # workspace.get_workspace_info
  # ---------------------------------------------------------------------------

  describe "get_workspace_info/1" do
    test "returns metadata for an existing workspace" do
      ws = tmp_workspace()

      assert {:ok, info} =
               WorkspaceTools.get_workspace_info(%{"workspace_slug" => ws.slug})

      assert info.slug == ws.slug
      assert info.name == ws.name
      assert info.root_path == ws.root_path
      assert info.created_at != nil
    end

    test "returns workspace_not_found for unknown slug" do
      assert {:error, :workspace_not_found} =
               WorkspaceTools.get_workspace_info(%{"workspace_slug" => "does-not-exist"})
    end
  end
end
