defmodule Canopy.Repo.Migrations.AddGovernanceAuditLogSessionOccurredIdx do
  @moduledoc """
  Adds a compound index on governance_audit_log(session_id, occurred_at).

  Closes audit finding: governance.ex:269-274 queries by session_id + occurred_at
  range. The existing single-column indexes on session_id and occurred_at force the
  planner to choose one or the other; the compound index covers both filter dimensions
  in a single index scan, which is critical as the audit log grows toward 15M rows/month
  at 100x scale.
  """

  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(
             :governance_audit_log,
             [:session_id, :occurred_at],
             name: :governance_audit_session_occurred_idx,
             concurrently: true
           )
  end
end
