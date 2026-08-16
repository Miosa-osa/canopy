defmodule Canopy.Runtimes.ClaudeLocal do
  @moduledoc """
  Runtime adapter for Claude Code CLI — the `claude` binary from Anthropic.

  Implements `Canopy.Runtimes.Adapter`.

  Behaviour is split across focused sub-modules:

  | Module    | Responsibility                                    |
  |-----------|---------------------------------------------------|
  | `Binary`  | Binary resolution + path-traversal guard          |
  | `Models`  | Static model catalogue + settings.json detection  |
  | `Config`  | Declarative config schema for the frontend form   |
  | `Args`    | CLI argument list + triple-key resume logic       |
  | `Env`     | `CANOPY_*` environment variable construction      |
  | `Bundle`  | SHA-256 bundle key + session-ID generation        |
  | `Parser`  | stream-json → TranscriptEntry translation         |
  | `Runner`  | GenServer owning the claude subprocess Port       |

  Canopy-specific behaviour: PubSub broadcast on `"session:<id>"`,
  `Canopy.Sessions.append_message/2` for DB persistence, `CANOPY_MIOSA_SANDBOX_URL`
  when a sandbox is provisioned, and `CANOPY_SESSION_ID` for agent self-correlation.

  If `append_message/2` returns `{:error, :not_implemented}` the Runner logs and
  continues — designed degraded-mode behaviour during parallel schema development.
  """

  @behaviour Canopy.Runtimes.Adapter

  alias Canopy.Runtimes.Bundle
  alias Canopy.Runtimes.ClaudeLocal.{Args, Binary, Config, Env, Models, Parser, Runner}
  alias Canopy.Runtimes.TranscriptEntry

  require Logger

  @impl true
  @spec type() :: String.t()
  def type, do: "claude-local"

  @impl true
  @spec capabilities() :: MapSet.t(Canopy.Runtimes.Adapter.capability())
  def capabilities do
    MapSet.new([
      :session_resume,
      :model_detection,
      :config_schema,
      :skill_injection,
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
         %{level: :info, message: "claude binary found at #{binary}"},
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
         {:ok, prompt_bundle_key} <-
           Bundle.compute_key(
             Map.get(context, "agents_md", ""),
             Map.get(context, "skills", []) |> List.wrap()
           ),
         {:ok, args} <- Args.build(context, prompt_bundle_key),
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
          {:ok,
           %{pid: pid, session_id: session_id, cwd: cwd, prompt_bundle_key: prompt_bundle_key}}

        {:error, reason} ->
          Logger.error("[ClaudeLocal] failed to start Runner: #{inspect(reason)}")
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
