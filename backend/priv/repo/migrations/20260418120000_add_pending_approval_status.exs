defmodule Canopy.Repo.Migrations.AddPendingApprovalStatus do
  use Ecto.Migration

  @moduledoc """
  Documents the addition of `pending_approval` to the sessions.status column.

  The column is a plain :string (not a Postgres enum), so no DDL ALTER is
  required — the new status value is enforced by the Ecto changeset validation
  in `Canopy.Sessions.Session`. This migration exists as an audit trail so the
  schema history reflects every status lifecycle change.
  """

  def up do
    execute """
    COMMENT ON COLUMN sessions.status IS
    'Valid values: pending, running, completed, cancelled, failed, pending_approval';
    """
  end

  def down do
    execute """
    COMMENT ON COLUMN sessions.status IS
    'Valid values: pending, running, completed, cancelled, failed';
    """
  end
end
