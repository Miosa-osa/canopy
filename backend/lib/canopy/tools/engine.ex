defmodule Canopy.Tools.Engine do
  @moduledoc """
  MCP tool surface for Optimal Engine operations scoped to a workspace.

  Delegates to `Canopy.Engine.Bridge` which shells out via
  `Canopy.Workspaces.Engine` — no in-process dep required.
  """

  use Canopy.Tool

  alias Canopy.Engine.Bridge

  tool("engine.search",
    description: "Search a workspace's Optimal Engine knowledge base.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{"type" => "string"},
        "query" => %{"type" => "string"},
        "limit" => %{"type" => "integer", "default" => 5}
      },
      "required" => ["workspace_slug", "query"]
    },
    handler: {__MODULE__, :search, []},
    requires: [:workspace],
    mcp_exposed: true,
    prompt_exposed: true
  )

  tool("engine.ingest",
    description: "Ingest a text signal into a workspace's Optimal Engine.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{"type" => "string"},
        "text" => %{"type" => "string"},
        "genre" => %{
          "type" => "string",
          "description" => "Signal genre (note, transcript, decision_log, ...)"
        }
      },
      "required" => ["workspace_slug", "text"]
    },
    handler: {__MODULE__, :ingest, []},
    requires: [:workspace],
    mcp_exposed: true,
    prompt_exposed: true
  )

  tool("engine.remember",
    description: "Store a key/value observation in workspace memory.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{"type" => "string"},
        "key" => %{"type" => "string"},
        "value" => %{"type" => "string"}
      },
      "required" => ["workspace_slug", "key", "value"]
    },
    handler: {__MODULE__, :remember, []},
    requires: [:workspace],
    mcp_exposed: true,
    prompt_exposed: true
  )

  tool("engine.recall",
    description: "Recall a value from workspace memory by key.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{"type" => "string"},
        "key" => %{"type" => "string"}
      },
      "required" => ["workspace_slug", "key"]
    },
    handler: {__MODULE__, :recall, []},
    requires: [:workspace],
    mcp_exposed: true,
    prompt_exposed: true
  )

  tool("engine.l0",
    description: "Load the L0 cache (all node abstracts) for a workspace engine.",
    parameters: %{
      "type" => "object",
      "properties" => %{"workspace_slug" => %{"type" => "string"}},
      "required" => ["workspace_slug"]
    },
    handler: {__MODULE__, :l0, []},
    requires: [:workspace],
    mcp_exposed: true,
    prompt_exposed: true
  )

  tool("engine.assemble",
    description: "Assemble tiered context bundle for a topic (L0 + L1 + L2).",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{"type" => "string"},
        "topic" => %{"type" => "string"}
      },
      "required" => ["workspace_slug", "topic"]
    },
    handler: {__MODULE__, :assemble, []},
    requires: [:workspace],
    mcp_exposed: true,
    prompt_exposed: true
  )

  def search(%{"workspace_slug" => slug, "query" => query} = args) do
    limit = Map.get(args, "limit", 5)
    Bridge.search(slug, query, limit: limit)
  end

  def ingest(%{"workspace_slug" => slug, "text" => text} = args) do
    opts = if genre = Map.get(args, "genre"), do: [genre: genre], else: []
    Bridge.ingest(slug, text, opts)
  end

  def remember(%{"workspace_slug" => slug, "key" => key, "value" => value}) do
    Bridge.memory_store(slug, key, value)
  end

  def recall(%{"workspace_slug" => slug, "key" => key}) do
    Bridge.memory_recall(slug, key)
  end

  def l0(%{"workspace_slug" => slug}), do: Bridge.l0(slug)

  def assemble(%{"workspace_slug" => slug, "topic" => topic}),
    do: Bridge.assemble(slug, topic)
end
