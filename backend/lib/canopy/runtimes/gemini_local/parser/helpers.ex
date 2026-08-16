defmodule Canopy.Runtimes.GeminiLocal.Parser.Helpers do
  @moduledoc """
  Internal extractors for Gemini stream-json (JSONL) parsing.

  Thin, well-typed, pure functions used by `Canopy.Runtimes.GeminiLocal.Parser`
  to safely access typed values from raw decoded JSON maps. Each getter returns
  a sensible default rather than raising when the key is absent or the value has
  an unexpected type.

  Also provides `collect_message_text/1` and `read_session_id/1`, which handle
  Gemini's polymorphic field shapes.

  Gemini-specific notes:
  - Session IDs may appear under `session_id`, `sessionId`, `sessionID`,
    `checkpoint_id`, or `thread_id` — Gemini's output is inconsistent across
    CLI versions. `read_session_id/1` checks all variants.
  - Usage appears under `usage` or `usageMetadata`, with token fields named
    either snake_case (`input_tokens`) or camelCase (`inputTokens` /
    `promptTokenCount`). `accumulate_usage/2` normalises both.
  - Tool calls follow the same `function_call` shape as the Gemini API:
    `{"type": "function_call", "name": "...", "args": {...}, "id": "..."}`.

  Not part of the public Canopy API — subject to change without notice.
  """

  @doc """
  Returns the string value at `key` in `map`, or `nil` when absent or not a binary.
  """
  @spec get_string(map(), String.t()) :: String.t() | nil
  def get_string(map, key) when is_map(map) do
    case map[key] do
      v when is_binary(v) -> v
      _other -> nil
    end
  end

  def get_string(_map, _key), do: nil

  @doc """
  Returns the map value at `key` in `map`, or `%{}` when absent or not a map.
  """
  @spec get_map(map(), String.t()) :: map()
  def get_map(map, key) when is_map(map) do
    case map[key] do
      v when is_map(v) -> v
      _other -> %{}
    end
  end

  def get_map(_map, _key), do: %{}

  @doc """
  Returns the list value at `key` in `map`, or `[]` when absent or not a list.
  """
  @spec get_list(map(), String.t()) :: list()
  def get_list(map, key) when is_map(map) do
    case map[key] do
      v when is_list(v) -> v
      _other -> []
    end
  end

  def get_list(_map, _key), do: []

  @doc """
  Returns `true` when the value at `key` in `map` is exactly `true`; otherwise
  returns `false`.
  """
  @spec get_bool(map(), String.t()) :: boolean()
  def get_bool(map, key) when is_map(map) do
    case map[key] do
      true -> true
      _other -> false
    end
  end

  def get_bool(_map, _key), do: false

  @doc """
  Returns the non-negative integer value at `key` in `map`, or `0` when absent,
  not an integer, or negative.
  """
  @spec get_int(map(), String.t()) :: non_neg_integer()
  def get_int(map, key) when is_map(map) do
    case map[key] do
      v when is_integer(v) and v >= 0 -> v
      _other -> 0
    end
  end

  def get_int(_map, _key), do: 0

  @doc """
  Extracts the session ID from a Gemini event map.

  Gemini's output uses several different field names across CLI versions.
  Returns the first non-empty value found, or `nil`.
  """
  @spec read_session_id(map()) :: String.t() | nil
  def read_session_id(event) when is_map(event) do
    candidates = [
      get_string(event, "session_id"),
      get_string(event, "sessionId"),
      get_string(event, "sessionID"),
      get_string(event, "checkpoint_id"),
      get_string(event, "thread_id")
    ]

    Enum.find_value(candidates, fn
      v when is_binary(v) and v != "" -> String.trim(v)
      _other -> nil
    end)
  end

  def read_session_id(_event), do: nil

  @doc """
  Collects text strings from a Gemini `message` value.

  Gemini `assistant` events carry `message` in several shapes:
  - A bare binary — returned as a single-element list.
  - A map with a `"text"` key — that text is returned.
  - A map with a `"content"` list of part objects — text parts are extracted.

  Part types recognised: `"output_text"`, `"text"`, `"content"`.
  Returns a (possibly empty) list of non-blank strings.
  """
  @spec collect_message_text(term()) :: [String.t()]
  def collect_message_text(message) when is_binary(message) do
    trimmed = String.trim(message)
    if trimmed == "", do: [], else: [trimmed]
  end

  def collect_message_text(message) when is_map(message) do
    direct = get_string(message, "text") |> trim_or_nil()
    direct_lines = if direct, do: [direct], else: []

    content_lines =
      get_list(message, "content")
      |> Enum.flat_map(fn part ->
        case part do
          %{"type" => type, "text" => text}
          when type in ["output_text", "text", "content"] and is_binary(text) ->
            trimmed = String.trim(text)
            if trimmed == "", do: [], else: [trimmed]

          %{"type" => type, "content" => content}
          when type in ["output_text", "text", "content"] and is_binary(content) ->
            trimmed = String.trim(content)
            if trimmed == "", do: [], else: [trimmed]

          _other ->
            []
        end
      end)

    direct_lines ++ content_lines
  end

  def collect_message_text(_other), do: []

  @doc """
  Accumulates token usage from a Gemini usage map into an existing accumulator.

  Gemini usage appears in two locations (`usage` or `usageMetadata`) and uses
  multiple key naming conventions across CLI versions (snake_case and camelCase).

  Returns an updated `%{input_tokens, cached_input_tokens, output_tokens}` map.
  """
  @spec accumulate_usage(map(), term()) :: map()
  def accumulate_usage(acc, usage_raw) when is_map(usage_raw) do
    # Gemini nests token counts under usageMetadata inside the usage object.
    # When the caller already extracted usageMetadata from the event top-level,
    # that map will NOT have a nested usageMetadata key — use it directly.
    nested = get_map(usage_raw, "usageMetadata")
    source = if map_size(nested) > 0, do: nested, else: usage_raw

    input = read_first_int(source, ["input_tokens", "inputTokens", "promptTokenCount"])

    cached =
      read_first_int(source, [
        "cached_input_tokens",
        "cachedInputTokens",
        "cachedContentTokenCount"
      ])

    output = read_first_int(source, ["output_tokens", "outputTokens", "candidatesTokenCount"])

    %{
      input_tokens: acc.input_tokens + input,
      cached_input_tokens: acc.cached_input_tokens + cached,
      output_tokens: acc.output_tokens + output
    }
  end

  def accumulate_usage(acc, _other), do: acc

  @doc """
  Extracts a cost-in-USD float from an event map.

  Checks `total_cost_usd`, `cost_usd`, and `cost` keys in order. Returns `nil`
  when no numeric cost value is found.
  """
  @spec extract_cost(map()) :: float() | nil
  def extract_cost(event) when is_map(event) do
    candidates = [event["total_cost_usd"], event["cost_usd"], event["cost"]]

    Enum.find_value(candidates, fn
      v when is_float(v) -> v
      v when is_integer(v) -> v * 1.0
      _other -> nil
    end)
  end

  def extract_cost(_event), do: nil

  @doc """
  Extracts a human-readable error message from a Gemini event value.

  Accepts:
  - A bare binary — returned as-is.
  - A map with `message`, `error`, `code`, or `detail` — first non-empty string.
  - Anything else — JSON-encoded.
  """
  @spec extract_error_text(term()) :: String.t()
  def extract_error_text(value) when is_binary(value), do: value

  def extract_error_text(value) when is_map(value) do
    candidates = [
      get_string(value, "message"),
      get_string(value, "error"),
      get_string(value, "code"),
      get_string(value, "detail")
    ]

    Enum.find(candidates, fn v -> is_binary(v) and v != "" end) ||
      Jason.encode!(value)
  end

  def extract_error_text(nil), do: ""
  def extract_error_text(other), do: Jason.encode!(other)

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec read_first_int(map(), [String.t()]) :: non_neg_integer()
  defp read_first_int(map, keys) do
    Enum.find_value(keys, 0, fn key ->
      case map[key] do
        v when is_integer(v) and v >= 0 -> v
        _other -> nil
      end
    end)
  end

  @spec trim_or_nil(String.t() | nil) :: String.t() | nil
  defp trim_or_nil(nil), do: nil

  defp trim_or_nil(s) do
    trimmed = String.trim(s)
    if trimmed == "", do: nil, else: trimmed
  end
end
