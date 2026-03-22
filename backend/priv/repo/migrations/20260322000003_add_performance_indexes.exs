defmodule Canopy.Repo.Migrations.AddPerformanceIndexes do
  use Ecto.Migration

  def change do
    # Sessions: queried heavily by agent_id and status
    create_if_not_exists index(:sessions, [:agent_id])
    create_if_not_exists index(:sessions, [:status])
    create_if_not_exists index(:sessions, [:agent_id, :status])

    # Schedules: queried by agent_id (no index exists)
    create_if_not_exists index(:schedules, [:agent_id])

    # Cost events: inserted_at for time-range aggregations (agent_id index already exists)
    create_if_not_exists index(:cost_events, [:inserted_at])

    # Goals: queried by project_id
    create_if_not_exists index(:goals, [:project_id])

    # Memory entries: GIN full-text search on content
    execute(
      "CREATE INDEX IF NOT EXISTS memory_entries_content_gin ON memory_entries USING gin(to_tsvector('english', content))",
      "DROP INDEX IF EXISTS memory_entries_content_gin"
    )

    # Audit events: paginated by inserted_at
    create_if_not_exists index(:audit_events, [:inserted_at])

    # Activity events: sorted/filtered by inserted_at (workspace_id index already exists)
    create_if_not_exists index(:activity_events, [:inserted_at])
  end
end
