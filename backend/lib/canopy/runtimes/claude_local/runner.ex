defmodule Canopy.Runtimes.ClaudeLocal.Runner do
  @moduledoc """
  GenServer that owns the Claude subprocess Port for one session.

  Each running session spawns exactly one Runner as a transient child of
  `Canopy.Sessions.Supervisor`. The Runner:

  1. Receives `{:run, context}` via `start_link/1` opts; spawns the Port
     on `init/1` so the supervisor gets a clean `{:ok, pid}` only after
     the process is ready to receive messages.
  2. Reads Port data line-by-line, JSON-decodes via `ClaudeLocal.Parser`,
     and emits `TranscriptEntry` structs on two channels:
       a. Phoenix.PubSub topic `"session:<id>"` (for SSE / LiveView consumers)
       b. `Canopy.Sessions.append_message/2` (for database persistence)
  3. On exit-code 0: emits a synthetic `:system` entry with `event: "completed"`.
  4. On non-zero exit: emits `:system` with `event: "error"`.
  5. On caller cancel: closes the Port and emits `:system` with `event: "cancelled"`.

  The caller (ClaudeLocal.execute/1) receives `{:ok, session_ref}` immediately;
  the Runner runs asynchronously and the session owner subscribes to PubSub for
  live updates.

  Restart strategy: `:transient` — crashed Runners are NOT restarted because a
  mid-execution crash likely indicates the Claude process itself failed. The
  session is marked failed via PubSub + DB, and the user can start a new session.

  Line buffering: Claude's stream-json emits one JSON object per line. The Port
  may split lines across data packets; the Runner buffers incomplete lines and
  only parses when a newline is received.
  """

  use GenServer

  alias Canopy.Runtimes.ClaudeLocal.Parser
  alias Canopy.Runtimes.TranscriptEntry

  require Logger

  @pubsub Canopy.PubSub

  defstruct [
    :session_id,
    :port,
    :line_buffer,
    :sequence,
    :context,
    :cancelled
  ]

  @type t :: %__MODULE__{
          session_id: String.t() | nil,
          port: port() | nil,
          line_buffer: String.t(),
          sequence: non_neg_integer(),
          context: map(),
          cancelled: boolean()
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
    - `:prompt` — the stdin prompt binary to write after spawn
    - `:context` — the full execution context map (stored for retry logic)
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
    prompt = Keyword.get(opts, :prompt, "")

    Logger.info("[ClaudeLocal.Runner] starting session=#{session_id} binary=#{binary}")

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

    # Write the prompt to stdin immediately
    unless prompt == "" do
      Port.command(port, prompt <> "\n")
    end

    state = %__MODULE__{
      session_id: session_id,
      port: port,
      line_buffer: "",
      sequence: 0,
      context: Keyword.get(opts, :context, %{}),
      cancelled: false
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
        Enum.reduce(entries, acc, &emit_entry(&2, &1))
      end)

    {:noreply, new_state}
  end

  def handle_info({port, {:exit_status, 0}}, %{port: port} = state) do
    # Flush any remaining buffered partial line
    new_state = flush_buffer(state)
    emit_system_entry(new_state, "completed")
    {:stop, :normal, new_state}
  end

  def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
    new_state = flush_buffer(state)
    Logger.warning("[ClaudeLocal.Runner] session=#{state.session_id} exited with code #{code}")
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
    # All but last are complete lines; last is the partial fragment (may be "")
    {Enum.drop(parts, -1), List.last(parts) || ""}
  end

  @spec flush_buffer(%__MODULE__{}) :: %__MODULE__{}
  defp flush_buffer(%{line_buffer: ""} = state), do: state

  defp flush_buffer(%{line_buffer: partial} = state) do
    entries = Parser.parse_line(partial)
    Enum.reduce(entries, %{state | line_buffer: ""}, &emit_entry(&2, &1))
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
          "[ClaudeLocal.Runner] append_message failed session=#{state.session_id}: #{inspect(reason)}"
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
