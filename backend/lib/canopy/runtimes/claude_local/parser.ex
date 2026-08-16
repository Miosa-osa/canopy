defmodule Canopy.Runtimes.ClaudeLocal.Parser do
  @moduledoc """
  Pure functions that translate Claude's `--output-format stream-json` lines
  into `Canopy.Runtimes.TranscriptEntry` structs.

  Implementation is fully stateless — callers pass one raw JSON binary and
  receive zero or more entries.

  | Claude type            | TranscriptEntry kind          |
  |------------------------|-------------------------------|
  | `system` + init        | `:init`                       |
  | `assistant` + text     | `:assistant`                  |
  | `assistant` + thinking | `:thinking`                   |
  | `assistant` + tool_use | `:tool_call`                  |
  | `tool_result`          | `:tool_result`                |
  | `result`               | `:result`                     |
  | `error`                | `:system` (error payload)     |
  | anything else          | `[]`                          |

  Malformed JSON lines are logged at `:warning` level and skipped — the
  pipeline never crashes on bad data.

  Event dispatch lives in `Canopy.Runtimes.ClaudeLocal.Parser.Dispatch`.
  Low-level type extractors live in `Canopy.Runtimes.ClaudeLocal.Parser.Helpers`.
  """

  alias Canopy.Runtimes.ClaudeLocal.Parser.Dispatch
  alias Canopy.Runtimes.TranscriptEntry

  require Logger

  @doc """
  Parses a single raw JSON line from Claude's stream-json output.

  Returns a list of `TranscriptEntry` structs — usually one, but an
  `assistant` message with multiple content blocks can yield several.
  Returns `[]` for blank lines, unknown types, or parse failures.
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
            "[ClaudeLocal.Parser] malformed JSON line: #{inspect(reason)} — raw: #{String.slice(line, 0, 200)}"
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
  Extracts the final `session_id` from a completed stream blob.

  Scans all lines and returns the last value seen in `session_id` fields.
  Returns `nil` when no session ID was emitted.
  """
  @spec extract_session_id(binary()) :: String.t() | nil
  def extract_session_id(stdout) when is_binary(stdout) do
    stdout
    |> String.split(~r/\r?\n/)
    |> Enum.reduce(nil, fn line, acc ->
      trimmed = String.trim(line)

      if trimmed == "" do
        acc
      else
        case Jason.decode(trimmed) do
          {:ok, %{"session_id" => id}} when is_binary(id) and id != "" -> id
          _other -> acc
        end
      end
    end)
  end

  @doc """
  Extracts cost + usage from the final `result` event in a stream blob.

  Returns a map with `:cost_usd`, `:input_tokens`, `:output_tokens`,
  `:cache_read_tokens`, and `:cache_write_tokens`.
  Returns `nil` when no `result` event is present.
  """
  @spec extract_result_metrics(binary()) :: map() | nil
  def extract_result_metrics(stdout) when is_binary(stdout) do
    Enum.find_value(parse_stream(stdout), fn
      %TranscriptEntry{kind: :result, content: content} -> content
      _other -> nil
    end)
  end
end
