defmodule Canopy.Repo.Migrations.AddProtocolFieldsToAgents do
  use Ecto.Migration

  def change do
    alter table(:agents) do
      add :title, :string
      add :signal, :string
      add :context_tier, :string, default: "l1"
      add :budget_monthly_cents, :integer
      add :tools, {:array, :string}, default: []
      add :color, :string
    end
  end
end
