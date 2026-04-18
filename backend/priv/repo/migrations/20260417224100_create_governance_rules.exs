defmodule Canopy.Repo.Migrations.CreateGovernanceRules do
  use Ecto.Migration

  def change do
    create table(:governance_rules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :enabled, :boolean, default: true, null: false
      add :priority, :integer, default: 0, null: false
      add :conditions, :map, null: false, default: %{}
      add :action, :string, null: false
      add :audit_context, :map, default: %{}

      timestamps()
    end

    create index(:governance_rules, [:enabled, :priority])
    create unique_index(:governance_rules, [:name])
  end
end
