defmodule Canopy.Adapter do
  @moduledoc """
  Behaviour contract for agent execution adapters.

  Each adapter knows how to start/stop agent sessions and execute
  heartbeat runs via a specific backend (OSA, Claude Code, Bash, etc.).

  `execute_heartbeat/1` and `send_message/2` return a `Stream` of event maps
  that get broadcast to SSE/WebSocket subscribers and persisted as session_events.
  """

  @type event :: %{
          event_type: String.t(),
          data: map(),
          tokens: non_neg_integer()
        }

  @callback type() :: String.t()
  @callback name() :: String.t()
  @callback start(config :: map()) :: {:ok, session :: map()} | {:error, term()}
  @callback stop(session :: map()) :: :ok | {:error, term()}
  @callback execute_heartbeat(params :: map()) :: Enumerable.t()
  @callback send_message(session :: map(), message :: String.t()) :: Enumerable.t()
  @callback supports_session?() :: boolean()
  @callback supports_concurrent?() :: boolean()
  @callback capabilities() :: [atom()]

  @doc """
  Check if the adapter's runtime dependency is available.

  Returns `:ok` if the adapter is ready to execute, or
  `{:error, reason}` if the required binary, API key, or service is missing.
  """
  @callback health() :: :ok | {:error, String.t()}

  @doc "Resolve adapter module from string type."
  def resolve("osa"), do: {:ok, Canopy.Adapters.OSA}
  def resolve("claude-code"), do: {:ok, Canopy.Adapters.ClaudeCode}
  def resolve("codex"), do: {:ok, Canopy.Adapters.Codex}
  def resolve("bash"), do: {:ok, Canopy.Adapters.Bash}
  def resolve("http"), do: {:ok, Canopy.Adapters.HTTP}
  def resolve("openclaw"), do: {:ok, Canopy.Adapters.OpenClaw}
  def resolve("cursor"), do: {:ok, Canopy.Adapters.Cursor}
  def resolve("gemini"), do: {:ok, Canopy.Adapters.Gemini}
  def resolve("aider"), do: {:ok, Canopy.Adapters.Aider}
  def resolve("jido-claw"), do: {:ok, Canopy.Adapters.JidoClaw}
  def resolve("windsurf"), do: {:ok, Canopy.Adapters.Windsurf}
  def resolve(type), do: {:error, {:unknown_adapter, type}}

  @adapters [
    Canopy.Adapters.OSA,
    Canopy.Adapters.ClaudeCode,
    Canopy.Adapters.Codex,
    Canopy.Adapters.Bash,
    Canopy.Adapters.HTTP,
    Canopy.Adapters.OpenClaw,
    Canopy.Adapters.Cursor,
    Canopy.Adapters.Gemini,
    Canopy.Adapters.Aider,
    Canopy.Adapters.JidoClaw,
    Canopy.Adapters.Windsurf
  ]

  @doc "List all registered adapters with metadata."
  def all do
    @adapters
    |> Enum.map(fn mod ->
      %{
        type: mod.type(),
        name: mod.name(),
        supports_session: mod.supports_session?(),
        supports_concurrent: mod.supports_concurrent?(),
        capabilities: mod.capabilities()
      }
    end)
  end

  @doc "List all adapters with health status included."
  def health_all do
    @adapters
    |> Enum.map(fn mod ->
      health =
        try do
          mod.health()
        rescue
          e -> {:error, "health check raised: #{Exception.message(e)}"}
        end

      %{
        type: mod.type(),
        name: mod.name(),
        supports_session: mod.supports_session?(),
        supports_concurrent: mod.supports_concurrent?(),
        capabilities: mod.capabilities(),
        health: health
      }
    end)
  end
end
