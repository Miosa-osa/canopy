defmodule Canopy.Runtimes.CodexLocal do
  @moduledoc """
  Runtime adapter for Codex CLI — the `codex` binary from OpenAI.

  Implements `Canopy.Runtimes.Adapter`.

  Behaviour is split across focused sub-modules:

  | Module    | Responsibility                                    |
  |-----------|---------------------------------------------------|
  | `Binary`  | Binary resolution + path-traversal guard          |
  | `Models`  | Static model catalogue + ~/.codex/config.json detection |
  | `Config`  | Declarative config schema for the frontend form   |
  | `Args`    | CLI argument list + session resume logic          |
  | `Env`     | `CANOPY_*` + `CODEX_HOME` env var construction   |
  | `Parser`  | Codex JSONL stream → TranscriptEntry translation  |
  | `Runner`  | GenServer owning the codex subprocess Port        |

  ## Codex stream format

  Codex emits JSONL events on stdout when invoked with `exec --json`.
  The primary event types are:

  - `thread.started` — session init, carries `thread_id`
  - `item.completed` — agent message, tool call, tool result, or reasoning
  - `turn.completed` — end of turn with usage stats
  - `turn.failed` / `error` — error conditions

  ## Capabilities

  Codex supports session resume via `codex exec resume <thread_id> -`.
  Skill injection (writing skills into `CODEX_HOME/skills/`) is not yet
  implemented. Model detection reads `~/.codex/config.json`. Quota windows
  are not currently surfaced via the CLI.

  ## Registration

  Call `register/0` explicitly from `Application.start/2` to register this
  adapter with `Canopy.Runtimes.RegistryServer`. Auto-registration is deliberately
  avoided to keep the Application module in control of startup order.
  """

  @behaviour Canopy.Runtimes.Adapter

  alias Canopy.Runtimes.Bundle
  alias Canopy.Runtimes.CodexLocal.{Args, Binary, Config, Env, Models, Parser, Runner}
  alias Canopy.Runtimes.RegistryServer
  alias Canopy.Runtimes.TranscriptEntry

  require Logger

  @impl true
  @spec type() :: String.t()
  def type, do: "codex-local"

  @impl true
  @spec capabilities() :: MapSet.t(Canopy.Runtimes.Adapter.capability())
  def capabilities do
    MapSet.new([
      :session_resume,
      :model_detection,
      :config_schema,
      :quota_windows
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
         %{level: :info, message: "codex binary found at #{binary}"},
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
        prompt: Map.get(context, "prompt", ""),
        context: context
      ]

      case DynamicSupervisor.start_child(Canopy.Sessions.Supervisor, Runner.child_spec(opts)) do
        {:ok, pid} ->
          {:ok, %{pid: pid, session_id: session_id, cwd: cwd}}

        {:error, reason} ->
          Logger.error("[CodexLocal] failed to start Runner: #{inspect(reason)}")
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
  Registers this adapter with `Canopy.Runtimes.RegistryServer`.

  Call this from `Application.start/2` after the Registry process has started.
  Do not call during module load — the Registry process may not exist yet.
  """
  @spec register() :: {:ok, pid()} | {:error, term()}
  def register do
    RegistryServer.register(__MODULE__)
  end

  # CWD resolution — too small to justify a separate module.
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
