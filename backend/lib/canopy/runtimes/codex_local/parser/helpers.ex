defmodule Canopy.Runtimes.CodexLocal.Parser.Helpers do
  @moduledoc """
  Internal extractors for Codex stream-json parsing.

  Thin, well-typed, pure functions used by `Canopy.Runtimes.CodexLocal.Parser`
  to safely access typed values from raw decoded JSON maps. Each getter returns
  a sensible default rather than raising when the key is absent or the value has
  an unexpected type.

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
  Normalises a Codex tool-call output content value into a plain string.

  Codex tool results carry `output` as either:
  - A bare binary — returned as-is.
  - A list of content-block maps — text blocks are joined; others JSON-encoded.
  - `nil` — returns `""`.
  - Anything else — JSON-encoded.
  """
  @spec parse_output_content(term()) :: String.t()
  def parse_output_content(content) when is_binary(content), do: content

  def parse_output_content(content) when is_list(content) do
    content
    |> Enum.filter(&is_map/1)
    |> Enum.map_join("\n", fn
      %{"type" => "text", "text" => t} when is_binary(t) -> t
      other -> Jason.encode!(other)
    end)
  end

  def parse_output_content(nil), do: ""
  def parse_output_content(other), do: Jason.encode!(other)
end
