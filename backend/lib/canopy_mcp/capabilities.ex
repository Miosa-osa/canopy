defmodule CanopyMCP.Capabilities do
  @moduledoc """
  MCP server capability negotiation.

  Returns the static server info and capability map sent in response to the
  `initialize` method. The capabilities object declares which MCP feature
  groups this server supports and whether change notifications are emitted.

  For Canopy MCP v0.1.0:
  - `tools`     — supported (list_changed: true, so clients may re-poll)
  - `resources` — declared but not yet active (list_changed: false)
  - `prompts`   — declared but not yet active (list_changed: false)

  Resources and prompts are listed here so external clients see the full
  intent without crashing on unknown capability keys.
  """

  @server_name "canopy-mcp"
  @server_version "0.1.0"
  @protocol_version "2024-11-05"

  @type capabilities_result :: %{
          required(:protocolVersion) => String.t(),
          required(:serverInfo) => %{
            required(:name) => String.t(),
            required(:version) => String.t()
          },
          required(:capabilities) => map()
        }

  @doc """
  Returns the full `initialize` response body as a map ready to be encoded
  into a JSON-RPC result.

  The shape follows the MCP spec `InitializeResult` object.
  """
  @spec initialize_result() :: capabilities_result()
  def initialize_result do
    %{
      "protocolVersion" => @protocol_version,
      "serverInfo" => %{
        "name" => @server_name,
        "version" => @server_version
      },
      "capabilities" => %{
        "tools" => %{"listChanged" => true},
        "resources" => %{"listChanged" => false},
        "prompts" => %{"listChanged" => false}
      }
    }
  end

  @doc "Returns the server name string."
  @spec server_name() :: String.t()
  def server_name, do: @server_name

  @doc "Returns the server version string."
  @spec server_version() :: String.t()
  def server_version, do: @server_version

  @doc "Returns the MCP protocol version this server speaks."
  @spec protocol_version() :: String.t()
  def protocol_version, do: @protocol_version
end
