defmodule Canopy.Repo.Migrations.CreateGovernanceApprovals do
  use Ecto.Migration

  def change do
    create table(:governance_approvals, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :rule_id, references(:governance_rules, type: :binary_id, on_delete: :restrict),
        null: false

      add :session_id, references(:sessions, type: :binary_id, on_delete: :nilify_all),
        null: false

      add :status, :string, null: false, default: "pending"
      add :requested_at, :utc_datetime_usec, null: false
      add :decided_at, :utc_datetime_usec
      add :expires_at, :utc_datetime_usec
      add :decided_by, :string
      add :decision_reason, :text

      timestamps()
    end

    create index(:governance_approvals, [:session_id, :status])
    create index(:governance_approvals, [:rule_id])
    create index(:governance_approvals, [:status])
  end
end
