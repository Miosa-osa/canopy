defmodule Canopy.Runtimes.CodexLocal.Runner do
  @moduledoc """
  GenServer that owns the Codex subprocess Port for one session.

  Each running session spawns exactly one Runner as a transient child of
  `Canopy.Sessions.Supervisor`. The Runner:

  1. Receives opts via `start_link/1`; spawns the Port on `init/1`.
  2. Reads Port data line-by-line, JSON-decodes via `CodexLocal.Parser`,
     and emits `TranscriptEntry` structs on two channels:
       a. Phoenix.PubSub topic `"session:<id>"` (for SSE / LiveView consumers)
       b. `Canopy.Sessions.append_message/2` (for database persistence)
  3. On exit-code 0: emits a synthetic `:system` entry with `event: "completed"`.
  4. On non-zero exit: emits `:system` with `event: "error"`, or
     `event: "session_expired"` when a stale-session pattern is detected.
  5. On caller cancel: closes the Port and emits `:system` with `event: "cancelled"`.

  ## Stale-session detection

  When Codex exits non-zero and the partial stdout buffer contains a stale-session
  error pattern (detected by `Parser.unknown_session_error?/2`), the Runner
  emits `event: "session_expired"` so callers can clear the stored session ID
  and retry with a fresh context.

  Common GenServer logic lives in `Canopy.Runtimes.ProcessRunner`.
  """

  use Canopy.Runtimes.ProcessRunner

  alias Canopy.Runtimes.CodexLocal.Parser
  alias Canopy.Runtimes.ProcessRunner.State

  @impl Canopy.Runtimes.ProcessRunner
  def parse_line(raw), do: Parser.parse_line(raw)

  @impl Canopy.Runtimes.ProcessRunner
  def on_exit_error(code, %State{} = pre_flush_state) when code != 0 do
    # Check partial line_buffer (pre-flush) for stale-session patterns.
    # stderr is not captured by the generic runner; pass "" as the second arg.
    if Parser.unknown_session_error?(pre_flush_state.line_buffer, "") do
      "session_expired"
    else
      "error"
    end
  end
end
