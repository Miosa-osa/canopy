defmodule Canopy.Sessions.ScrollbackStore do
  @moduledoc """
  GenServer that persists all pty output for one session to disk.

  One store per session, registered via `ScrollbackRegistry`. On start it
  opens `~/.canopy/scrollback/<session_id>.log` in append+binary mode,
  attaches to the PtyBridge as a subscriber, and accumulates bytes.

  ## File lifecycle
  - Created on start, kept after pty exit (log is valuable post-exit).
  - Rotated when the file exceeds 10 MB: tail 5 MB is kept, head is dropped.
  - File is never deleted by this process; explicit cleanup is the caller's job.

  ## Public API
    - `start_link/1`  — started by `ScrollbackSupervisor`
    - `read/2`        — returns `{:ok, data, offset}` for a given byte range
  """

  use GenServer, restart: :temporary

  require Logger

  alias Canopy.Runs.Events, as: RunEvents

  @max_bytes 10_485_760
  @keep_bytes 5_242_880

  # ---------------------------------------------------------------------------
  # Child spec
  # ---------------------------------------------------------------------------

  def child_spec(session_id) do
    %{
      id: {__MODULE__, session_id},
      start: {__MODULE__, :start_link, [session_id]},
      restart: :temporary
    }
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Starts a ScrollbackStore for `session_id`."
  @spec start_link(binary()) :: GenServer.on_start()
  def start_link(session_id) do
    GenServer.start_link(__MODULE__, session_id, name: via(session_id))
  end

  @doc """
  Reads scrollback bytes for `session_id`.

  Options:
  - `last_n_lines: N` — return approximately last N newline-delimited chunks
    (scan from tail; may be slightly over N on chunk boundaries).
  - `from: offset` — return bytes starting at `offset` bytes from file start.

  Returns `{:ok, data_binary, next_offset}` where `next_offset` is the
  current file end position (suitable for the next poll's `from:` value).
  Returns `{:error, :not_found}` if no store is running for this session.
  """
  @spec read(binary(), keyword()) ::
          {:ok, binary(), non_neg_integer()} | {:error, :not_found | term()}
  def read(session_id, opts \\ []) do
    case Registry.lookup(Canopy.Sessions.ScrollbackRegistry, session_id) do
      [{pid, _}] -> GenServer.call(pid, {:read, opts})
      [] -> {:error, :not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(session_id) do
    dir = scrollback_dir()

    with :ok <- File.mkdir_p(dir) do
      path = log_path(dir, session_id)

      case :file.open(String.to_charlist(path), [:append, :binary, :sync]) do
        {:ok, fd} ->
          # Attach to PtyBridge — if bridge isn't up yet, retry after a moment.
          attach_with_retry(session_id)

          state = %{
            session_id: session_id,
            path: path,
            fd: fd,
            byte_count: current_size(path),
            log_seq: 0
          }

          {:ok, state}

        {:error, reason} ->
          Logger.error(
            "[ScrollbackStore] failed to open log session_id=#{session_id} reason=#{inspect(reason)}"
          )

          {:stop, {:file_open_failed, reason}}
      end
    else
      {:error, reason} ->
        Logger.error(
          "[ScrollbackStore] failed to create scrollback dir reason=#{inspect(reason)}"
        )

        {:stop, {:mkdir_failed, reason}}
    end
  end

  @impl true
  def handle_info({:pty_output, data}, state) do
    :file.write(state.fd, data)
    new_count = state.byte_count + byte_size(data)
    seq = state.log_seq + 1

    new_state =
      if new_count > @max_bytes do
        rotate(%{state | log_seq: seq})
      else
        %{state | byte_count: new_count, log_seq: seq}
      end

    maybe_broadcast_log(state.session_id, seq, data)

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:pty_exit, code}, state) do
    Logger.info(
      "[ScrollbackStore] pty exited session_id=#{state.session_id} code=#{code} — keeping log"
    )

    # Flush is implicit — :sync flag on open ensures writes are durable.
    {:noreply, state}
  end

  # PtyBridge monitor — if the bridge crashes before we attach, we just keep
  # the file and stop accumulating (no crash required).
  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    Logger.debug(
      "[ScrollbackStore] PtyBridge down session_id=#{state.session_id} reason=#{inspect(reason)}"
    )

    {:noreply, state}
  end

  # Retry attach if the bridge wasn't up at init time.
  @impl true
  def handle_info(:attach_retry, state) do
    attach_with_retry(state.session_id)
    {:noreply, state}
  end

  @impl true
  def handle_call({:read, opts}, _from, state) do
    reply = do_read(state.path, opts)
    {:reply, reply, state}
  end

  @impl true
  def terminate(_reason, state) do
    :file.close(state.fd)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp via(session_id),
    do: {:via, Registry, {Canopy.Sessions.ScrollbackRegistry, session_id}}

  defp scrollback_dir do
    Path.join(System.user_home!(), ".canopy/scrollback")
  end

  defp log_path(dir, session_id), do: Path.join(dir, "#{session_id}.log")

  defp current_size(path) do
    case File.stat(path) do
      {:ok, %{size: s}} -> s
      _ -> 0
    end
  end

  # Rotate: keep last @keep_bytes of the file.
  defp rotate(%{path: path, fd: fd} = state) do
    :file.close(fd)

    case File.read(path) do
      {:ok, contents} ->
        tail = :binary.part(contents, byte_size(contents) - @keep_bytes, @keep_bytes)
        File.write!(path, tail)

      _ ->
        :ok
    end

    case :file.open(String.to_charlist(path), [:append, :binary, :sync]) do
      {:ok, new_fd} ->
        Logger.info("[ScrollbackStore] rotated log path=#{path}")
        %{state | fd: new_fd, byte_count: @keep_bytes}

      {:error, reason} ->
        Logger.error("[ScrollbackStore] rotate reopen failed reason=#{inspect(reason)}")
        state
    end
  end

  defp attach_with_retry(session_id) do
    case Registry.lookup(Canopy.Sessions.PtyRegistry, session_id) do
      [{_pid, _}] ->
        :ok = Canopy.Sessions.PtyBridge.attach(session_id, self())

      [] ->
        Process.send_after(self(), :attach_retry, 500)
    end
  end

  # Emit a run_log event if the session has an active run with a latest_run_id.
  # Best-effort — any error (non-UUID id, DB miss, sandbox restriction in tests)
  # silently returns :ok so the write path is never affected.
  defp maybe_broadcast_log(session_id, seq, data) do
    try do
      with {:ok, _} <- Ecto.UUID.cast(session_id),
           {:ok, session} <- Canopy.Sessions.get(session_id),
           run_id when is_binary(run_id) <- session.latest_run_id,
           {:ok, run} <- Canopy.Runs.get(run_id) do
        RunEvents.run_log(%{
          run_id: run.id,
          short_id: run.short_id,
          workspace_slug: run.workspace_slug || "default",
          seq: seq,
          kind: "stdout",
          data: data,
          at: DateTime.to_iso8601(DateTime.utc_now())
        })
      else
        _ -> :ok
      end
    rescue
      _ -> :ok
    end
  end

  defp do_read(path, opts) do
    case File.stat(path) do
      {:error, reason} ->
        {:error, reason}

      {:ok, %{size: total}} ->
        data =
          cond do
            Keyword.has_key?(opts, :from) ->
              offset = Keyword.fetch!(opts, :from)
              read_from(path, offset, total)

            Keyword.has_key?(opts, :last_n_lines) ->
              n = Keyword.fetch!(opts, :last_n_lines)
              read_last_lines(path, n, total)

            true ->
              read_from(path, 0, total)
          end

        {:ok, data, total}
    end
  end

  defp read_from(_path, offset, total) when offset >= total, do: <<>>

  defp read_from(path, offset, total) do
    length = total - offset

    case :file.open(String.to_charlist(path), [:read, :binary, :raw]) do
      {:ok, fd} ->
        :file.position(fd, offset)
        {:ok, data} = :file.read(fd, length)
        :file.close(fd)
        data

      {:error, _} ->
        <<>>
    end
  end

  defp read_last_lines(path, n, total) do
    # Scan backward reading 64 KB chunks until we have enough newlines.
    chunk = 65_536
    start = max(0, total - chunk * 4)
    data = read_from(path, start, total)

    lines = :binary.split(data, "\n", [:global])
    tail = Enum.take(lines, -n)
    Enum.join(tail, "\n")
  end
end
