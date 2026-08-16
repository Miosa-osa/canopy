defmodule Canopy.Analytics.Breadcrumb do
  @moduledoc """
  Per-run trail entry capturing what an agent did, in order, with enough
  context to reconstruct an investigation later.

  Implemented as a ring buffer in ETS during a run (cap configurable per
  agent persona, default 100, max 1000). Flushed to Postgres on run
  completion via `Canopy.Analytics.Breadcrumbs.flush_run/1`.

  Each breadcrumb has a `type` (tool_call, http, db, governance, navigation,
  user, system), a `category` (free-form for sub-classification), and a
  `level` (debug, info, warning, error, fatal). The `data` map carries the
  payload — tool args, HTTP method/url/status, query string, etc.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @types ~w(tool_call http db governance navigation user system)
  @levels ~w(debug info warning error fatal)

  @derive {Jason.Encoder,
           only: [
             :id,
             :run_id,
             :session_id,
             :sequence,
             :ts,
             :type,
             :category,
             :level,
             :message,
             :data,
             :inserted_at
           ]}

  schema "analytics_breadcrumbs" do
    field :run_id, :binary_id
    field :session_id, :binary_id
    field :sequence, :integer
    field :ts, :utc_datetime_usec
    field :type, :string
    field :category, :string
    field :level, :string, default: "info"
    field :message, :string
    field :data, :map, default: %{}

    timestamps(updated_at: false)
  end

  @required ~w(run_id sequence ts type)a
  @optional ~w(session_id category level message data)a

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:type, @types)
    |> validate_inclusion(:level, @levels)
    |> validate_number(:sequence, greater_than_or_equal_to: 0)
  end

  def types, do: @types
  def levels, do: @levels
end
