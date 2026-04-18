defmodule Canopy.Repo.Migrations.AddObanJobsArgsGinIndex do
  @moduledoc """
  Adds a GIN index on oban_jobs.args (JSONB).

  Closes audit finding: Registrar.unregister/1 uses
  fragment("?->>'agent_slug' = ?", j.args, ^slug) which performs a full sequential
  scan on the oban_jobs table. A GIN index on args lets Postgres use an index
  containment check for JSONB key access.

  @disable_migration_lock is NOT set because oban_jobs is Oban-owned and typically
  small in dev. CONCURRENTLY still prevents holding a share-update lock during the build.
  """

  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(
             :oban_jobs,
             [:args],
             name: :oban_jobs_args_gin_idx,
             using: "GIN",
             concurrently: true
           )
  end
end
