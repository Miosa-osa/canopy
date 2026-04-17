defmodule Canopy.Runtimes.CodexLocal.Parser.Dispatch do
  @moduledoc """
  Event-type dispatch for the Codex stream-json parser.

  Routes each decoded JSON event map to the appropriate
  `Canopy.Runtimes.TranscriptEntry` construction path.

  Codex (`codex exec --json`) emits a JSONL stream with these event types:

  | type              | item.type            | Output entry kind |
  |-------------------|----------------------|-------------------|
  | thread.started    | —                    | `:init`           |
  | item.completed    | agent_message        | `:assistant`      |
  | item.completed    | function_call        | `:tool_call`      |
  | item.completed    | function_call_output | `:tool_result`    |
  | item.completed    | reasoning            | `:thinking`       |
  | item.completed    | *(other)*            | `[]`              |
  | turn.completed    | —                    | `:result`         |
  | turn.failed       | —                    | `:system` (error) |
  | error             | —                    | `:system` (error) |
  | *(other)*         | —                    | `[]`              |

  Provenance: derived from Paperclip's `parse.ts` and `parse.test.ts`
  (packages/adapters/codex-local/src/server/). Not part of the public Canopy API.
  """

  alias Canopy.Runtimes.CodexLocal.Parser.Helpers
  alias Canopy.Runtimes.TranscriptEntry

  @doc """
  Dispatches a decoded Codex stream-json event map to zero or more
  `TranscriptEntry` structs.
  """
  @spec run(map()) :: [TranscriptEntry.t()]
  def run(%{"type" => "thread.started"} = event) do
    thread_id = Helpers.get_string(event, "thread_id")

    entry =
      TranscriptEntry.new(:init, %{
        session_id: thread_id,
        model: nil
      })

    [entry]
  end

  def run(%{"type" => "item.completed"} = event) do
    item = Helpers.get_map(event, "item")
    parse_item(item)
  end

  def run(%{"type" => "turn.completed"} = event) do
    usage = Helpers.get_map(event, "usage")

    entry =
      TranscriptEntry.new(:result, %{
        subtype: "success",
        is_error: false,
        input_tokens: Helpers.get_int(usage, "input_tokens"),
        output_tokens: Helpers.get_int(usage, "output_tokens"),
        cache_read_tokens: Helpers.get_int(usage, "cached_input_tokens"),
        cache_write_tokens: 0,
        cost_usd: 0.0,
        errors: []
      })

    [entry]
  end

  def run(%{"type" => "turn.failed"} = event) do
    err = Helpers.get_map(event, "error")

    message =
      Helpers.get_string(err, "message") ||
        Helpers.get_string(event, "message") ||
        "turn failed"

    entry = TranscriptEntry.new(:system, %{event: "error", message: message})
    [entry]
  end

  def run(%{"type" => "error"} = event) do
    message =
      Helpers.get_string(event, "message") ||
        Helpers.get_string(event, "error") ||
        "unknown error"

    entry = TranscriptEntry.new(:system, %{event: "error", message: message})
    [entry]
  end

  # Catch-all — unknown or future event types produce no entries.
  def run(_event), do: []

  # ---------------------------------------------------------------------------
  # Private — item type dispatch
  # ---------------------------------------------------------------------------

  @spec parse_item(map()) :: [TranscriptEntry.t()]
  defp parse_item(%{"type" => "agent_message"} = item) do
    text = Helpers.get_string(item, "text") || ""

    if text == "" do
      []
    else
      [TranscriptEntry.new(:assistant, %{text: text})]
    end
  end

  defp parse_item(%{"type" => "reasoning"} = item) do
    text = Helpers.get_string(item, "text") || Helpers.get_string(item, "thinking") || ""

    if text == "" do
      []
    else
      [TranscriptEntry.new(:thinking, %{text: text})]
    end
  end

  defp parse_item(%{"type" => "function_call"} = item) do
    call_id = Helpers.get_string(item, "call_id") || Helpers.get_string(item, "id")
    name = Helpers.get_string(item, "name") || ""
    input = decode_arguments(item["arguments"] || item["input"])

    entry =
      TranscriptEntry.new(
        :tool_call,
        %{name: name, input: input},
        tool_call_id: call_id
      )

    [entry]
  end

  defp parse_item(%{"type" => "function_call_output"} = item) do
    call_id = Helpers.get_string(item, "call_id") || Helpers.get_string(item, "id")
    output = Helpers.parse_output_content(item["output"])
    is_error = Helpers.get_bool(item, "is_error")

    entry =
      TranscriptEntry.new(
        :tool_result,
        %{
          tool_name: Helpers.get_string(item, "name"),
          content: output,
          is_error: is_error
        },
        tool_call_id: call_id
      )

    [entry]
  end

  defp parse_item(_other), do: []

  # Decodes a function_call arguments value to a plain map.
  # Codex emits arguments as a JSON-encoded string; fall back gracefully for maps.
  @spec decode_arguments(term()) :: map()
  defp decode_arguments(s) when is_binary(s) do
    case Jason.decode(s) do
      {:ok, decoded} when is_map(decoded) -> decoded
      _other -> %{"raw" => s}
    end
  end

  defp decode_arguments(m) when is_map(m), do: m
  defp decode_arguments(_other), do: %{}
end
