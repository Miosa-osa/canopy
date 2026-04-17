defmodule Canopy.Runtimes.ClaudeLocal.Parser.Dispatch do
  @moduledoc """
  Event-type dispatch for the Claude stream-json parser.

  Routes each decoded JSON event map to the appropriate
  `Canopy.Runtimes.TranscriptEntry` construction path.  One module per event
  type keeps each clause self-contained and under 25 lines.

  Claude event types handled:

  | type       | subtype | Output entry kind |
  |------------|---------|-------------------|
  | system     | init    | `:init`           |
  | assistant  | —       | `:assistant` / `:thinking` / `:tool_call` |
  | tool_result| —       | `:tool_result`    |
  | result     | *       | `:result`         |
  | error      | —       | `:system`         |
  | *(other)*  | —       | `[]`              |

  Not part of the public Canopy API.
  """

  alias Canopy.Runtimes.ClaudeLocal.Parser.Helpers
  alias Canopy.Runtimes.TranscriptEntry

  @doc """
  Dispatches a decoded Claude stream-json event map to zero or more
  `TranscriptEntry` structs.
  """
  @spec run(map()) :: [TranscriptEntry.t()]
  def run(%{"type" => "system", "subtype" => "init"} = event) do
    entry =
      TranscriptEntry.new(:init, %{
        session_id: Helpers.get_string(event, "session_id"),
        model: Helpers.get_string(event, "model")
      })

    [entry]
  end

  def run(%{"type" => "assistant"} = event) do
    message = Helpers.get_map(event, "message")
    content_blocks = Helpers.get_list(message, "content")
    parse_content_blocks(content_blocks)
  end

  def run(%{"type" => "tool_result"} = event) do
    entry =
      TranscriptEntry.new(
        :tool_result,
        %{
          tool_name: Helpers.get_string(event, "tool_name"),
          content: Helpers.parse_tool_result_content(event["content"]),
          is_error: Helpers.get_bool(event, "is_error")
        },
        tool_call_id: Helpers.get_string(event, "tool_use_id")
      )

    [entry]
  end

  def run(%{"type" => "result"} = event) do
    subtype = Helpers.get_string(event, "subtype")
    usage = Helpers.get_map(event, "usage")
    cost_raw = event["total_cost_usd"]

    entry =
      TranscriptEntry.new(:result, %{
        text: Helpers.get_string(event, "result"),
        subtype: subtype,
        is_error: subtype in ~w(error error_max_turns),
        input_tokens: Helpers.get_int(usage, "input_tokens"),
        output_tokens: Helpers.get_int(usage, "output_tokens"),
        cache_read_tokens: Helpers.get_int(usage, "cache_read_input_tokens"),
        cache_write_tokens: Helpers.get_int(usage, "cache_creation_input_tokens"),
        cost_usd: if(is_float(cost_raw) or is_integer(cost_raw), do: cost_raw / 1.0, else: 0.0),
        errors: Helpers.parse_errors(event["errors"])
      })

    [entry]
  end

  def run(%{"type" => "error"} = event) do
    message =
      Helpers.get_string(event, "message") || Helpers.get_string(event, "error") ||
        "unknown error"

    entry = TranscriptEntry.new(:system, %{event: "error", message: message})
    [entry]
  end

  # Catch-all — unknown or future event types produce no entries.
  def run(_event), do: []

  # ---------------------------------------------------------------------------
  # Private — content block parsing
  # ---------------------------------------------------------------------------

  @spec parse_content_blocks([map()]) :: [TranscriptEntry.t()]
  defp parse_content_blocks(blocks) when is_list(blocks),
    do: Enum.flat_map(blocks, &parse_content_block/1)

  defp parse_content_blocks(_other), do: []

  @spec parse_content_block(map()) :: [TranscriptEntry.t()]
  defp parse_content_block(%{"type" => "text", "text" => text})
       when is_binary(text) and text != "" do
    [TranscriptEntry.new(:assistant, %{text: text})]
  end

  defp parse_content_block(%{"type" => "thinking", "thinking" => text})
       when is_binary(text) and text != "" do
    [TranscriptEntry.new(:thinking, %{text: text})]
  end

  defp parse_content_block(%{"type" => "tool_use"} = block) do
    entry =
      TranscriptEntry.new(
        :tool_call,
        %{name: Helpers.get_string(block, "name"), input: block["input"] || %{}},
        tool_call_id: Helpers.get_string(block, "id")
      )

    [entry]
  end

  defp parse_content_block(_other), do: []
end
