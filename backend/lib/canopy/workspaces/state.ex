defmodule Canopy.Workspaces.State do
  @moduledoc """
  Ecto schema for a single per-workspace state entry.

  Each row is a (workspace_slug, key) → JSON value tuple. Keys are
  module-agnostic — any feature can read or write its own namespace
  (e.g. `"mosaic.layout"`, `"build.sideRail.section"`,
  `"files.recentPaths"`).

  Validation rules (match the analytics pattern):
    * `workspace_slug` — `[a-z0-9][a-z0-9_-]{0,127}`
    * `key`            — `[a-z0-9][a-z0-9._-]{0,127}` (dots allowed for namespaces)

  Value-size and per-workspace cardinality limits are enforced at the
  context boundary (`Canopy.Workspaces.States`), not in the changeset.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @derive {Jason.Encoder, only: [:id, :workspace_slug, :key, :value, :inserted_at, :updated_at]}

  @workspace_slug_regex ~r/\A[a-z0-9][a-z0-9_-]{0,127}\z/
  # Keys are programmatic identifiers — allow camelCase + dots/underscores/dashes.
  # Module owners namespace via dots (e.g. `files.recentPaths`, `build.sideRail.section`).
  @key_regex ~r/\A[A-Za-z0-9][A-Za-z0-9._-]{0,127}\z/

  schema "workspace_states" do
    field :workspace_slug, :string
    field :key, :string
    field :value, Canopy.Workspaces.State.JsonValue, default: %{}

    timestamps()
  end

  @required ~w(workspace_slug key value)a

  @doc "Changeset for inserting or updating a workspace state entry."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(state, attrs) do
    state
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> validate_length(:workspace_slug, min: 1, max: 128)
    |> validate_length(:key, min: 1, max: 128)
    |> validate_format(:workspace_slug, @workspace_slug_regex)
    |> validate_format(:key, @key_regex)
    |> unique_constraint([:workspace_slug, :key],
      name: :workspace_states_slug_key_index
    )
  end

  @doc "Returns the workspace_slug regex used for validation."
  @spec workspace_slug_regex() :: Regex.t()
  def workspace_slug_regex, do: @workspace_slug_regex

  @doc "Returns the key regex used for validation."
  @spec key_regex() :: Regex.t()
  def key_regex, do: @key_regex
end
