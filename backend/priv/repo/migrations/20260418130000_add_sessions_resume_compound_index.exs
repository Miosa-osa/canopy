defmodule Canopy.Repo.Migrations.AddSessionsResumeCompoundIndex do
  @moduledoc """
  Adds a compound partial index on sessions(agent_slug, workspace_slug, status, inserted_at)
  filtered to status = 'completed'.

  Closes audit finding #6: Resume.find_resumable/4 was doing a full sequential scan when
  filtering on agent_slug + workspace_slug + status + inserted_at. At 100x scale this is
  catastrophic — the index reduces that to an index-range scan on at most 30 days of
  completed rows for the given (agent_slug, workspace_slug) pair.

  CONCURRENTLY is safe here — the partial WHERE clause means Postgres only scans the
  completed subset, so lock-free index build is fast even on large tables.
  """

  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(
             :sessions,
             [:agent_slug, :workspace_slug, :status, :inserted_at],
             name: :sessions_resume_lookup_idx,
             concurrently: true,
             where: "status = 'completed'"
           )
  end
end
