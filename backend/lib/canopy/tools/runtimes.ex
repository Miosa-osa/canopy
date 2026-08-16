defmodule Canopy.Tools.Runtimes do
  @moduledoc """
  Conductor tool surface for **embedding a runtime into the active pane**.

  This module is intentionally narrow — it owns the single `runtime.spawn`
  tool that the Build cockpit needs to satisfy `/claude`, `/codex`,
  `/gemini`, etc. slash commands. The richer runtime management surface
  (detection, swapping, credentials, MCP, checkpoints) lives in
  `Canopy.Tools.RuntimeAdapter`.

  ## Why a separate module

  `runtime.spawn` is the **missing Conductor piece** that bridges runtime
  adapters and the Mosaic dispatcher. The frontend `BuildDispatcher` already
  knows how to consume `{ action: "embed_runtime", ... }` payloads (it sets
  `pane.config.embeddedRuntime`). This tool produces that payload — nothing
  more, nothing less.

  Sessions are created via `Canopy.Sessions.create/1` so all the existing
  governance + budget gates fire normally. If a `session_id` is supplied
  the tool short-circuits — the agent assumes the session already exists
  and we just want the dispatcher to embed it.
  """

  use Canopy.Tool

  alias Canopy.Runtimes
  alias Canopy.Sessions

  tool("runtime.spawn",
    description: """
    Spawn a runtime (Claude Code, Codex, Gemini, ...) into the currently
    active Build pane. Either creates a fresh Session via
    `Canopy.Sessions.create/1` and asks the dispatcher to embed it, or
    embeds an existing session if `session_id` is supplied.

    Returns a payload the BuildDispatcher consumes:
      `{ action: "embed_runtime", runtime_type, session_id, embed_into_pane: true, cwd }`
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "type" => %{
          "type" => "string",
          "description" =>
            "Runtime type identifier — must match a registered adapter (e.g. \"claude-local\")"
        },
        "session_id" => %{
          "type" => "string",
          "description" =>
            "Optional existing session UUID. When supplied, no new session is created."
        },
        "cwd" => %{
          "type" => "string",
          "description" => "Working directory for the spawned runtime."
        },
        "workspace_slug" => %{"type" => "string"},
        "agent_slug" => %{"type" => "string"}
      },
      "required" => ["type"]
    },
    handler: {__MODULE__, :spawn_runtime, []},
    requires: [:runtimes]
  )

  @doc false
  @spec spawn_runtime(map()) :: {:ok, map()} | {:error, term()}
  def spawn_runtime(%{"type" => type} = args) when is_binary(type) and type != "" do
    with {:ok, _adapter} <- Runtimes.lookup_adapter(type),
         {:ok, session_id} <- ensure_session(type, args) do
      {:ok,
       %{
         action: "embed_runtime",
         runtime_type: type,
         session_id: session_id,
         embed_into_pane: true,
         cwd: args["cwd"]
       }}
    else
      {:error, :not_found} ->
        {:error, %{reason: "unknown_runtime", type: type}}

      {:error, %Ecto.Changeset{} = cs} ->
        {:error, %{reason: "validation_failed", errors: changeset_errors(cs)}}

      {:error, reason} ->
        {:error, %{reason: inspect(reason)}}
    end
  end

  def spawn_runtime(_), do: {:error, %{reason: "type is required"}}

  # ---------------------------------------------------------------------------
  # Session resolution
  # ---------------------------------------------------------------------------

  # When `session_id` is supplied, trust it (the agent already knows the
  # session). Otherwise create a fresh session pinned to the runtime type.
  defp ensure_session(_type, %{"session_id" => sid}) when is_binary(sid) and sid != "" do
    {:ok, sid}
  end

  defp ensure_session(type, args) do
    attrs = %{
      "runtime_type" => type,
      "agent_slug" => args["agent_slug"] || "conductor",
      "workspace_slug" => args["workspace_slug"],
      "prompt" => "",
      "status" => "running"
    }

    case Sessions.create(attrs) do
      {:ok, session} -> {:ok, session.id}
      {:error, _} = err -> err
    end
  end

  defp changeset_errors(%Ecto.Changeset{errors: errors}) do
    Enum.map(errors, fn {field, {msg, _}} -> %{field: field, message: msg} end)
  end
end
