defmodule Canopy.Repo.Migrations.CreateBudgets do
  use Ecto.Migration

  def change do
    create table(:budgets, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :scope_type, :string, null: false
      add :scope_id, :binary_id, null: true

      add :period, :string, null: false

      add :limit_usd, :decimal, precision: 12, scale: 6, null: false
      add :soft_alert_pct, :integer, null: false, default: 80
      add :hard_ceiling, :boolean, null: false, default: true
      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    # Two partial unique indexes to correctly handle NULL scope_id.
    # In Postgres, NULL != NULL so a single unique index on (scope_type, scope_id, period)
    # would allow multiple rows with scope_id = NULL.
    create unique_index(:budgets, [:scope_type, :period],
             where: "scope_id IS NULL",
             name: :budgets_scope_period_unique
           )

    create unique_index(:budgets, [:scope_type, :scope_id, :period],
             where: "scope_id IS NOT NULL",
             name: :budgets_scope_id_period_unique
           )

    create index(:budgets, [:scope_type])
    create index(:budgets, [:enabled])
  end
end
