defmodule CanopyMCP.ToolAdapterTest do
  @moduledoc """
  Unit tests for CanopyMCP.ToolAdapter — tool schema transformation and
  fallback behaviour when Canopy.Tools.Registry is unavailable.

  All tests are pure (no DB, no network) and run async.
  """

  use ExUnit.Case, async: true

  alias CanopyMCP.ToolAdapter

  # ---------------------------------------------------------------------------
  # to_mcp_tool/1 — individual tool transformation
  # ---------------------------------------------------------------------------

  describe "to_mcp_tool/1 with atom-keyed maps" do
    test "maps :name to 'name' string" do
      tool = %{name: :read_file, description: "Read a file", parameters: %{}}
      result = ToolAdapter.to_mcp_tool(tool)
      assert result["name"] == "read_file"
    end

    test "maps :description to 'description' string" do
      tool = %{name: "do_thing", description: "Does a thing", parameters: %{}}
      result = ToolAdapter.to_mcp_tool(tool)
      assert result["description"] == "Does a thing"
    end

    test "uses :parameters as inputSchema" do
      schema = %{"type" => "object", "properties" => %{"x" => %{"type" => "integer"}}}
      tool = %{name: "add", description: "Add", parameters: schema}
      result = ToolAdapter.to_mcp_tool(tool)
      assert result["inputSchema"] == schema
    end

    test "uses :input_schema as inputSchema fallback" do
      schema = %{"type" => "object"}
      tool = %{name: "t", description: "d", input_schema: schema}
      result = ToolAdapter.to_mcp_tool(tool)
      assert result["inputSchema"] == schema
    end
  end

  describe "to_mcp_tool/1 with string-keyed maps" do
    test "maps 'name' key correctly" do
      tool = %{"name" => "write_file", "description" => "Write", "parameters" => %{}}
      result = ToolAdapter.to_mcp_tool(tool)
      assert result["name"] == "write_file"
    end

    test "maps 'inputSchema' key directly" do
      schema = %{"type" => "object", "properties" => %{}}
      tool = %{"name" => "t", "description" => "d", "inputSchema" => schema}
      result = ToolAdapter.to_mcp_tool(tool)
      assert result["inputSchema"] == schema
    end
  end

  describe "to_mcp_tool/1 — missing fields" do
    test "defaults name to 'unknown' when absent" do
      tool = %{description: "No name here"}
      result = ToolAdapter.to_mcp_tool(tool)
      assert result["name"] == "unknown"
    end

    test "defaults description to empty string when absent" do
      tool = %{name: "silent_tool"}
      result = ToolAdapter.to_mcp_tool(tool)
      assert result["description"] == ""
    end

    test "defaults inputSchema to empty object schema when no params key" do
      tool = %{name: "bare", description: "bare tool"}
      result = ToolAdapter.to_mcp_tool(tool)
      assert result["inputSchema"] == %{"type" => "object", "properties" => %{}}
    end

    test "result always has the three required MCP keys" do
      result = ToolAdapter.to_mcp_tool(%{})
      assert Map.has_key?(result, "name")
      assert Map.has_key?(result, "description")
      assert Map.has_key?(result, "inputSchema")
    end
  end

  describe "to_mcp_tool/1 — type coercion" do
    test "converts atom name to string" do
      result = ToolAdapter.to_mcp_tool(%{name: :my_tool, description: ""})
      assert is_binary(result["name"])
    end

    test "converts atom description to string" do
      result = ToolAdapter.to_mcp_tool(%{name: "t", description: :some_atom})
      assert is_binary(result["description"])
    end
  end

  # ---------------------------------------------------------------------------
  # list_mcp_tools/0 — registry integration + fallback
  # ---------------------------------------------------------------------------

  describe "list_mcp_tools/0" do
    test "returns a non-empty list" do
      tools = ToolAdapter.list_mcp_tools()
      assert is_list(tools)
      assert tools != []
    end

    test "every tool has the required MCP keys" do
      tools = ToolAdapter.list_mcp_tools()

      for tool <- tools do
        assert Map.has_key?(tool, "name"), "tool missing 'name': #{inspect(tool)}"
        assert Map.has_key?(tool, "description"), "tool missing 'description': #{inspect(tool)}"
        assert Map.has_key?(tool, "inputSchema"), "tool missing 'inputSchema': #{inspect(tool)}"
      end
    end

    test "every tool name is a non-empty binary" do
      tools = ToolAdapter.list_mcp_tools()

      for tool <- tools do
        assert is_binary(tool["name"])
        assert String.length(tool["name"]) > 0
      end
    end

    test "returns fallback list when Canopy.Tools is not implemented" do
      # Canopy.Tools.list/0 currently returns {:error, :not_implemented}.
      # ToolAdapter should fall back to the hardcoded stubs rather than crash.
      tools = ToolAdapter.list_mcp_tools()
      names = Enum.map(tools, & &1["name"])
      # At minimum the three fallback stubs must be present.
      assert "canopy_read_file" in names
      assert "canopy_write_file" in names
      assert "canopy_list_sessions" in names
    end

    test "fallback tools have valid inputSchema structure" do
      tools = ToolAdapter.list_mcp_tools()

      for tool <- tools do
        schema = tool["inputSchema"]
        assert is_map(schema), "inputSchema must be a map: #{inspect(tool)}"
        # Must be encodable as JSON
        assert {:ok, _encoded} = Jason.encode(schema)
      end
    end
  end
end
