defmodule Canopy.Budgets.Budget do
  @moduledoc """
  Ecto schema for a budget policy record.

  A budget constrains spending for a given scope (agent, workspace, runtime, or global)
  over a given period (daily, weekly, monthly, total). Enforcement operates at three tiers:

    1. Visibility — spend is always tracked and visible.
    2. Soft alert — at `soft_alert_pct`% of the limit, callers receive `{:warn, ...}`.
    3. Hard ceiling — at 100% of the limit (when `hard_ceiling: true`), callers receive
       `{:block, ...}` and the session should be denied.

  The `scope_id` is nullable for global budgets. For scoped budgets it must reference
  a valid agent, workspace, or runtime record (not enforced at the DB FK level to keep
  the schema polymorphic).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @scope_types ~w(agent workspace runtime global)
  @periods ~w(daily weekly monthly total)

  @derive {Jason.Encoder,
           only: [
             :id,
             :scope_type,
             :scope_id,
             :period,
             :limit_usd,
             :soft_alert_pct,
             :hard_ceiling,
             :enabled,
             :inserted_at,
             :updated_at
           ]}

  schema "budgets" do
    field :scope_type, :string
    field :scope_id, :binary_id
    field :period, :string
    field :limit_usd, :decimal
    field :soft_alert_pct, :integer, default: 80
    field :hard_ceiling, :boolean, default: true
    field :enabled, :boolean, default: true

    has_many :spend_snapshots, Canopy.Budgets.SpendSnapshot

    timestamps()
  end

  @required ~w(scope_type period limit_usd)a
  @optional ~w(scope_id soft_alert_pct hard_ceiling enabled)a

  @doc "Changeset for creating a budget."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(budget, attrs) do
    budget
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:scope_type, @scope_types)
    |> validate_inclusion(:period, @periods)
    |> validate_number(:limit_usd, greater_than: Decimal.new(0))
    |> validate_number(:soft_alert_pct, greater_than_or_equal_to: 1, less_than_or_equal_to: 100)
    |> unique_constraint([:scope_type, :period],
      name: :budgets_scope_period_unique,
      message: "already exists for this scope and period"
    )
    |> unique_constraint([:scope_type, :scope_id, :period],
      name: :budgets_scope_id_period_unique,
      message: "already exists for this scope and period"
    )
  end

  @doc "Changeset for updating mutable fields on an existing budget."
  @spec update_changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def update_changeset(budget, attrs) do
    budget
    |> cast(attrs, [:limit_usd, :soft_alert_pct, :hard_ceiling, :enabled])
    |> validate_number(:limit_usd, greater_than: Decimal.new(0))
    |> validate_number(:soft_alert_pct, greater_than_or_equal_to: 1, less_than_or_equal_to: 100)
  end
end
