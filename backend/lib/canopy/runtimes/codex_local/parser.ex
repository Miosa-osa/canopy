defmodule Canopy.Runtimes.CodexLocal.Parser do
  @moduledoc """
  Pure functions that translate Codex's `--json` (JSONL) stream lines
  into `Canopy.Runtimes.TranscriptEntry` structs.

  Provenance: derived from Paperclip's `parse.ts`
  (packages/adapters/codex-local/src/server/parse.ts).
  The TypeScript original accumulated state in a mutable loop; this
  implementation is fully stateless — callers pass one raw JSON binary and
  receive zero or more entries.

  ## Codex event → TranscriptEntry mapping

  | Codex event                          | TranscriptEntry kind    |
  |--------------------------------------|-------------------------|
  | `thread.started`                     | `:init`                 |
  | `item.completed` + `agent_message`   | `:assistant`            |
  | `item.completed` + `function_call`   | `:tool_call`            |
  | `item.completed` + `function_call_output` | `:tool_result`    |
  | `item.completed` + `reasoning`       | `:thinking`             |
  | `turn.completed`                     | `:result`               |
  | `turn.failed`                        | `:system` (error)       |
  | `error`                              | `:system` (error)       |
  | anything else                        | `[]`                    |

  Malformed JSON lines are logged at `:warning` level and skipped — the
  pipeline never crashes on bad data.

  Event dispatch lives in `Canopy.Runtimes.CodexLocal.Parser.Dispatch`.
  Low-level type extractors live in `Canopy.Runtimes.CodexLocal.Parser.Helpers`.
  """

  alias Canopy.Runtimes.CodexLocal.Parser.Dispatch
  alias Canopy.Runtimes.TranscriptEntry

  require Logger

  @doc """
  Parses a single raw JSON line from Codex's `--json` JSONL output.

  Returns a list of `TranscriptEntry` structs — usually one, but may be
  empty for unknown event types or blank lines.
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
            "[CodexLocal.Parser] malformed JSON line: #{inspect(reason)} — raw: #{String.slice(line, 0, 200)}"
          )

          []
      end
    end
  end

  @doc """
  Parses a complete stdout blob (newline-delimited JSONL).

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
  Extracts the final `thread_id` / session ID from a completed stream blob.

  Scans all `thread.started` events and returns the last thread_id seen.
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
          {:ok, %{"type" => "thread.started", "thread_id" => id}}
          when is_binary(id) and id != "" ->
            id

          _other ->
            acc
        end
      end
    end)
  end

  @doc """
  Extracts usage metrics from the final `turn.completed` event in a stream blob.

  Returns a map with `:input_tokens`, `:output_tokens`, `:cache_read_tokens`,
  and `:cost_usd`.
  Returns `nil` when no `turn.completed` event is present.
  """
  @spec extract_result_metrics(binary()) :: map() | nil
  def extract_result_metrics(stdout) when is_binary(stdout) do
    Enum.find_value(parse_stream(stdout), fn
      %TranscriptEntry{kind: :result, content: content} -> content
      _other -> nil
    end)
  end

  @doc """
  Returns `true` when the combined stdout+stderr blob contains a Codex
  "unknown session" error — indicating the prior session ID is stale and the
  caller should retry with a fresh session.

  Pattern derived from Paperclip's `isCodexUnknownSessionError`.
  """
  @spec unknown_session_error?(String.t(), String.t()) :: boolean()
  def unknown_session_error?(stdout, stderr) do
    haystack =
      (stdout <> "\n" <> stderr)
      |> String.split(~r/\r?\n/)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n")

    Regex.match?(
      ~r/unknown (session|thread)|session .* not found|thread .* not found|conversation .* not found|missing rollout path for thread|state db missing rollout path|no rollout found for thread id/i,
      haystack
    )
  end
end
