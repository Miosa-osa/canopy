defmodule Canopy.Repo.Migrations.AddCheckoutToIssues do
  use Ecto.Migration

  def change do
    alter table(:issues) do
      add :checked_out_by_agent, :string, null: true
      add :checked_out_at, :utc_datetime, null: true
      add :checkout_expires_at, :utc_datetime, null: true
    end

    create index(:issues, [:checked_out_by_agent])
  end
end
