defmodule Canopy.Sessions.PtyBridge do
  @moduledoc """
  GenServer that owns one pty process per session.

  Spawns the subprocess via erlexec with the `:pty` flag, which allocates a
  real pseudo-TTY pair via openpty(3). This gives the child process a genuine
  /dev/pts device on stdin/stdout, satisfying interactive CLIs (Claude Code,
  bash) that check isatty(stdin).

  Output bytes arrive as `{:stdout, os_pid, data}` erlexec messages and are
  forwarded to subscribed channel pids as `{:pty_output, data}`. On process
  exit, subscribers receive `{:pty_exit, code}` and the GenServer records the
  exit code but does NOT stop — it holds state so late-attaching subscribers
  (race in the channel join path) get the exit event immediately on attach.

  One bridge per session, registered in `Canopy.Sessions.PtyRegistry`.

  ## Lifecycle
  The pty outlives individual channel disconnects. Attach/detach is used for
  channel lifecycle; stop/1 or session deletion is the only kill path.

  ## Output Batching
  Instead of forwarding every {:stdout, os_pid, data} message immediately,
  chunks are coalesced into a
  list buffer for up to @flush_interval_ms (32ms, ~30fps max). The flush fires
  immediately if accumulated bytes hit @flush_max_bytes (128KB). Chunks are
  prepended (O(1)) and reversed once at flush time (O(n) total vs O(n²) naive
  concatenation). Subscribers still receive the same {:pty_output, data} API.

  ## Stdin Write Queue
  Input is queued and drained on a periodic timer instead of calling
  :exec.send/2 immediately. A high-watermark (8MB) suspends client writes;
  a low-watermark (4MB) reopens the valve. A hard limit (64MB) drops writes
  entirely. Exponential backoff (2ms→50ms) handles :exec.send errors.

  ## Pause / Resume
  Pause gates message forwarding at the GenServer level — the child process
  keeps running and the PTY kernel buffer absorbs its output. While paused,
  output that would have flushed goes into the pause buffer (cap 64 KB) rather
  than to subscribers. Oldest bytes are dropped when the cap is exceeded. On
  resume the pause buffer is sent as a single :pty_output frame.

  ## Resize
  `resize/3` calls `:exec.winsz/3` to send TIOCSWINSZ to the real PTY so the
  child process receives SIGWINCH and re-renders at the new dimensions.

  ## Public API
  start_link/5, attach/2, detach/2, send_input/2, resize/3, pause/1, resume/1, stop/1
  """

  use GenServer, restart: :temporary

  # erlexec is a rebar3/Erlang dep — its module is available at runtime via the
  # erlexec OTP application but Mix cannot resolve it at compile time. Suppress
  # the undefined-module warnings so --warnings-as-errors stays green.
  @compile {:no_warn_undefined, :exec}

  alias Canopy.Heartbeats

  require Logger

  @type session_id :: binary()

  # ---------------------------------------------------------------------------
  # Tunables
  # ---------------------------------------------------------------------------

  # Output batching
  @flush_interval_ms 32
  @flush_max_bytes 131_072

  # Stdin write queue watermarks
  @stdin_high_watermark 8 * 1024 * 1024
  @stdin_low_watermark 4 * 1024 * 1024
  @stdin_hard_limit 64 * 1024 * 1024
  @drain_interval_ms 10

  # Exponential write-backoff bounds (milliseconds)
  @backoff_min_ms 2
  @backoff_max_ms 50

  # Pause buffer cap (existing behaviour preserved)
  @buffer_cap 65_536

  defstruct [
    :session_id,
    :os_pid,
    :pid,
    :exit_code,
    subscribers: MapSet.new(),
    cols: 80,
    rows: 24,

    # Pause buffer (existing) — accumulates bytes while paused
    paused: false,
    buffer: <<>>,

    # Output batching (new)
    pending_output: [],
    pending_bytes: 0,
    flush_timer: nil,

    # Stdin write queue (new)
    stdin_queue: :queue.new(),
    stdin_bytes: 0,
    stdin_paused: false,
    drain_timer: nil,

    # Exponential backoff for :exec.send errors
    write_backoff_ms: 0
  ]

  # ---------------------------------------------------------------------------
  # Child spec — for DynamicSupervisor.start_child/2
  # ---------------------------------------------------------------------------

  @doc false
  def child_spec({session_id, command, args, env}) do
    %{
      id: {__MODULE__, session_id},
      start: {__MODULE__, :start_link, [session_id, command, args, env, nil]},
      restart: :temporary
    }
  end

  def child_spec({session_id, command, args, env, cwd}) do
    %{
      id: {__MODULE__, session_id},
      start: {__MODULE__, :start_link, [session_id, command, args, env, cwd]},
      restart: :temporary
    }
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Starts a PtyBridge for the given session. Registered in PtyRegistry."
  @spec start_link(session_id(), binary(), [binary()], [{binary(), binary()}], binary() | nil) ::
          GenServer.on_start()
  def start_link(session_id, command, args, env, cwd) do
    GenServer.start_link(__MODULE__, {session_id, command, args, env, cwd}, name: via(session_id))
  end

  @doc """
  Subscribes `pid` to receive `{:pty_output, data}` and `{:pty_exit, code}` messages.
  If the process already exited, sends `{:pty_exit, code}` immediately.
  """
  @spec attach(session_id(), pid()) :: :ok
  def attach(session_id, pid) do
    GenServer.call(via(session_id), {:attach, pid})
  end

  @doc "Unsubscribes `pid` from pty messages. Never stops the pty. No-op if bridge is gone."
  @spec detach(session_id(), pid()) :: :ok
  def detach(session_id, pid) do
    case Registry.lookup(Canopy.Sessions.PtyRegistry, session_id) do
      [{bridge_pid, _}] -> GenServer.cast(bridge_pid, {:detach, pid})
      [] -> :ok
    end
  end

  @doc "Writes `data` to the pty stdin."
  @spec send_input(session_id(), binary()) :: :ok
  def send_input(session_id, data) do
    GenServer.cast(via(session_id), {:input, data})
  end

  @doc "Sends TIOCSWINSZ to the real PTY so the child process resizes."
  @spec resize(session_id(), pos_integer(), pos_integer()) :: :ok
  def resize(session_id, cols, rows) do
    GenServer.cast(via(session_id), {:resize, cols, rows})
  end

  @doc "Pauses output forwarding. The subprocess keeps running; output is buffered (cap 64 KB)."
  @spec pause(session_id()) :: :ok
  def pause(session_id) do
    case Registry.lookup(Canopy.Sessions.PtyRegistry, session_id) do
      [{pid, _}] -> GenServer.cast(pid, :pause)
      [] -> :ok
    end
  end

  @doc "Resumes output forwarding, flushing any buffered bytes to subscribers."
  @spec resume(session_id()) :: :ok
  def resume(session_id) do
    case Registry.lookup(Canopy.Sessions.PtyRegistry, session_id) do
      [{pid, _}] -> GenServer.cast(pid, :resume)
      [] -> :ok
    end
  end

  @doc "Stops the pty bridge (kills the subprocess). Use detach/2 for channel disconnect."
  @spec stop(session_id()) :: :ok
  def stop(session_id) do
    case Registry.lookup(Canopy.Sessions.PtyRegistry, session_id) do
      [{pid, _}] -> GenServer.stop(pid, :normal)
      [] -> :ok
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init({session_id, command, args, env, cwd}) do
    # erlexec env expects charlists for both key and value.
    exec_env =
      Enum.map(env, fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)

    cmd_charlist = String.to_charlist(command)
    args_charlists = Enum.map(args, &String.to_charlist/1)

    exec_opts =
      [:stdin, :stdout, :stderr, :pty, {:env, exec_env}, :monitor] ++
        if(is_binary(cwd) and cwd != "", do: [{:cd, String.to_charlist(cwd)}], else: [])

    case :exec.run([cmd_charlist | args_charlists], exec_opts) do
      {:ok, pid, os_pid} ->
        state = %__MODULE__{
          session_id: session_id,
          os_pid: os_pid,
          pid: pid,
          subscribers: MapSet.new()
        }

        Logger.info(
          "[PtyBridge] started session_id=#{session_id} command=#{command} os_pid=#{os_pid}"
        )

        {:ok, state}

      {:error, reason} ->
        Logger.error(
          "[PtyBridge] failed to start pty session_id=#{session_id} command=#{command}: #{inspect(reason)}"
        )

        {:stop, {:pty_start_failed, reason}}
    end
  end

  @impl true
  def handle_call({:attach, pid}, _from, state) do
    Process.monitor(pid)
    new_subscribers = MapSet.put(state.subscribers, pid)
    new_state = %{state | subscribers: new_subscribers}

    # If the process already exited before this attach call (race in join path),
    # immediately deliver the exit event to the newly-subscribed pid.
    if state.exit_code != nil do
      send(pid, {:pty_exit, state.exit_code})
    end

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:detach, pid}, state) do
    {:noreply, %{state | subscribers: MapSet.delete(state.subscribers, pid)}}
  end

  # ---------------------------------------------------------------------------
  # Stdin write queue — enqueue on input cast, drain on timer
  # ---------------------------------------------------------------------------

  @impl true
  def handle_cast({:input, data}, state) do
    byte_count = byte_size(data)

    if state.stdin_bytes + byte_count > @stdin_hard_limit do
      Logger.warning(
        "[PtyBridge] stdin hard limit exceeded session_id=#{state.session_id} — dropping #{byte_count} bytes"
      )

      async_record(state.session_id, :input, data)
      {:noreply, state}
    else
      new_queue = :queue.in(data, state.stdin_queue)
      new_bytes = state.stdin_bytes + byte_count

      new_stdin_paused =
        if new_bytes > @stdin_high_watermark and not state.stdin_paused do
          Logger.debug(
            "[PtyBridge] stdin high-watermark reached session_id=#{state.session_id} queued=#{new_bytes}"
          )

          true
        else
          state.stdin_paused
        end

      # Schedule drain timer if not already running
      new_drain_timer =
        if state.drain_timer == nil do
          Process.send_after(self(), :drain_stdin, @drain_interval_ms)
        else
          state.drain_timer
        end

      async_record(state.session_id, :input, data)

      {:noreply,
       %{
         state
         | stdin_queue: new_queue,
           stdin_bytes: new_bytes,
           stdin_paused: new_stdin_paused,
           drain_timer: new_drain_timer
       }}
    end
  end

  @impl true
  def handle_cast(:pause, state) do
    Logger.debug("[PtyBridge] paused session_id=#{state.session_id}")
    async_record(state.session_id, :pause, "")
    {:noreply, %{state | paused: true}}
  end

  @impl true
  def handle_cast(:resume, state) do
    Logger.debug(
      "[PtyBridge] resumed session_id=#{state.session_id} buffered=#{byte_size(state.buffer)}"
    )

    async_record(state.session_id, :resume, "")

    unless state.buffer == <<>> do
      broadcast(state.subscribers, {:pty_output, state.buffer})
    end

    {:noreply, %{state | paused: false, buffer: <<>>}}
  end

  @impl true
  def handle_cast({:resize, cols, rows}, state) do
    :exec.winsz(state.os_pid, rows, cols)
    Logger.debug("[PtyBridge] resize cols=#{cols} rows=#{rows} os_pid=#{state.os_pid}")
    {:noreply, %{state | cols: cols, rows: rows}}
  end

  # ---------------------------------------------------------------------------
  # erlexec stdout — output batching
  # ---------------------------------------------------------------------------

  # erlexec stdout data — includes both stdout and stderr (merged on pty).
  @impl true
  def handle_info({:stdout, os_pid, data}, %{os_pid: os_pid} = state) do
    async_record(state.session_id, :output, data)
    {:noreply, enqueue_output(data, state)}
  end

  # erlexec stderr data (separate stream, forwarded same as stdout).
  @impl true
  def handle_info({:stderr, os_pid, data}, %{os_pid: os_pid} = state) do
    handle_info({:stdout, os_pid, data}, state)
  end

  # ---------------------------------------------------------------------------
  # Output batch flush timer
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info(:flush_output, state) do
    {:noreply, do_flush_output(%{state | flush_timer: nil})}
  end

  # ---------------------------------------------------------------------------
  # Stdin drain timer
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info(:drain_stdin, state) do
    state = %{state | drain_timer: nil}

    case :queue.out(state.stdin_queue) do
      {:empty, _} ->
        {:noreply, state}

      {{:value, chunk}, rest_queue} ->
        new_bytes = state.stdin_bytes - byte_size(chunk)

        new_state =
          case exec_send(state.os_pid, chunk, state.write_backoff_ms) do
            {:ok, backoff} ->
              new_stdin_paused =
                if state.stdin_paused and new_bytes < @stdin_low_watermark do
                  Logger.debug(
                    "[PtyBridge] stdin low-watermark cleared session_id=#{state.session_id}"
                  )

                  false
                else
                  state.stdin_paused
                end

              %{
                state
                | stdin_queue: rest_queue,
                  stdin_bytes: new_bytes,
                  stdin_paused: new_stdin_paused,
                  write_backoff_ms: backoff
              }

            {:error, backoff} ->
              # Re-queue the chunk at front and retry after backoff
              Logger.debug(
                "[PtyBridge] exec.send error — retrying in #{backoff}ms session_id=#{state.session_id}"
              )

              %{state | write_backoff_ms: backoff}
          end

        # Reschedule drain if there's more in queue
        new_drain_timer =
          if not :queue.is_empty(new_state.stdin_queue) do
            delay =
              if new_state.write_backoff_ms > 0,
                do: new_state.write_backoff_ms,
                else: @drain_interval_ms

            Process.send_after(self(), :drain_stdin, delay)
          else
            nil
          end

        {:noreply, %{new_state | drain_timer: new_drain_timer}}
    end
  end

  # ---------------------------------------------------------------------------
  # erlexec process exit
  # ---------------------------------------------------------------------------

  # erlexec process exit — sent because we passed :monitor in opts.
  # Keep GenServer alive (do not stop) so late-attaching subscribers get the exit.
  @impl true
  def handle_info({:DOWN, os_pid, :process, _pid, reason}, %{os_pid: os_pid} = state) do
    code =
      case reason do
        :normal -> 0
        {:exit_status, n} -> n
        _ -> 1
      end

    Logger.info("[PtyBridge] process exited session_id=#{state.session_id} code=#{code}")
    async_record(state.session_id, :exit, "", %{"exit_code" => code})

    # Drain pending output before broadcasting exit
    state = do_flush_output(state)

    broadcast(state.subscribers, {:pty_exit, code})
    {:noreply, %{state | exit_code: code}}
  end

  # Subscriber channel process died — remove from MapSet.
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, %{state | subscribers: MapSet.delete(state.subscribers, pid)}}
  end

  # Task.Supervisor.async_nolink/2 sends {ref, result} back to the caller.
  # Heartbeat tasks are fire-and-forget — discard the reply silently.
  @impl true
  def handle_info({ref, _result}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Flush any pending output before going down
    do_flush_output(state)

    if state.os_pid do
      :exec.stop(state.os_pid)
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Private — output batching
  # ---------------------------------------------------------------------------

  # Enqueue a chunk, flush immediately if over cap, otherwise arm the timer.
  defp enqueue_output(data, state) do
    new_pending = [data | state.pending_output]
    new_bytes = state.pending_bytes + byte_size(data)

    cond do
      new_bytes >= @flush_max_bytes ->
        # Immediate flush — cancel any existing timer
        if state.flush_timer do
          Process.cancel_timer(state.flush_timer)
        end

        do_flush_output(%{
          state
          | pending_output: new_pending,
            pending_bytes: new_bytes,
            flush_timer: nil
        })

      state.flush_timer == nil ->
        # Arm the interval timer (first chunk in this window)
        timer = Process.send_after(self(), :flush_output, @flush_interval_ms)
        %{state | pending_output: new_pending, pending_bytes: new_bytes, flush_timer: timer}

      true ->
        # Timer already armed — just buffer
        %{state | pending_output: new_pending, pending_bytes: new_bytes}
    end
  end

  # Concatenate pending chunks and deliver to subscribers or pause buffer.
  defp do_flush_output(%{pending_output: []} = state), do: state

  defp do_flush_output(state) do
    # Chunks were prepended (O(1) each); reverse once for correct order, then join O(n).
    data = :erlang.iolist_to_binary(Enum.reverse(state.pending_output))
    state = %{state | pending_output: [], pending_bytes: 0}

    if state.paused do
      combined = state.buffer <> data

      new_buffer =
        if byte_size(combined) > @buffer_cap do
          :binary.part(combined, byte_size(combined) - @buffer_cap, @buffer_cap)
        else
          combined
        end

      %{state | buffer: new_buffer}
    else
      broadcast(state.subscribers, {:pty_output, data})
      state
    end
  end

  # ---------------------------------------------------------------------------
  # Private — stdin write with backoff
  # ---------------------------------------------------------------------------

  # Attempt :exec.send/2. On error, double the backoff (capped). On success, reset it.
  # Returns {:ok, new_backoff} | {:error, new_backoff}.
  defp exec_send(os_pid, data, current_backoff) do
    case :exec.send(os_pid, data) do
      :ok ->
        {:ok, 0}

      {:error, reason} ->
        new_backoff =
          if current_backoff == 0 do
            @backoff_min_ms
          else
            min(current_backoff * 2, @backoff_max_ms)
          end

        Logger.debug("[PtyBridge] exec.send error: #{inspect(reason)} backoff=#{new_backoff}ms")
        {:error, new_backoff}
    end
  end

  # ---------------------------------------------------------------------------
  # Private — helpers
  # ---------------------------------------------------------------------------

  @spec via(session_id()) :: {:via, Registry, {Canopy.Sessions.PtyRegistry, session_id()}}
  defp via(session_id), do: {:via, Registry, {Canopy.Sessions.PtyRegistry, session_id}}

  @spec broadcast(MapSet.t(), term()) :: :ok
  defp broadcast(subscribers, message) do
    Enum.each(subscribers, fn pid -> send(pid, message) end)
  end

  # Fire-and-forget heartbeat write — never blocks the pty loop.
  @spec async_record(binary(), atom(), binary(), map()) :: :ok
  defp async_record(session_id, kind, payload, meta \\ %{}) do
    caller = self()
    sandbox_pool? = Application.get_env(:canopy, Canopy.Repo)[:pool] == Ecto.Adapters.SQL.Sandbox

    Task.Supervisor.start_child(Canopy.TaskSupervisor, fn ->
      if sandbox_pool? do
        Ecto.Adapters.SQL.Sandbox.allow(Canopy.Repo, caller, self())
      end

      Heartbeats.record(session_id, kind, payload, meta)
    end)

    :ok
  end
end
