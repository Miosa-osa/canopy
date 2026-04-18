defmodule Canopy.Runtimes.GeminiLocal.Runner do
  @moduledoc """
  GenServer that owns the Gemini CLI subprocess Port for one session.

  Each running session spawns exactly one Runner as a transient child of
  `Canopy.Sessions.Supervisor`. The Runner:

  1. Receives opts (including `:port_cmd`, `:cwd`, `:env`) via `start_link/1`
     and spawns the Port on `init/1`.
  2. Reads Port data line-by-line, JSON-decodes via `GeminiLocal.Parser`,
     and emits `TranscriptEntry` structs on two channels:
       a. Phoenix.PubSub topic `"session:<id>"` (for SSE / LiveView consumers)
       b. `Canopy.Sessions.append_message/2` (for database persistence)
  3. On exit-code 0: emits a synthetic `:system` entry with `event: "completed"`
     and the captured `gemini_session_id` for resume support.
  4. On non-zero exit: emits `:system` with `event: "error"`.
  5. On caller cancel: closes the Port and emits `:system` with `event: "cancelled"`.

  ## No stdin prompt

  The Gemini CLI receives the prompt as a `--prompt` CLI argument (built by
  `GeminiLocal.Args.build/1`). Unlike Claude/Codex, no stdin write is performed.

  ## Session ID tracking

  Each output line is inspected for a Gemini session ID (via
  `GeminiLocal.Parser.Helpers.read_session_id/1`). The last seen value is
  attached to the `completed` system entry so callers can resume the session.

  Common GenServer logic lives in `Canopy.Runtimes.ProcessRunner`.
  """

  use Canopy.Runtimes.ProcessRunner

  alias Canopy.Runtimes.GeminiLocal.Parser
  alias Canopy.Runtimes.GeminiLocal.Parser.Helpers, as: ParseHelpers
  alias Canopy.Runtimes.ProcessRunner.State

  @impl Canopy.Runtimes.ProcessRunner
  def parse_line(raw), do: Parser.parse_line(raw)

  @impl Canopy.Runtimes.ProcessRunner
  def use_stdin?, do: false

  @impl Canopy.Runtimes.ProcessRunner
  def on_line(line, extra) do
    trimmed = String.trim(line)

    case Jason.decode(trimmed) do
      {:ok, event} ->
        case ParseHelpers.read_session_id(event) do
          id when is_binary(id) and id != "" -> Map.put(extra, :gemini_session_id, id)
          _other -> extra
        end

      _error ->
        extra
    end
  end

  @impl Canopy.Runtimes.ProcessRunner
  def completed_extra(%State{extra: extra}) do
    %{gemini_session_id: Map.get(extra, :gemini_session_id)}
  end
end
