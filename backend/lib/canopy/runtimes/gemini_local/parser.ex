defmodule Canopy.Runtimes.GeminiLocal.Parser do
  @moduledoc """
  Pure functions that translate Gemini CLI's `--output-format stream-json`
  JSONL lines into `Canopy.Runtimes.TranscriptEntry` structs.

  Provenance: derived from Paperclip's `parse.ts`
  (packages/adapters/gemini-local/src/server/parse.ts).
  The TypeScript original accumulated state in a mutable loop; this
  implementation is fully stateless — callers pass one raw JSON binary and
  receive zero or more entries.

  ## Key differences from the Claude parser

  - Gemini uses `--prompt` for prompt delivery (not stdin), so there is no
    `:init` entry type — the first event is typically an `assistant` message.
  - Session IDs appear on almost every event (Gemini emits `session_id` or
    one of its aliases on each line).
  - Thinking blocks appear as `{"type":"thinking","thinking":"..."}` within
    `assistant` message content — same shape as Claude but different wrapping.
  - Tool calls use `function_call` type (not `tool_use`).
  - Usage appears in both `result` events and `step_finish` events.

  ## Event type → TranscriptEntry mapping

  | Gemini type   | condition               | kind           |
  |---------------|-------------------------|----------------|
  | `assistant`   | text content            | `:assistant`   |
  | `assistant`   | thinking content        | `:thinking`    |
  | `assistant`   | function_call content   | `:tool_call`   |
  | `tool_result` | —                       | `:tool_result` |
  | `result`      | any subtype             | `:result`      |
  | `error`       | —                       | `:system`      |
  | `system`      | subtype: error          | `:system`      |
  | `text`        | part.text               | `:assistant`   |
  | `step_finish` | —                       | (none)         |
  | *(other)*     | —                       | (none)         |

  Malformed JSON lines are logged at `:warning` level and skipped — the
  pipeline never crashes on bad data.

  Event dispatch lives in `Canopy.Runtimes.GeminiLocal.Parser.Dispatch`.
  Low-level extractors live in `Canopy.Runtimes.GeminiLocal.Parser.Helpers`.
  """

  alias Canopy.Runtimes.GeminiLocal.Parser.{Dispatch, Helpers}
  alias Canopy.Runtimes.TranscriptEntry

  require Logger

  @doc """
  Parses a single raw JSON line from Gemini's `--output-format stream-json` output.

  Returns a list of `TranscriptEntry` structs — usually one, but an `assistant`
  message with multiple content blocks can yield several. Returns `[]` for blank
  lines, unknown types, or parse failures.
  """
  @spec parse_line(binary()) :: [TranscriptEntry.t()]
  def parse_line(raw) when is_binary(raw) do
    line = String.trim(raw)

    if line == "" do
      []
    else
      case Jason.decode(line) do
        {:ok, event} ->
          Dispatch.run(event)

        {:error, reason} ->
          Logger.warning(
            "[GeminiLocal.Parser] malformed JSON line: #{inspect(reason)} — raw: #{String.slice(line, 0, 200)}"
          )

          []
      end
    end
  end

  @doc """
  Parses a complete stdout blob (newline-delimited stream-json).

  Returns all entries in emission order. Useful in tests and for processing
  buffered output after process exit.
  """
  @spec parse_stream(binary()) :: [TranscriptEntry.t()]
  def parse_stream(stdout) when is_binary(stdout) do
    stdout
    |> String.split(~r/\r?\n/)
    |> Enum.flat_map(&parse_line/1)
  end

  @doc """
  Extracts the final session ID from a completed stream blob.

  Scans all lines and returns the last session ID value seen. Gemini emits a
  session ID on nearly every line; the last one is the canonical checkpoint.
  Returns `nil` when no session ID was emitted.
  """
  @spec extract_session_id(binary()) :: String.t() | nil
  def extract_session_id(stdout) when is_binary(stdout) do
    stdout
    |> String.split(~r/\r?\n/)
    |> Enum.reduce(nil, &extract_session_id_from_line/2)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec extract_session_id_from_line(binary(), String.t() | nil) :: String.t() | nil
  defp extract_session_id_from_line(line, acc) do
    trimmed = String.trim(line)
    if trimmed == "", do: acc, else: try_read_session_id(trimmed, acc)
  end

  @spec try_read_session_id(binary(), String.t() | nil) :: String.t() | nil
  defp try_read_session_id(trimmed, acc) do
    case Jason.decode(trimmed) do
      {:ok, event} ->
        case Helpers.read_session_id(event) do
          id when is_binary(id) and id != "" -> id
          _other -> acc
        end

      _error ->
        acc
    end
  end

  @doc """
  Extracts cost + usage from the `result` event in a stream blob.

  Returns a map with `:cost_usd`, `:input_tokens`, `:cached_input_tokens`, and
  `:output_tokens`. Returns `nil` when no `result` event is present.
  """
  @spec extract_result_metrics(binary()) :: map() | nil
  def extract_result_metrics(stdout) when is_binary(stdout) do
    Enum.find_value(parse_stream(stdout), fn
      %TranscriptEntry{kind: :result, content: content} -> content
      _other -> nil
    end)
  end
end
