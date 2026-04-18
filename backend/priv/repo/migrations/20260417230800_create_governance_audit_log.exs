defmodule Canopy.Repo.Migrations.CreateGovernanceAuditLog do
  use Ecto.Migration

  def change do
    create table(:governance_audit_log, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :rule_id, references(:governance_rules, type: :binary_id, on_delete: :nilify_all)
      add :session_id, references(:sessions, type: :binary_id, on_delete: :nilify_all)
      add :event_type, :string, null: false
      add :payload, :map, null: false, default: %{}
      add :occurred_at, :utc_datetime_usec, null: false
    end

    create index(:governance_audit_log, [:occurred_at])
    create index(:governance_audit_log, [:session_id])
    create index(:governance_audit_log, [:event_type])
  end
end
