defmodule Canopy.Runtimes.GeminiLocal.Parser.Dispatch do
  @moduledoc """
  Event-type dispatch for the Gemini stream-json (JSONL) parser.

  Routes each decoded JSON event map to the appropriate
  `Canopy.Runtimes.TranscriptEntry` construction path. One module per event
  type keeps each clause self-contained and under 25 lines.

  ## Gemini event types handled

  | type          | subtype / condition     | Output entry kind          |
  |---------------|-------------------------|----------------------------|
  | `assistant`   | text content            | `:assistant`               |
  | `assistant`   | thinking content        | `:thinking`                |
  | `assistant`   | function_call content   | `:tool_call`               |
  | `tool_result` | —                       | `:tool_result`             |
  | `result`      | success                 | `:result`                  |
  | `result`      | error / is_error: true  | `:result` (is_error: true) |
  | `error`       | —                       | `:system` (error payload)  |
  | `system`      | subtype: error          | `:system` (error payload)  |
  | `text`        | part.text               | `:assistant`               |
  | `step_finish` | —                       | ignored (no entry)         |
  | *(other)*     | —                       | `[]`                       |

  Gemini also emits `step_finish` events that carry usage accumulators but no
  transcript content. These are silently ignored — usage is extracted from the
  `result` event by the Parser.

  Not part of the public Canopy API.
  """

  alias Canopy.Runtimes.GeminiLocal.Parser.Helpers
  alias Canopy.Runtimes.TranscriptEntry

  @doc """
  Dispatches a decoded Gemini JSONL event map to zero or more
  `TranscriptEntry` structs.
  """
  @spec run(map()) :: [TranscriptEntry.t()]
  def run(%{"type" => "assistant"} = event) do
    message = Helpers.get_map(event, "message")
    content_blocks = Helpers.get_list(message, "content")

    if Enum.empty?(content_blocks) do
      # Flat message — collect text directly from `message`
      Helpers.collect_message_text(message)
      |> Enum.map(fn text -> TranscriptEntry.new(:assistant, %{text: text}) end)
    else
      Enum.flat_map(content_blocks, &parse_content_block/1)
    end
  end

  def run(%{"type" => "tool_result"} = event) do
    content_raw = event["content"] || event["result"] || ""

    entry =
      TranscriptEntry.new(
        :tool_result,
        %{
          tool_name: Helpers.get_string(event, "tool_name") || Helpers.get_string(event, "name"),
          content: to_string(content_raw),
          is_error: Helpers.get_bool(event, "is_error")
        },
        tool_call_id:
          Helpers.get_string(event, "tool_use_id") || Helpers.get_string(event, "call_id") ||
            Helpers.get_string(event, "id")
      )

    [entry]
  end

  def run(%{"type" => "result"} = event) do
    subtype = Helpers.get_string(event, "subtype") || ""
    is_error = event["is_error"] == true or String.downcase(subtype) == "error"

    usage_acc = %{input_tokens: 0, cached_input_tokens: 0, output_tokens: 0}
    usage = Helpers.accumulate_usage(usage_acc, event["usage"] || event["usageMetadata"] || %{})
    cost = Helpers.extract_cost(event)

    result_text =
      Helpers.get_string(event, "result") ||
        Helpers.get_string(event, "text") ||
        Helpers.get_string(event, "response") || ""

    entry =
      TranscriptEntry.new(:result, %{
        text: result_text,
        subtype: subtype,
        is_error: is_error,
        input_tokens: usage.input_tokens,
        cached_input_tokens: usage.cached_input_tokens,
        output_tokens: usage.output_tokens,
        cost_usd: cost || 0.0
      })

    [entry]
  end

  def run(%{"type" => "error"} = event) do
    message =
      Helpers.extract_error_text(
        event["error"] || event["message"] || event["detail"] || "unknown error"
      )

    entry = TranscriptEntry.new(:system, %{event: "error", message: message})
    [entry]
  end

  def run(%{"type" => "system"} = event) do
    subtype = Helpers.get_string(event, "subtype") || ""

    if String.downcase(subtype) == "error" do
      message =
        Helpers.extract_error_text(
          event["error"] || event["message"] || event["detail"] || "unknown error"
        )

      entry = TranscriptEntry.new(:system, %{event: "error", message: message})
      [entry]
    else
      []
    end
  end

  def run(%{"type" => "text"} = event) do
    # Gemini CLI occasionally emits a flat `{"type":"text","part":{"text":"..."}}` event.
    part = Helpers.get_map(event, "part")
    text = Helpers.get_string(part, "text") || ""
    trimmed = String.trim(text)

    if trimmed == "" do
      []
    else
      [TranscriptEntry.new(:assistant, %{text: trimmed})]
    end
  end

  # step_finish carries usage accumulators only — no transcript content.
  def run(%{"type" => "step_finish"}), do: []

  # Catch-all — unknown or future event types produce no entries.
  def run(_event), do: []

  # ---------------------------------------------------------------------------
  # Private — content block parsing
  # ---------------------------------------------------------------------------

  @spec parse_content_block(map()) :: [TranscriptEntry.t()]
  defp parse_content_block(%{"type" => type, "text" => text})
       when type in ["text", "output_text"] and is_binary(text) do
    trimmed = String.trim(text)
    if trimmed == "", do: [], else: [TranscriptEntry.new(:assistant, %{text: trimmed})]
  end

  defp parse_content_block(%{"type" => "thinking", "thinking" => text})
       when is_binary(text) do
    trimmed = String.trim(text)
    if trimmed == "", do: [], else: [TranscriptEntry.new(:thinking, %{text: trimmed})]
  end

  defp parse_content_block(%{"type" => "function_call"} = block) do
    args = block["args"] || block["input"] || %{}

    entry =
      TranscriptEntry.new(
        :tool_call,
        %{
          name: Helpers.get_string(block, "name"),
          input: args
        },
        tool_call_id:
          Helpers.get_string(block, "id") ||
            Helpers.get_string(block, "call_id")
      )

    [entry]
  end

  defp parse_content_block(_other), do: []
end
