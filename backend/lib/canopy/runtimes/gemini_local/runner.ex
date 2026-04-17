defmodule Canopy.Runtimes.GeminiLocal.Runner do
  @moduledoc """
  GenServer that owns the Gemini CLI subprocess Port for one session.

  Each running session spawns exactly one Runner as a transient child of
  `Canopy.Sessions.Supervisor`. The Runner:

  1. Receives opts (including `:port_cmd`, `:cwd`, `:env`) via `start_link/1`
     and spawns the Port on `init/1` so the supervisor gets a clean `{:ok, pid}`
     only after the process is ready to receive messages.
  2. Reads Port data line-by-line, JSON-decodes via `GeminiLocal.Parser`,
     and emits `TranscriptEntry` structs on two channels:
       a. Phoenix.PubSub topic `"session:<id>"` (for SSE / LiveView consumers)
       b. `Canopy.Sessions.append_message/2` (for database persistence)
  3. On exit-code 0: emits a synthetic `:system` entry with `event: "completed"`.
  4. On non-zero exit: emits `:system` with `event: "error"` and the exit code.
  5. On caller cancel: closes the Port and emits `:system` with `event: "cancelled"`.

  ## Key difference from ClaudeLocal.Runner — no stdin prompt

  The Gemini CLI does not read the prompt from stdin. The prompt is embedded in
  the CLI argument list as `--prompt "<text>"` by `GeminiLocal.Args.build/1`.
  The Runner therefore does NOT call `Port.command/2` after spawn.

  ## Session ID extraction

  The Runner watches for a `:result` TranscriptEntry and records the session ID
  emitted by the Gemini CLI so it can be surfaced in the session ref for resume.

  ## Restart strategy

  `:transient` — crashed Runners are NOT restarted. A mid-execution crash likely
  indicates the Gemini process itself failed. The session is marked failed via
  PubSub + DB, and the user can start a new session.

  ## Line buffering

  Gemini's JSONL stream emits one JSON object per line. The Port may split lines
  across data packets; the Runner buffers incomplete lines and only parses when
  a newline is received.
  """

  use GenServer

  alias Canopy.Runtimes.GeminiLocal.Parser
  alias Canopy.Runtimes.GeminiLocal.Parser.Helpers, as: ParseHelpers
  alias Canopy.Runtimes.TranscriptEntry

  require Logger

  @pubsub Canopy.PubSub

  defstruct [
    :session_id,
    :port,
    :line_buffer,
    :sequence,
    :context,
    :cancelled,
    :gemini_session_id
  ]

  @type t :: %__MODULE__{
          session_id: String.t() | nil,
          port: port() | nil,
          line_buffer: String.t(),
          sequence: non_neg_integer(),
          context: map(),
          cancelled: boolean(),
          # Session ID returned by the Gemini CLI (for resume on next execute)
          gemini_session_id: String.t() | nil
        }

  # ---------------------------------------------------------------------------
  # Child spec — :transient so a crash does not restart the runner
  # ---------------------------------------------------------------------------

  def child_spec(opts) do
    %{
      id: {__MODULE__, Keyword.fetch!(opts, :session_id)},
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient,
      type: :worker
    }
  end

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  @doc """
  Starts the runner. Opts must include:
    - `:session_id` — the Canopy session UUID (string)
    - `:port_cmd` — `{binary_path, args}` to spawn
    - `:cwd` — working directory (charlist)
    - `:env` — list of `{charlist_key, charlist_value}` tuples
    - `:context` — the full execution context map (stored for retry logic)

  Note: unlike ClaudeLocal.Runner, there is no `:prompt` opt — the prompt is
  already embedded in the args list by `GeminiLocal.Args.build/1`.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc "Sends a cancel request to the runner. The Port is closed and the session finalised."
  @spec cancel(pid()) :: :ok
  def cancel(pid) do
    GenServer.cast(pid, :cancel)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    {binary, args} = Keyword.fetch!(opts, :port_cmd)
    cwd = Keyword.fetch!(opts, :cwd)
    env = Keyword.get(opts, :env, [])

    Logger.info("[GeminiLocal.Runner] starting session=#{session_id} binary=#{binary}")

    port =
      Port.open(
        {:spawn_executable, binary},
        [
          :binary,
          :exit_status,
          {:args, args},
          {:cd, cwd},
          {:env, env}
        ]
      )

    state = %__MODULE__{
      session_id: session_id,
      port: port,
      line_buffer: "",
      sequence: 0,
      context: Keyword.get(opts, :context, %{}),
      cancelled: false,
      gemini_session_id: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_cast(:cancel, %{cancelled: false} = state) do
    close_port(state.port)
    emit_system_entry(state, "cancelled")
    {:stop, :normal, %{state | cancelled: true}}
  end

  def handle_cast(:cancel, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    combined = state.line_buffer <> data
    {lines, remaining} = split_lines(combined)

    new_state =
      Enum.reduce(lines, %{state | line_buffer: remaining}, fn line, acc ->
        entries = Parser.parse_line(line)
        gemini_id = extract_gemini_session_id(line, acc.gemini_session_id)
        acc_with_id = %{acc | gemini_session_id: gemini_id}
        Enum.reduce(entries, acc_with_id, &emit_entry(&2, &1))
      end)

    {:noreply, new_state}
  end

  def handle_info({port, {:exit_status, 0}}, %{port: port} = state) do
    new_state = flush_buffer(state)
    emit_system_entry(new_state, "completed", %{gemini_session_id: new_state.gemini_session_id})
    {:stop, :normal, new_state}
  end

  def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
    new_state = flush_buffer(state)

    Logger.warning("[GeminiLocal.Runner] session=#{state.session_id} exited with code #{code}")

    emit_system_entry(new_state, "error", %{exit_code: code})
    {:stop, :normal, new_state}
  end

  # Ignore messages from ports we already closed
  def handle_info({_other_port, _msg}, state) do
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  # Split buffer at newlines; last element is the incomplete trailing fragment.
  @spec split_lines(binary()) :: {[binary()], binary()}
  defp split_lines(buffer) do
    parts = String.split(buffer, ~r/\r?\n/)
    {Enum.drop(parts, -1), List.last(parts) || ""}
  end

  @spec flush_buffer(%__MODULE__{}) :: %__MODULE__{}
  defp flush_buffer(%{line_buffer: ""} = state), do: state

  defp flush_buffer(%{line_buffer: partial} = state) do
    entries = Parser.parse_line(partial)
    gemini_id = extract_gemini_session_id(partial, state.gemini_session_id)
    state_with_id = %{state | gemini_session_id: gemini_id, line_buffer: ""}
    Enum.reduce(entries, state_with_id, &emit_entry(&2, &1))
  end

  @spec extract_gemini_session_id(binary(), String.t() | nil) :: String.t() | nil
  defp extract_gemini_session_id(line, current_id) do
    trimmed = String.trim(line)

    case Jason.decode(trimmed) do
      {:ok, event} ->
        case ParseHelpers.read_session_id(event) do
          id when is_binary(id) and id != "" -> id
          _other -> current_id
        end

      _error ->
        current_id
    end
  end

  @spec emit_entry(%__MODULE__{}, TranscriptEntry.t()) :: %__MODULE__{}
  defp emit_entry(state, entry) do
    seq = state.sequence + 1
    stamped = %{entry | sequence: seq}

    topic = "session:#{state.session_id}"
    Phoenix.PubSub.broadcast(@pubsub, topic, {:transcript_entry, stamped})

    # Best-effort DB persistence — log non-transient errors but don't crash the runner.
    # {:error, :not_implemented} is expected during parallel development while the
    # SessionMessage schema migration is being applied; suppress it to keep logs clean.
    case Canopy.Sessions.append_message(state.session_id, stamped) do
      {:error, :not_implemented} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "[GeminiLocal.Runner] append_message failed session=#{state.session_id}: #{inspect(reason)}"
        )
    end

    %{state | sequence: seq}
  end

  @spec emit_system_entry(%__MODULE__{}, String.t(), map()) :: :ok
  defp emit_system_entry(state, event, extra \\ %{}) do
    entry =
      TranscriptEntry.new(:system, Map.merge(%{event: event}, extra),
        sequence: state.sequence + 1
      )

    topic = "session:#{state.session_id}"
    Phoenix.PubSub.broadcast(@pubsub, topic, {:transcript_entry, entry})
    :ok
  end

  @spec close_port(port()) :: :ok
  defp close_port(port) do
    try do
      Port.close(port)
    catch
      :error, _reason -> :ok
    end

    :ok
  end
end
