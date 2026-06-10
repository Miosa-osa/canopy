defmodule Canopy.Repo.Migrations.MakeBudgetIncidentAgentIdNullable do
  use Ecto.Migration

  def change do
    # agent_id was originally NOT NULL but budget incidents can now be created
    # at team/department/division/organization scope where agent_id is not applicable.
    # The scope_type + scope_id columns (added in 20260323000007) are the canonical
    # identifiers; agent_id is kept for backwards compatibility on agent-scope incidents.
    alter table(:budget_incidents) do
      modify :agent_id, :binary_id, null: true
    end
  end
end
