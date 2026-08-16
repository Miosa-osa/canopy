defmodule Canopy.Runtimes.GeminiLocal do
  @moduledoc """
  Runtime adapter for Gemini CLI — the `gemini` binary from Google.

  Implements `Canopy.Runtimes.Adapter`.

  Behaviour is split across focused sub-modules:

  | Module    | Responsibility                                       |
  |-----------|------------------------------------------------------|
  | `Binary`  | Binary resolution + path-traversal guard             |
  | `Models`  | Static model catalogue + settings.json detection     |
  | `Config`  | Declarative config schema for the frontend form      |
  | `Args`    | CLI argument list + session resume logic             |
  | `Env`     | `CANOPY_*` / `GEMINI_API_KEY` env var construction   |
  | `Parser`  | JSONL → TranscriptEntry translation                  |
  | `Runner`  | GenServer owning the gemini subprocess Port          |

  ## Key differences from ClaudeLocal

  - **No stdin prompt** — Gemini CLI requires the prompt as `--prompt "<text>"`
    in the arg list. The Runner does NOT write to the Port's stdin.
  - **Session resume** — dual-key check (session_id + cwd) vs. Claude's triple
    (session_id + cwd + prompt_bundle_key). No prompt bundle optimisation.
  - **Thinking** — `:thinking` capability is included; Gemini 2.5 Pro/Flash
    support extended thinking via the `--thinking-budget` flag (not yet wired).
  - **No skill injection** — Gemini CLI skills are injected via symlinks in
    `~/.gemini/skills/`, a file-system operation outside Canopy's scope.
  - **No session resume in v1** — `:session_resume` is excluded from the
    initial capability set; the dual-key logic is implemented in Args and will
    be enabled once the session store wires up `external_session_id`.
  - **Quota windows** — not supported via CLI; returns `{:error, :not_supported}`.

  ## Canopy-specific behaviour

  - PubSub broadcast on `"session:<id>"`.
  - `Canopy.Sessions.append_message/2` for DB persistence with graceful
    degraded mode when schema migration is pending.
  - `CANOPY_SESSION_ID` / `CANOPY_API_URL` in the process environment.
  - `gemini_session_id` surfaced in the `:system` `completed` entry for
    session-resume wiring.
  """

  @behaviour Canopy.Runtimes.Adapter

  alias Canopy.Runtimes.Bundle
  alias Canopy.Runtimes.GeminiLocal.{Args, Binary, Config, Env, Models, Parser, Runner}
  alias Canopy.Runtimes.RegistryServer
  alias Canopy.Runtimes.TranscriptEntry

  require Logger

  @impl true
  @spec type() :: String.t()
  def type, do: "gemini-local"

  @impl true
  @spec capabilities() :: MapSet.t(Canopy.Runtimes.Adapter.capability())
  def capabilities do
    MapSet.new([
      :model_detection,
      :config_schema
    ])
  end

  @impl true
  @spec test_environment(map()) :: {:ok, [map()]} | {:error, term()}
  def test_environment(context) do
    binary = Binary.resolve(context)

    with :ok <- Binary.guard_path(binary),
         {:ok, version} <- Binary.run_version(binary) do
      {:ok,
       [
         %{level: :info, message: "gemini binary found at #{binary}"},
         %{level: :info, message: "version: #{version}"}
       ]}
    else
      {:error, :not_installed} -> {:error, :not_installed}
      {:error, {:binary_path_not_allowed, path}} -> {:error, {:binary_path_not_allowed, path}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  @spec detect_model() :: {:ok, map()} | {:error, :not_detected}
  def detect_model, do: Models.detect()

  @impl true
  @spec list_models() :: {:ok, [map()]} | {:error, term()}
  def list_models, do: Models.list()

  @impl true
  @spec get_config_schema() :: {:ok, [map()]}
  def get_config_schema, do: {:ok, Config.schema()}

  @impl true
  @spec get_quota_windows() :: {:ok, [map()]} | {:error, term()}
  def get_quota_windows, do: {:error, :not_supported}

  @impl true
  @spec execute(map()) :: {:ok, map()} | {:error, term()}
  def execute(context) do
    session_id = Map.get(context, "session_id") || Bundle.generate_id()
    binary = Binary.resolve(context)

    with :ok <- Binary.guard_path(binary),
         {:ok, args} <- Args.build(context),
         {:ok, env} <- Env.build(context, session_id),
         {:ok, cwd} <- resolve_cwd(context) do
      opts = [
        session_id: session_id,
        port_cmd: {binary, args},
        cwd: to_charlist(cwd),
        env: env,
        context: context
      ]

      case DynamicSupervisor.start_child(Canopy.Sessions.Supervisor, Runner.child_spec(opts)) do
        {:ok, pid} ->
          {:ok, %{pid: pid, session_id: session_id, cwd: cwd}}

        {:error, reason} ->
          Logger.error("[GeminiLocal] failed to start Runner: #{inspect(reason)}")
          {:error, {:runner_start_failed, reason}}
      end
    end
  end

  @impl true
  @spec list_skills(map()) :: {:ok, [map()]} | {:error, term()}
  def list_skills(_context), do: {:error, :not_implemented}

  @impl true
  @spec sync_skills(map(), [String.t()]) :: {:ok, map()} | {:error, term()}
  def sync_skills(_context, _desired_skills), do: {:error, :not_implemented}

  @doc """
  Registers this adapter in the Canopy runtime registry.

  Called during application boot by `Canopy.Application` after the Registry is
  started. The wire-up in `application.ex` is intentionally left for the
  application owner — this function provides the registration call.
  """
  @spec register() :: {:ok, pid()} | {:error, term()}
  def register, do: RegistryServer.register(__MODULE__)

  # CWD resolution — too small to justify a separate module (3 meaningful lines).
  @spec resolve_cwd(map()) :: {:ok, Path.t()} | {:error, term()}
  defp resolve_cwd(context) do
    cwd = Map.get(context, "cwd", "") |> to_string() |> String.trim()
    {:ok, Path.expand(if cwd != "", do: cwd, else: System.tmp_dir!())}
  end

  # Keep Parser + TranscriptEntry aliases live so the compiler does not warn on
  # unused aliases — both are referenced by test fixtures and the Runner sub-module.
  @doc false
  def __parser__, do: Parser

  @doc false
  def __entry__, do: TranscriptEntry
end
