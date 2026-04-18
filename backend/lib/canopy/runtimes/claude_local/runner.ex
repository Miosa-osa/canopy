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

  Common GenServer logic lives in `Canopy.Runtimes.ProcessRunner`.
  """

  use Canopy.Runtimes.ProcessRunner

  alias Canopy.Runtimes.ClaudeLocal.Parser

  @impl Canopy.Runtimes.ProcessRunner
  def parse_line(raw), do: Parser.parse_line(raw)
end
