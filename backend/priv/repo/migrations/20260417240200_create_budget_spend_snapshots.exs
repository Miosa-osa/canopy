defmodule Canopy.Repo.Migrations.CreateBudgetSpendSnapshots do
  use Ecto.Migration

  def change do
    create table(:budget_spend_snapshots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :budget_id, references(:budgets, type: :binary_id, on_delete: :delete_all), null: false

      add :period_start, :utc_datetime, null: false
      add :period_end, :utc_datetime, null: false
      add :actual_spend_usd, :decimal, precision: 12, scale: 6, null: false
      add :session_count, :integer, null: false, default: 0
      add :snapshot_at, :utc_datetime_usec, null: false

      # Append-only: no updated_at
      add :inserted_at, :utc_datetime, null: false
    end

    create index(:budget_spend_snapshots, [:budget_id])
    create index(:budget_spend_snapshots, [:budget_id, :snapshot_at])
  end
end
