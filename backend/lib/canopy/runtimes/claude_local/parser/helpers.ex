defmodule Canopy.Runtimes.ClaudeLocal.Parser.Helpers do
  @moduledoc """
  Internal extractors for Claude stream-json parsing.

  Thin, well-typed, pure functions used by `Canopy.Runtimes.ClaudeLocal.Parser`
  to safely access typed values from raw decoded JSON maps.  Each getter returns
  a sensible default rather than raising when the key is absent or the value has
  an unexpected type.

  Also contains `parse_tool_result_content/1` and `parse_errors/1`, which
  normalise Claude's polymorphic content fields into stable Elixir types.

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
  Normalises a Claude tool-result content value into a plain string.

  Claude tool results carry `content` in one of three shapes:
  - A bare binary — returned as-is.
  - A list of content-block maps — text blocks are joined with newlines; other
    blocks are JSON-encoded.
  - `nil` — returns `""`.
  - Anything else — JSON-encoded.
  """
  @spec parse_tool_result_content(term()) :: String.t()
  def parse_tool_result_content(content) when is_binary(content), do: content

  def parse_tool_result_content(content) when is_list(content) do
    content
    |> Enum.filter(&is_map/1)
    |> Enum.map_join("\n", fn
      %{"type" => "text", "text" => t} when is_binary(t) -> t
      other -> Jason.encode!(other)
    end)
  end

  def parse_tool_result_content(nil), do: ""
  def parse_tool_result_content(other), do: Jason.encode!(other)

  @doc """
  Extracts error messages from the `errors` field of a Claude `result` event.

  Accepts a list of bare strings, `%{"message" => msg}` maps, or
  `%{"error" => msg}` maps.  Returns a flat list of error message strings.
  Unknown entries are silently dropped.
  """
  @spec parse_errors(term()) :: [String.t()]
  def parse_errors(errors) when is_list(errors) do
    Enum.flat_map(errors, fn
      msg when is_binary(msg) -> [msg]
      %{"message" => msg} when is_binary(msg) -> [msg]
      %{"error" => msg} when is_binary(msg) -> [msg]
      _other -> []
    end)
  end

  def parse_errors(_other), do: []
end
