defmodule Canopy.Runtimes.ProcessRunner do
  @moduledoc """
  Shared GenServer behaviour for all subprocess-based runtime adapters.

  Provides the full Port lifecycle: spawn, line-buffer, parse, broadcast,
  persist, cancel, and exit. Adapters `use` this module and implement callbacks.

  **Required callback**
  - `c:parse_line/1` — translate one raw stdout line into zero or more `TranscriptEntry` structs.

  **Optional callbacks (defaults provided)**
  - `c:use_stdin?/0` — write `:prompt` to stdin after spawn. Default `true`.
    Gemini returns `false` (prompt is a CLI arg).
  - `c:on_line/2` — `(line, extra) -> extra`. Called per line before entry emission.
    Gemini uses it to track the session ID returned by the CLI.
  - `c:on_exit_error/2` — `(code, pre_flush_state) -> event_string`. Default `"error"`.
    Codex overrides to detect `"session_expired"` from the partial line_buffer.
  - `c:completed_extra/1` — extra fields merged into the `completed` system entry.
    Gemini returns `%{gemini_session_id: ...}`.

  **State**: common fields in `ProcessRunner.State`; adapter-specific data in `:extra`.
  """

  alias Canopy.Analytics.Emitter
  alias Canopy.Runtimes.TranscriptEntry

  require Logger

  @pubsub Canopy.PubSub

  defmodule State do
    @moduledoc false
    @enforce_keys [:session_id, :module]
    defstruct [
      :session_id,
      :port,
      :module,
      line_buffer: "",
      sequence: 0,
      context: %{},
      cancelled: false,
      extra: %{}
    ]

    @type t :: %__MODULE__{
            session_id: String.t(),
            port: port() | nil,
            module: module(),
            line_buffer: String.t(),
            sequence: non_neg_integer(),
            context: map(),
            cancelled: boolean(),
            extra: map()
          }
  end

  @callback parse_line(raw :: String.t()) :: [TranscriptEntry.t()]
  @callback use_stdin?() :: boolean()
  @callback on_line(line :: String.t(), extra :: map()) :: map()
  @callback on_exit_error(exit_code :: non_neg_integer(), state :: State.t()) :: String.t()
  @callback completed_extra(state :: State.t()) :: map()

  @optional_callbacks [use_stdin?: 0, on_line: 2, on_exit_error: 2, completed_extra: 1]

  defmacro __using__(_opts) do
    quote do
      use GenServer

      @behaviour Canopy.Runtimes.ProcessRunner

      require Logger

      alias Canopy.Runtimes.ProcessRunner
      alias Canopy.Runtimes.ProcessRunner.State

      @impl ProcessRunner
      def use_stdin?, do: true
      @impl ProcessRunner
      def on_line(_line, extra), do: extra
      @impl ProcessRunner
      def on_exit_error(_code, _state), do: "error"
      @impl ProcessRunner
      def completed_extra(_state), do: %{}

      defoverridable use_stdin?: 0, on_line: 2, on_exit_error: 2, completed_extra: 1

      def child_spec(opts) do
        %{
          id: {__MODULE__, Keyword.fetch!(opts, :session_id)},
          start: {__MODULE__, :start_link, [opts]},
          restart: :transient,
          type: :worker
        }
      end

      @spec start_link(keyword()) :: GenServer.on_start()
      def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

      @doc "Sends a cancel request to the runner."
      @spec cancel(pid()) :: :ok
      def cancel(pid), do: GenServer.cast(pid, :cancel)

      @impl GenServer
      def init(opts), do: ProcessRunner.do_init(__MODULE__, opts)

      @impl GenServer
      def handle_cast(:cancel, %State{cancelled: false} = state) do
        ProcessRunner.close_port(state.port)
        ProcessRunner.emit_system_entry(state, "cancelled")
        {:stop, :normal, %{state | cancelled: true}}
      end

      def handle_cast(:cancel, state), do: {:noreply, state}

      @impl GenServer
      def handle_info({port, {:data, data}}, %State{port: port} = state) do
        ProcessRunner.do_data(__MODULE__, data, state)
      end

      def handle_info({port, {:exit_status, 0}}, %State{port: port} = state) do
        new_state = ProcessRunner.flush_buffer(__MODULE__, state)

        ProcessRunner.emit_system_entry(
          new_state,
          "completed",
          __MODULE__.completed_extra(new_state)
        )

        ProcessRunner.emit_finished(new_state)

        {:stop, :normal, new_state}
      end

      def handle_info({port, {:exit_status, code}}, %State{port: port} = state) do
        Logger.warning("[#{__MODULE__}] session=#{state.session_id} exited with code #{code}")
        # on_exit_error receives pre-flush state so adapters can read partial line_buffer
        event = __MODULE__.on_exit_error(code, state)
        new_state = ProcessRunner.flush_buffer(__MODULE__, state)
        ProcessRunner.emit_system_entry(new_state, event, %{exit_code: code})
        ProcessRunner.emit_failed(new_state, {:exit_status, code, event})
        # Persist terminal status so the session is never stuck in :running forever.
        # Using _ = intentionally: we've already emitted a PubSub entry and logged;
        # a DB failure here is non-fatal for the port lifecycle.
        _ = Canopy.Sessions.update_status(state.session_id, "failed")
        {:stop, :normal, new_state}
      end

      def handle_info({_other_port, _msg}, state), do: {:noreply, state}
    end
  end

  @doc false
  @spec do_init(module(), keyword()) :: {:ok, State.t()}
  def do_init(mod, opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    {binary, args} = Keyword.fetch!(opts, :port_cmd)
    cwd = Keyword.fetch!(opts, :cwd)
    env = Keyword.get(opts, :env, [])
    prompt = Keyword.get(opts, :prompt, "")

    Logger.info("[#{mod}] starting session=#{session_id} binary=#{binary}")

    port =
      Port.open(
        {:spawn_executable, binary},
        [:binary, :exit_status, {:args, args}, {:cd, cwd}, {:env, env}]
      )

    if mod.use_stdin?() and prompt != "" do
      Port.command(port, prompt <> "\n")
    end

    context = Keyword.get(opts, :context, %{})

    Emitter.agent_run_started(%{
      session_id: session_id,
      run_id: session_id,
      workspace_slug: Map.get(context, "workspace_slug") || Map.get(context, :workspace_slug),
      runtime: runtime_type_for(mod),
      model: Map.get(context, "model") || Map.get(context, :model),
      payload: %{"adapter" => inspect(mod)}
    })

    {:ok,
     %State{
       session_id: session_id,
       port: port,
       module: mod,
       context: context
     }}
  end

  @doc false
  @spec runtime_type_for(module()) :: String.t() | nil
  def runtime_type_for(mod) do
    if function_exported?(mod, :type, 0) do
      try do
        mod.type()
      rescue
        _ -> nil
      end
    else
      nil
    end
  end

  @doc false
  @spec emit_finished(State.t()) :: :ok
  def emit_finished(state) do
    Emitter.agent_run_finished(
      %{
        session_id: state.session_id,
        run_id: state.session_id,
        workspace_slug:
          Map.get(state.context, "workspace_slug") || Map.get(state.context, :workspace_slug),
        runtime: runtime_type_for(state.module),
        model: Map.get(state.context, "model") || Map.get(state.context, :model)
      },
      %{status: "ok"}
    )

    _ = Canopy.Analytics.Breadcrumbs.flush_run(state.session_id)
    :ok
  rescue
    _ -> :ok
  end

  @doc false
  @spec emit_failed(State.t(), term()) :: :ok
  def emit_failed(state, reason) do
    Emitter.agent_run_failed(
      %{
        session_id: state.session_id,
        run_id: state.session_id,
        workspace_slug:
          Map.get(state.context, "workspace_slug") || Map.get(state.context, :workspace_slug),
        runtime: runtime_type_for(state.module),
        model: Map.get(state.context, "model") || Map.get(state.context, :model)
      },
      %{reason: inspect(reason)}
    )

    _ = Canopy.Analytics.Breadcrumbs.flush_run(state.session_id)
    :ok
  rescue
    _ -> :ok
  end

  @doc false
  @spec do_data(module(), binary(), State.t()) :: {:noreply, State.t()}
  def do_data(mod, data, state) do
    combined = state.line_buffer <> data
    {lines, remaining} = split_lines(combined)

    new_state =
      Enum.reduce(lines, %{state | line_buffer: remaining}, fn line, acc ->
        extra = mod.on_line(line, acc.extra)
        Enum.reduce(mod.parse_line(line), %{acc | extra: extra}, &emit_entry(&2, &1))
      end)

    {:noreply, new_state}
  end

  @doc false
  @spec flush_buffer(module(), State.t()) :: State.t()
  def flush_buffer(_mod, %{line_buffer: ""} = state), do: state

  def flush_buffer(mod, %{line_buffer: partial} = state) do
    extra = mod.on_line(partial, state.extra)

    Enum.reduce(
      mod.parse_line(partial),
      %{state | extra: extra, line_buffer: ""},
      &emit_entry(&2, &1)
    )
  end

  @doc false
  @spec emit_entry(State.t(), TranscriptEntry.t()) :: State.t()
  def emit_entry(state, entry) do
    seq = state.sequence + 1
    stamped = %{entry | sequence: seq}
    topic = "session:#{state.session_id}"
    Phoenix.PubSub.broadcast(@pubsub, topic, {:transcript_entry, stamped})

    message_attrs = %{
      session_id: state.session_id,
      sequence: seq,
      kind: to_string(stamped.kind),
      content: stamped.content,
      tool_call_id: stamped.tool_call_id,
      emitted_at: stamped.emitted_at
    }

    try do
      case Canopy.Sessions.add_message(state.session_id, message_attrs) do
        {:ok, _msg} ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "[#{state.module}] add_message failed session=#{state.session_id}: #{inspect(reason)}"
          )
      end
    rescue
      err ->
        Logger.debug(
          "[#{state.module}] add_message raised session=#{state.session_id}: #{inspect(err)}"
        )
    end

    %{state | sequence: seq}
  end

  @doc false
  @spec emit_system_entry(State.t(), String.t(), map()) :: :ok
  def emit_system_entry(state, event, extra \\ %{}) do
    entry =
      TranscriptEntry.new(:system, Map.merge(%{event: event}, extra),
        sequence: state.sequence + 1
      )

    Phoenix.PubSub.broadcast(@pubsub, "session:#{state.session_id}", {:transcript_entry, entry})
    :ok
  end

  @doc false
  @spec close_port(port()) :: :ok
  def close_port(port) do
    try do
      Port.close(port)
    catch
      :error, _reason -> :ok
    end

    :ok
  end

  @doc false
  @spec split_lines(binary()) :: {[binary()], binary()}
  def split_lines(buffer) do
    parts = String.split(buffer, ~r/\r?\n/)
    {Enum.drop(parts, -1), List.last(parts) || ""}
  end
end
