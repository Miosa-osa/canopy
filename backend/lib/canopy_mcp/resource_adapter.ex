defmodule CanopyMCP.ResourceAdapter do
  @moduledoc """
  Exposes Canopy workspace files and hired agent personas as MCP resources.

  Resource URI scheme:

      canopy://workspace/:slug/files/:path    — individual workspace file
      canopy://agent/:slug/persona            — hired agent persona markdown

  This module is read-only. No write operations are exposed via MCP this phase.

  ## Resource enumeration

  `list_resources/0` walks every non-deleted workspace (via `Canopy.Workspaces.list/0`)
  and recursively enumerates files via `Canopy.Workspaces.Files.list_dir/2`. File
  count is capped at 500 per workspace to prevent enumeration DoS.

  Only hired agents are included in persona resources to preserve signal-to-noise.

  ## Path traversal safety

  All file reads delegate to `Canopy.Workspaces.Files.read_file/2`, which applies
  the same directory-traversal guard as the HTTP file API (Phase 2, Track #67).
  The path extracted from the URI cannot escape the workspace root.
  """

  alias Canopy.Workspaces
  alias Canopy.Workspaces.Files
  alias Canopy.Agents

  @resource_cap 500

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Returns a list of MCP resource descriptors for all workspace files and hired
  agent personas.

  Each descriptor has the shape:

      %{
        "uri"         => "canopy://workspace/my-ws/files/SYSTEM.md",
        "name"        => "SYSTEM.md",
        "description" => "Workspace SYSTEM.md in my-ws",
        "mimeType"    => "text/markdown"
      }
  """
  @spec list_resources() :: [map()]
  def list_resources do
    workspace_resources() ++ agent_persona_resources()
  end

  @doc """
  Reads the content of a resource identified by `uri`.

  Returns `{:ok, content_map}` on success where `content_map` has:

      %{
        "uri"      => uri,
        "mimeType" => "text/markdown",
        "text"     => "..."
      }

  Returns `{:error, :not_found}` for unknown URIs or missing files/agents.
  Returns `{:error, reason}` for other read failures (e.g. `:too_large`, `:not_utf8`).
  """
  @spec read_resource(String.t()) :: {:ok, map()} | {:error, term()}
  def read_resource(uri) when is_binary(uri) do
    case parse_uri(uri) do
      {:workspace_file, ws_slug, rel_path} ->
        read_workspace_file(uri, ws_slug, rel_path)

      {:agent_persona, agent_slug} ->
        read_agent_persona(uri, agent_slug)

      :unknown ->
        {:error, :not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # Private — resource enumeration
  # ---------------------------------------------------------------------------

  @spec workspace_resources() :: [map()]
  defp workspace_resources do
    case Workspaces.list() do
      {:ok, workspaces} ->
        Enum.flat_map(workspaces, &resources_for_workspace/1)

      _error ->
        []
    end
  end

  @spec resources_for_workspace(Workspaces.Workspace.t()) :: [map()]
  defp resources_for_workspace(workspace) do
    workspace
    |> enumerate_files("", 0)
    |> Enum.take(@resource_cap)
    |> Enum.map(fn rel_path ->
      uri = workspace_file_uri(workspace.slug, rel_path)
      name = Path.basename(rel_path)

      %{
        "uri" => uri,
        "name" => name,
        "description" => "#{name} in #{workspace.slug}",
        "mimeType" => mime_for(rel_path)
      }
    end)
  end

  # Recursively enumerates files under rel_dir. Returns flat list of relative paths.
  @spec enumerate_files(Workspaces.Workspace.t(), String.t(), non_neg_integer()) :: [String.t()]
  defp enumerate_files(workspace, rel_dir, depth) when depth <= 20 do
    case Files.list_dir(workspace, rel_dir) do
      {:ok, entries} ->
        Enum.flat_map(entries, fn entry ->
          child_path =
            if rel_dir == "" do
              entry.name
            else
              Path.join(rel_dir, entry.name)
            end

          if entry.is_dir do
            enumerate_files(workspace, child_path, depth + 1)
          else
            [child_path]
          end
        end)

      _error ->
        []
    end
  end

  defp enumerate_files(_workspace, _rel_dir, _depth), do: []

  @spec agent_persona_resources() :: [map()]
  defp agent_persona_resources do
    case Agents.list(hired: true) do
      {:ok, agents} ->
        Enum.map(agents, fn agent ->
          %{
            "uri" => agent_persona_uri(agent.slug),
            "name" => "#{agent.name} persona",
            "description" => "Hired agent persona for #{agent.name}",
            "mimeType" => "text/markdown"
          }
        end)

      _error ->
        []
    end
  end

  # ---------------------------------------------------------------------------
  # Private — resource reads
  # ---------------------------------------------------------------------------

  @spec read_workspace_file(String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  defp read_workspace_file(uri, ws_slug, rel_path) do
    with {:ok, workspace} <- Workspaces.get_by_slug(ws_slug),
         {:ok, content} <- Files.read_file(workspace, rel_path) do
      {:ok,
       %{
         "uri" => uri,
         "mimeType" => mime_for(rel_path),
         "text" => content
       }}
    else
      {:error, :not_found} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec read_agent_persona(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  defp read_agent_persona(uri, agent_slug) do
    case Agents.get_by_slug(agent_slug) do
      {:ok, %{hired: true} = agent} ->
        {:ok,
         %{
           "uri" => uri,
           "mimeType" => "text/markdown",
           "text" => agent.persona_markdown || ""
         }}

      {:ok, %{hired: false}} ->
        # Non-hired agents are not exposed — treat as not found
        {:error, :not_found}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # Private — URI construction and parsing
  # ---------------------------------------------------------------------------

  @spec workspace_file_uri(String.t(), String.t()) :: String.t()
  defp workspace_file_uri(ws_slug, rel_path) do
    "canopy://workspace/#{ws_slug}/files/#{rel_path}"
  end

  @spec agent_persona_uri(String.t()) :: String.t()
  defp agent_persona_uri(agent_slug) do
    "canopy://agent/#{agent_slug}/persona"
  end

  @type parsed_uri ::
          {:workspace_file, String.t(), String.t()}
          | {:agent_persona, String.t()}
          | :unknown

  @spec parse_uri(String.t()) :: parsed_uri()
  defp parse_uri("canopy://workspace/" <> rest) do
    # rest = "<ws_slug>/files/<rel_path>"
    case String.split(rest, "/files/", parts: 2) do
      [ws_slug, rel_path] when ws_slug != "" and rel_path != "" ->
        {:workspace_file, ws_slug, rel_path}

      _other ->
        :unknown
    end
  end

  defp parse_uri("canopy://agent/" <> rest) do
    # rest = "<agent_slug>/persona"
    case String.split(rest, "/", parts: 2) do
      [agent_slug, "persona"] when agent_slug != "" ->
        {:agent_persona, agent_slug}

      _other ->
        :unknown
    end
  end

  defp parse_uri(_uri), do: :unknown

  # ---------------------------------------------------------------------------
  # Private — MIME type inference
  # ---------------------------------------------------------------------------

  @spec mime_for(String.t()) :: String.t()
  defp mime_for(path) do
    case Path.extname(path) do
      ".md" -> "text/markdown"
      ".markdown" -> "text/markdown"
      ".txt" -> "text/plain"
      ".json" -> "application/json"
      ".yaml" -> "application/yaml"
      ".yml" -> "application/yaml"
      ".toml" -> "application/toml"
      ".ex" -> "text/x-elixir"
      ".exs" -> "text/x-elixir"
      ".ts" -> "text/typescript"
      ".js" -> "text/javascript"
      ".html" -> "text/html"
      ".css" -> "text/css"
      ".sh" -> "text/x-sh"
      _ -> "text/plain"
    end
  end
end
