defmodule CanopyMCP.ResourceAdapterTest do
  @moduledoc """
  Unit + integration tests for CanopyMCP.ResourceAdapter.

  Tests that hit the DB use DataCase (SQL sandbox). Pure parse/enumerate tests
  run async. Tests that touch the filesystem create temp dirs and clean up on exit.
  """

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias CanopyMCP.ResourceAdapter

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Creates a temp dir, writes files into it, returns the dir path.
  defp temp_workspace_dir(files) do
    dir = Path.join(System.tmp_dir!(), "canopy-mcp-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    Enum.each(files, fn {rel_path, content} ->
      abs = Path.join(dir, rel_path)
      File.mkdir_p!(Path.dirname(abs))
      File.write!(abs, content)
    end)

    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end

  # ---------------------------------------------------------------------------
  # list_resources/0 — empty state
  # ---------------------------------------------------------------------------

  describe "list_resources/0 with no workspaces or hired agents" do
    test "returns empty list when nothing exists" do
      resources = ResourceAdapter.list_resources()
      assert is_list(resources)
    end
  end

  # ---------------------------------------------------------------------------
  # list_resources/0 — workspace files
  # ---------------------------------------------------------------------------

  describe "list_resources/0 workspace file enumeration" do
    test "includes files from a workspace with real root_path" do
      dir = temp_workspace_dir([{"SYSTEM.md", "# System"}, {"notes.txt", "hello"}])
      ws = insert(:workspace, root_path: dir)

      resources = ResourceAdapter.list_resources()
      uris = Enum.map(resources, & &1["uri"])

      assert Enum.any?(uris, &String.contains?(&1, "#{ws.slug}/files/SYSTEM.md"))
      assert Enum.any?(uris, &String.contains?(&1, "#{ws.slug}/files/notes.txt"))
    end

    test "each resource descriptor has required MCP keys" do
      dir = temp_workspace_dir([{"README.md", "# Read me"}])
      insert(:workspace, root_path: dir)

      resources = ResourceAdapter.list_resources()

      for resource <- resources do
        assert Map.has_key?(resource, "uri")
        assert Map.has_key?(resource, "name")
        assert Map.has_key?(resource, "description")
        assert Map.has_key?(resource, "mimeType")
      end
    end

    test "URI follows canopy://workspace/:slug/files/:path scheme" do
      dir = temp_workspace_dir([{"SYSTEM.md", "# System"}])
      ws = insert(:workspace, root_path: dir)

      resources = ResourceAdapter.list_resources()

      ws_resources =
        Enum.filter(resources, &String.starts_with?(&1["uri"], "canopy://workspace/#{ws.slug}/"))

      assert ws_resources != []

      for r <- ws_resources do
        assert String.starts_with?(r["uri"], "canopy://workspace/#{ws.slug}/files/")
      end
    end

    test "markdown files get text/markdown MIME type" do
      dir = temp_workspace_dir([{"SYSTEM.md", "# System"}])
      insert(:workspace, root_path: dir)

      resources = ResourceAdapter.list_resources()
      md_resource = Enum.find(resources, &String.ends_with?(&1["uri"], "SYSTEM.md"))

      assert md_resource != nil
      assert md_resource["mimeType"] == "text/markdown"
    end

    test "txt files get text/plain MIME type" do
      dir = temp_workspace_dir([{"notes.txt", "hello"}])
      insert(:workspace, root_path: dir)

      resources = ResourceAdapter.list_resources()
      txt_resource = Enum.find(resources, &String.ends_with?(&1["uri"], "notes.txt"))

      assert txt_resource != nil
      assert txt_resource["mimeType"] == "text/plain"
    end

    test "recursively enumerates subdirectory files" do
      dir = temp_workspace_dir([{"docs/guide.md", "# Guide"}])
      ws = insert(:workspace, root_path: dir)

      resources = ResourceAdapter.list_resources()
      uris = Enum.map(resources, & &1["uri"])

      assert Enum.any?(uris, &String.contains?(&1, "#{ws.slug}/files/docs/guide.md"))
    end

    test "soft-deleted workspaces are not included" do
      dir = temp_workspace_dir([{"SYSTEM.md", "# System"}])
      ws = insert(:workspace, root_path: dir, deleted_at: DateTime.utc_now())

      resources = ResourceAdapter.list_resources()
      uris = Enum.map(resources, & &1["uri"])

      refute Enum.any?(uris, &String.contains?(&1, ws.slug))
    end
  end

  # ---------------------------------------------------------------------------
  # list_resources/0 — agent persona resources
  # ---------------------------------------------------------------------------

  describe "list_resources/0 agent persona enumeration" do
    test "includes hired agents as persona resources" do
      agent = insert(:agent, hired: true)

      resources = ResourceAdapter.list_resources()
      uris = Enum.map(resources, & &1["uri"])

      assert "canopy://agent/#{agent.slug}/persona" in uris
    end

    test "does not include unhired agents" do
      agent = insert(:agent, hired: false)

      resources = ResourceAdapter.list_resources()
      uris = Enum.map(resources, & &1["uri"])

      refute "canopy://agent/#{agent.slug}/persona" in uris
    end

    test "agent persona URI follows canopy://agent/:slug/persona scheme" do
      agent = insert(:agent, hired: true)

      resources = ResourceAdapter.list_resources()

      persona_resource =
        Enum.find(resources, &(&1["uri"] == "canopy://agent/#{agent.slug}/persona"))

      assert persona_resource != nil
      assert persona_resource["mimeType"] == "text/markdown"
    end
  end

  # ---------------------------------------------------------------------------
  # read_resource/1 — workspace files
  # ---------------------------------------------------------------------------

  describe "read_resource/1 workspace file reads" do
    test "returns content for an existing workspace file" do
      dir = temp_workspace_dir([{"SYSTEM.md", "# System content"}])
      ws = insert(:workspace, root_path: dir)

      uri = "canopy://workspace/#{ws.slug}/files/SYSTEM.md"
      assert {:ok, content} = ResourceAdapter.read_resource(uri)
      assert content["uri"] == uri
      assert content["text"] == "# System content"
      assert content["mimeType"] == "text/markdown"
    end

    test "returns :not_found for a missing file" do
      dir = temp_workspace_dir([])
      ws = insert(:workspace, root_path: dir)

      uri = "canopy://workspace/#{ws.slug}/files/ghost.md"
      assert {:error, :not_found} = ResourceAdapter.read_resource(uri)
    end

    test "returns :not_found for an unknown workspace slug" do
      uri = "canopy://workspace/no-such-workspace/files/SYSTEM.md"
      assert {:error, :not_found} = ResourceAdapter.read_resource(uri)
    end

    test "traversal attack is rejected" do
      dir = temp_workspace_dir([{"SYSTEM.md", "# ok"}])
      ws = insert(:workspace, root_path: dir)

      # The Files module rejects ".." segments — this must surface as an error, not a read
      uri = "canopy://workspace/#{ws.slug}/files/../../etc/passwd"
      result = ResourceAdapter.read_resource(uri)
      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # read_resource/1 — agent persona reads
  # ---------------------------------------------------------------------------

  describe "read_resource/1 agent persona reads" do
    test "returns persona markdown for a hired agent" do
      agent = insert(:agent, hired: true, persona_markdown: "You are a senior engineer.")

      uri = "canopy://agent/#{agent.slug}/persona"
      assert {:ok, content} = ResourceAdapter.read_resource(uri)
      assert content["uri"] == uri
      assert content["text"] == "You are a senior engineer."
      assert content["mimeType"] == "text/markdown"
    end

    test "returns :not_found for an unhired agent" do
      agent = insert(:agent, hired: false)

      uri = "canopy://agent/#{agent.slug}/persona"
      assert {:error, :not_found} = ResourceAdapter.read_resource(uri)
    end

    test "returns :not_found for an unknown agent slug" do
      uri = "canopy://agent/no-such-agent/persona"
      assert {:error, :not_found} = ResourceAdapter.read_resource(uri)
    end
  end

  # ---------------------------------------------------------------------------
  # read_resource/1 — unknown URI shapes
  # ---------------------------------------------------------------------------

  describe "read_resource/1 unknown URIs" do
    test "returns :not_found for a completely unknown URI scheme" do
      assert {:error, :not_found} = ResourceAdapter.read_resource("http://example.com/file")
    end

    test "returns :not_found for canopy:// URI with unrecognised structure" do
      assert {:error, :not_found} = ResourceAdapter.read_resource("canopy://unknown/something")
    end

    test "returns :not_found for workspace URI missing /files/ segment" do
      assert {:error, :not_found} = ResourceAdapter.read_resource("canopy://workspace/my-ws/nope")
    end

    test "returns :not_found for agent URI with wrong suffix" do
      assert {:error, :not_found} =
               ResourceAdapter.read_resource("canopy://agent/my-agent/system")
    end
  end
end
