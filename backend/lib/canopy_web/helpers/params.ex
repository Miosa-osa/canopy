defmodule CanopyWeb.Helpers.Params do
  @moduledoc """
  Safe parameter parsing helpers for controllers.
  """

  @doc """
  Safely parses an integer from a string param with a fallback default.
  Returns the default if the value is nil, empty, or not a valid integer.
  """
  def parse_int(nil, default), do: default
  def parse_int("", default), do: default

  def parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {n, _} -> n
      :error -> default
    end
  end

  def parse_int(value, _default) when is_integer(value), do: value
  def parse_int(_, default), do: default
end
