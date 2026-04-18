defmodule Canopy.Repo.Migrations.AddPersonaMarkdownToAgents do
  @moduledoc """
  Adds persona_markdown TEXT column to the agents table.

  This moves persona content from priv/agents/*.md files (read per-heartbeat inside
  Oban workers) into the database, eliminating the filesystem stall in the heartbeat
  queue at concurrency=5.

  Migration is non-locking: ADD COLUMN with a non-volatile DEFAULT is a metadata-only
  operation in Postgres 11+. No CONCURRENTLY needed — no index is created here.

  ## Backfill

  The column is added as nullable with default '' so existing rows are immediately
  valid. Backfill happens by re-running:

      mix canopy.seed.agents

  after this migration is applied. The seeder now extracts the body of each markdown
  file (everything after the YAML frontmatter block) and writes it into persona_markdown.
  persona_path remains as a backward reference to the source file.

  ## Source-of-truth note

  After seeding, persona_markdown IS the authoritative runtime value. The file at
  persona_path is the seed source only and is never read at runtime.
  """

  use Ecto.Migration

  def change do
    alter table(:agents) do
      add :persona_markdown, :text, default: ""
    end
  end
end
