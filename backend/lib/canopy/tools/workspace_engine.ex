defmodule Canopy.Tools.WorkspaceEngine do
  @moduledoc """
  Agent tool surface for workspace-local OptimalEngine commands.
  """

  use Canopy.Tool

  alias Canopy.Workspaces.Engine

  tool("workspace.engine_health",
    description:
      "Check whether a workspace has an engine directory, Mix project, and command manifest.",
    parameters: %{
      "type" => "object",
      "properties" => %{"workspace_slug" => %{"type" => "string"}},
      "required" => ["workspace_slug"]
    },
    handler: {__MODULE__, :health, []},
    requires: [:workspace],
    mcp_exposed: true,
    prompt_exposed: true
  )

  tool("workspace.engine_commands",
    description: "List allowlisted OptimalEngine commands from `.canopy/engine.yaml`.",
    parameters: %{
      "type" => "object",
      "properties" => %{"workspace_slug" => %{"type" => "string"}},
      "required" => ["workspace_slug"]
    },
    handler: {__MODULE__, :commands, []},
    requires: [:workspace],
    mcp_exposed: true,
    prompt_exposed: true
  )

  tool("workspace.engine_run",
    description:
      "Run an allowlisted OptimalEngine command inside a workspace's `engine/` directory.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{"type" => "string"},
        "command" => %{"type" => "string"},
        "args" => %{"type" => "array", "items" => %{"type" => "string"}},
        "timeout_ms" => %{"type" => "integer"}
      },
      "required" => ["workspace_slug", "command"]
    },
    handler: {__MODULE__, :run, []},
    requires: [:workspace],
    mcp_exposed: true,
    prompt_exposed: true
  )

  tool("workspace.engine_search",
    description: "Search a workspace's knowledge base via `mix optimal.search`.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{"type" => "string"},
        "query" => %{"type" => "string"},
        "limit" => %{"type" => "integer", "default" => 5}
      },
      "required" => ["workspace_slug", "query"]
    },
    handler: {__MODULE__, :engine_search, []},
    requires: [:workspace],
    mcp_exposed: true,
    prompt_exposed: true
  )

  tool("workspace.engine_ingest",
    description: "Ingest a text signal into a workspace's engine via `mix optimal.ingest`.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{"type" => "string"},
        "text" => %{"type" => "string"},
        "genre" => %{"type" => "string"}
      },
      "required" => ["workspace_slug", "text"]
    },
    handler: {__MODULE__, :engine_ingest, []},
    requires: [:workspace],
    mcp_exposed: true,
    prompt_exposed: true
  )

  tool("workspace.engine_l0",
    description: "Load the L0 cache (all node abstracts) for a workspace engine.",
    parameters: %{
      "type" => "object",
      "properties" => %{"workspace_slug" => %{"type" => "string"}},
      "required" => ["workspace_slug"]
    },
    handler: {__MODULE__, :engine_l0, []},
    requires: [:workspace],
    mcp_exposed: true,
    prompt_exposed: true
  )

  tool("workspace.engine_assemble",
    description: "Assemble tiered context for a topic via `mix optimal.assemble`.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{"type" => "string"},
        "topic" => %{"type" => "string"}
      },
      "required" => ["workspace_slug", "topic"]
    },
    handler: {__MODULE__, :engine_assemble, []},
    requires: [:workspace],
    mcp_exposed: true,
    prompt_exposed: true
  )

  def health(%{"workspace_slug" => slug}), do: Engine.health(slug)

  def commands(%{"workspace_slug" => slug}) do
    with {:ok, commands} <- Engine.list_commands(slug) do
      {:ok, %{commands: commands, count: length(commands)}}
    end
  end

  def run(%{"workspace_slug" => slug, "command" => command} = args) do
    Engine.run(slug, command, Map.get(args, "args", []), timeout_ms: Map.get(args, "timeout_ms"))
  end

  def engine_search(%{"workspace_slug" => slug, "query" => query} = args) do
    extra = if limit = Map.get(args, "limit"), do: ["--limit", to_string(limit)], else: []
    Engine.run(slug, "search", [query] ++ extra)
  end

  def engine_ingest(%{"workspace_slug" => slug, "text" => text} = args) do
    extra = if genre = Map.get(args, "genre"), do: ["--genre", genre], else: []
    Engine.run(slug, "ingest", [text] ++ extra)
  end

  def engine_l0(%{"workspace_slug" => slug}), do: Engine.run(slug, "l0", [])

  def engine_assemble(%{"workspace_slug" => slug, "topic" => topic}),
    do: Engine.run(slug, "assemble", [topic])
end
