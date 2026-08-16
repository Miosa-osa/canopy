defmodule Canopy.Build.LayoutUse do
  @moduledoc """
  Telemetry record — one row per "user opened/loaded layout X" event.

  The `Canopy.Build.suggest_layout/1` ranker reads this table to compute a
  recency-weighted use score per layout, combined with a fuzzy match on the
  layout's name + description vs the supplied intent. Recent uses dominate;
  the table is append-only.

  Rows are deleted via `ON DELETE CASCADE` if the parent layout is hard-deleted.
  Most flows soft-delete via `archived_at` instead, preserving history.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @derive {Jason.Encoder,
           only: [
             :id,
             :layout_id,
             :user_id,
             :workspace_slug,
             :intent,
             :opened_at,
             :inserted_at
           ]}

  schema "build_layout_uses" do
    field :layout_id, :binary_id
    field :user_id, :binary_id
    field :workspace_slug, :string
    field :intent, :string
    field :opened_at, :utc_datetime_usec

    timestamps(updated_at: false)
  end

  @required ~w(layout_id opened_at)a
  @optional ~w(user_id workspace_slug intent)a

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:intent, max: 256)
    |> foreign_key_constraint(:layout_id)
  end
end
