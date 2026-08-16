defmodule Canopy.Workspaces.State.JsonValue do
  @moduledoc """
  Ecto custom type that stores any JSON-serialisable value in a Postgres
  `jsonb` column.

  The default `:map` type rejects non-map values at cast time, but workspace
  state keys legitimately hold arrays (e.g. `files.recentPaths` →
  `["a.md", "b.md"]`), strings (e.g. `build.sideRail.section` → `"conversations"`),
  and primitives. This type accepts any of those.
  """

  use Ecto.Type

  @impl true
  def type, do: :map

  @impl true
  def cast(value)
      when is_map(value) or is_list(value) or is_binary(value) or
             is_number(value) or is_boolean(value) or is_nil(value),
      do: {:ok, value}

  def cast(_), do: :error

  @impl true
  def load(value), do: {:ok, value}

  @impl true
  def dump(value)
      when is_map(value) or is_list(value) or is_binary(value) or
             is_number(value) or is_boolean(value) or is_nil(value),
      do: {:ok, value}

  def dump(_), do: :error
end
