defmodule CanopyMCP.ToolAdapter do
  @moduledoc """
  Transforms Canopy tool definitions into the MCP tool schema format.

  The MCP `tools/list` response expects each tool as:

      %{
        "name"        => "read_file",
        "description" => "Read a file's contents",
        "inputSchema" => %{ ... JSON Schema object ... }
      }

  This module bridges between whatever shape `Canopy.Tools.list/0` returns and
  the MCP wire format. It also provides a fallback stub list so the MCP server
  can respond meaningfully even when `Canopy.Tools.Registry` is not yet
  available (Track F parallel implementation).

  ## Fallback behaviour

  When `Canopy.Tools.list/0` returns `{:error, :not_implemented}` (or raises),
  `list_mcp_tools/0` falls back to a hardcoded list of demonstration tools.
  This lets external clients like Claude CLI see a valid tool schema immediately
  without waiting for Track F to land. The fallback is documented here so it
  can be removed once the registry is live.
  """

  @type mcp_tool :: %{
          required(String.t()) => String.t() | map()
        }

  @fallback_tools [
    %{
      "name" => "canopy_read_file",
      "description" => "Read the contents of a file at the given path.",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{
          "path" => %{"type" => "string", "description" => "Absolute path to the file"}
        },
        "required" => ["path"]
      }
    },
    %{
      "name" => "canopy_write_file",
      "description" => "Write content to a file at the given path.",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{
          "path" => %{"type" => "string", "description" => "Absolute path to the file"},
          "content" => %{"type" => "string", "description" => "Content to write"}
        },
        "required" => ["path", "content"]
      }
    },
    %{
      "name" => "canopy_list_sessions",
      "description" => "List active Canopy sessions for the current workspace.",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{}
      }
    }
  ]

  @doc """
  Returns the list of Canopy tools formatted as MCP tool schema objects.

  Attempts to call `Canopy.Tools.list/0`. On success, maps each tool map
  through `to_mcp_tool/1`. On error or exception, returns the fallback stub
  list so the MCP server always has something valid to return.
  """
  @spec list_mcp_tools() :: [mcp_tool()]
  def list_mcp_tools do
    # Canopy.Tools.list/0 is a stub that will be replaced by Track F.
    # apply/3 is intentional: it prevents the Elixir type-checker from proving
    # the return type statically, avoiding "clause will never match" during the
    # stub period. Remove when Track F ships the real registry.
    # credo:disable-for-next-line Credo.Check.Refactor.Apply
    case apply(Canopy.Tools, :list, []) do
      {:ok, tools} when is_list(tools) -> Enum.map(tools, &to_mcp_tool/1)
      _other -> @fallback_tools
    end
  rescue
    _err -> @fallback_tools
  end

  @doc """
  Converts a single Canopy tool map into an MCP tool schema map.

  Expects the Canopy tool to have at minimum `:name` and `:description` keys
  (string or atom). The `:parameters` key (if present) is used as the
  `inputSchema`; otherwise an empty object schema is emitted.
  """
  @spec to_mcp_tool(map()) :: mcp_tool()
  def to_mcp_tool(tool) when is_map(tool) do
    name = Map.get(tool, :name) || Map.get(tool, "name") || "unknown"
    description = Map.get(tool, :description) || Map.get(tool, "description") || ""

    input_schema =
      Map.get(tool, :parameters) ||
        Map.get(tool, "parameters") ||
        Map.get(tool, :input_schema) ||
        Map.get(tool, "inputSchema") ||
        %{"type" => "object", "properties" => %{}}

    %{
      "name" => to_string(name),
      "description" => to_string(description),
      "inputSchema" => input_schema
    }
  end
end
