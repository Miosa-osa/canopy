defmodule Canopy.Budgets.SpendSnapshot do
  @moduledoc """
  Ecto schema for a budget spend snapshot.

  Snapshots are append-only materialized observations of a budget's actual spend
  for a given period window. They are written by `Canopy.Budgets.Snapshotter` (Oban
  worker) on an hourly schedule and can also be queried directly for historical charts.

  The schema has no `updated_at` — once written a snapshot is immutable.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @derive {Jason.Encoder,
           only: [
             :id,
             :budget_id,
             :period_start,
             :period_end,
             :actual_spend_usd,
             :session_count,
             :snapshot_at,
             :inserted_at
           ]}

  schema "budget_spend_snapshots" do
    belongs_to :budget, Canopy.Budgets.Budget

    field :period_start, :utc_datetime
    field :period_end, :utc_datetime
    field :actual_spend_usd, :decimal
    field :session_count, :integer, default: 0
    field :snapshot_at, :utc_datetime_usec

    # Append-only: no updated_at. inserted_at is written by insert/2 directly.
    field :inserted_at, :utc_datetime
  end

  @required ~w(budget_id period_start period_end actual_spend_usd snapshot_at inserted_at)a
  @optional ~w(session_count)a

  @doc "Changeset for inserting a new spend snapshot (append-only)."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_number(:actual_spend_usd, greater_than_or_equal_to: 0)
    |> validate_number(:session_count, greater_than_or_equal_to: 0)
    |> assoc_constraint(:budget)
  end
end
