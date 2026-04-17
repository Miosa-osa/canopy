defmodule Canopy.Repo.Migrations.EnablePgvector do
  @moduledoc """
  Enables the pgvector PostgreSQL extension.

  pgvector is used for semantic search across agent memories, skills, and
  workspace content (Multica pattern — they have it installed but unused;
  we use it from day one).

  Requires PostgreSQL 14+ with the pgvector extension package installed:
    - macOS (Homebrew): `brew install pgvector`
    - Ubuntu: `apt-get install postgresql-14-pgvector`
  """

  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS vector"
  end

  def down do
    execute "DROP EXTENSION IF EXISTS vector"
  end
end
