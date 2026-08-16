defmodule Canopy.Repo.Migrations.CreateDriveEntries do
  @moduledoc """
  Drive super-module — unified shell of typed knowledge entries with Personal /
  Team scope.

  Entries are polymorphic. The `kind` enum tells callers how to interpret the
  `body` JSON column:

  - `folder`     → `{name, parent_id}` (organizational only)
  - `workflow`   → `{routine_id}` link to `routines`
  - `prompt`     → `{body, variables}` standalone (new primitive)
  - `notebook`   → `{session_id, block_ids[]}` link to `session_blocks`
  - `env_vars`   → `{vault_secret_ids[]}` link to credential vault rows
  - `mcp_server` → `{mcp_server_id}` link to MCP registry (Phase B)
  - `rule`       → `{body, applies_to: [agent_slugs]}` standalone (new primitive)

  The unique-slug constraint is scoped to `(scope, parent_id, slug)` so
  Personal and Team trees are independent and slugs only need to be unique
  within their containing folder.
  """

  use Ecto.Migration

  def change do
    create table(:drive_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :slug, :string, null: false, size: 128
      add :name, :string, null: false, size: 256
      add :kind, :string, null: false, size: 32
      add :scope, :string, null: false, size: 16

      add :parent_id,
          references(:drive_entries, type: :binary_id, on_delete: :nilify_all)

      add :body, :map, default: %{}, null: false
      add :owner_id, :binary_id
      add :tags, {:array, :string}, default: [], null: false
      add :position, :integer, default: 0, null: false
      add :archived_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:drive_entries, [:scope, :parent_id, :position])
    create index(:drive_entries, [:kind])
    create index(:drive_entries, [:owner_id])
    create index(:drive_entries, [:archived_at])
    create index(:drive_entries, [:tags], using: "GIN")

    # Slug must be unique within (scope, parent_id). For PG < 15 compat,
    # use a partial unique index + coalesce instead of NULLS NOT DISTINCT.
    execute(
      "CREATE UNIQUE INDEX drive_entries_scope_parent_slug_index ON drive_entries (scope, COALESCE(parent_id, '00000000-0000-0000-0000-000000000000'::uuid), slug)",
      "DROP INDEX IF EXISTS drive_entries_scope_parent_slug_index"
    )
  end
end
