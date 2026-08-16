defmodule Canopy.Repo.Migrations.CreateToolPermissionGrants do
  @moduledoc """
  Tool permission grants — 5-scope permission taxonomy for agent tool access.

  Scopes: once | session | today | forever | never

  The (agent_slug, tool_name) composite index supports the hot path in
  `Governance.check_permission/3`. The workspace_slug index supports
  workspace-scoped grant listing.
  """

  use Ecto.Migration

  def change do
    create table(:tool_permission_grants, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :agent_slug, :string, null: false, size: 255
      add :tool_name, :string, null: false, size: 255
      add :scope, :string, null: false, size: 16
      add :workspace_slug, :string, size: 255
      add :session_id, :binary_id
      add :granted_by, :string, null: false, default: "human", size: 255
      add :expires_at, :utc_datetime_usec
      add :used, :boolean, null: false, default: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:tool_permission_grants, [:agent_slug, :tool_name])
    create index(:tool_permission_grants, [:workspace_slug])
    create index(:tool_permission_grants, [:expires_at])
    create index(:tool_permission_grants, [:scope])
  end
end
