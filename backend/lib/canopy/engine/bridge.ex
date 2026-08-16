defmodule Canopy.Engine.Bridge do
  @moduledoc """
  Bridges Optimal Engine facades into Canopy's workspace context.

  All calls go through the shell bridge (System.cmd via Port in
  `Canopy.Workspaces.Engine`). This keeps the integration safe and
  operational without requiring the engine to compile as a Mix dep.

  Each public function is workspace-scoped: the `workspace_slug` is used
  to locate the right engine directory and enforce the manifest allowlist.
  """

  alias Canopy.Workspaces.Engine

  require Logger

  @type result :: {:ok, map()} | {:error, atom() | term()}

  @doc "Search a workspace's knowledge base."
  @spec search(String.t(), String.t(), keyword()) :: result()
  def search(workspace_slug, query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    with {:ok, result} <-
           Engine.run(workspace_slug, "search", [query, "--limit", to_string(limit)]) do
      emit(:search, workspace_slug, result.duration_ms)
      {:ok, result}
    end
  end

  @doc "Ingest a text signal into a workspace's engine."
  @spec ingest(String.t(), String.t(), keyword()) :: result()
  def ingest(workspace_slug, text, opts \\ []) do
    args =
      case Keyword.get(opts, :genre) do
        nil -> [text]
        genre -> [text, "--genre", genre]
      end

    with {:ok, result} <- Engine.run(workspace_slug, "ingest", args) do
      emit(:ingest, workspace_slug, result.duration_ms)

      Phoenix.PubSub.broadcast(
        Canopy.PubSub,
        "engine:#{workspace_slug}",
        %{event: "signal_ingested", workspace_slug: workspace_slug, stdout: result.stdout}
      )

      {:ok, result}
    end
  end

  @doc "Store a key/value pair in workspace memory via `mix optimal.remember`."
  @spec memory_store(String.t(), String.t(), String.t()) :: result()
  def memory_store(workspace_slug, key, value) do
    with {:ok, result} <- Engine.run(workspace_slug, "remember", ["#{key}: #{value}"]) do
      emit(:memory_store, workspace_slug, result.duration_ms)
      {:ok, result}
    end
  end

  @doc "Recall a value from workspace memory via `mix optimal.search`."
  @spec memory_recall(String.t(), String.t()) :: result()
  def memory_recall(workspace_slug, key) do
    with {:ok, result} <- Engine.run(workspace_slug, "search", [key, "--type", "memory"]) do
      emit(:memory_recall, workspace_slug, result.duration_ms)
      {:ok, result}
    end
  end

  @doc "Load the L0 cache (all node abstracts) for a workspace engine."
  @spec l0(String.t()) :: result()
  def l0(workspace_slug) do
    with {:ok, result} <- Engine.run(workspace_slug, "l0", []) do
      emit(:l0, workspace_slug, result.duration_ms)
      {:ok, result}
    end
  end

  @doc "Assemble tiered context for a topic."
  @spec assemble(String.t(), String.t()) :: result()
  def assemble(workspace_slug, topic) do
    with {:ok, result} <- Engine.run(workspace_slug, "assemble", [topic]) do
      emit(:assemble, workspace_slug, result.duration_ms)
      {:ok, result}
    end
  end

  @doc "Run the engine health diagnostic."
  @spec health(String.t()) :: result()
  def health(workspace_slug) do
    Engine.health(workspace_slug)
  end

  defp emit(action, workspace_slug, duration_ms) do
    :telemetry.execute(
      [:canopy, :engine, :bridge, action],
      %{duration_ms: duration_ms},
      %{workspace_slug: workspace_slug}
    )
  end
end
