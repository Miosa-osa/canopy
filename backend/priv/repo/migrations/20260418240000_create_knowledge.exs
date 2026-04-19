defmodule Canopy.Repo.Migrations.CreateKnowledge do
  @moduledoc """
  Knowledge Bases module — Phase 5 Wave 2 Track #105.

  Three tables:
    knowledge_bases      — KB metadata and configuration
    kb_chunks            — chunked content with pgvector embeddings
    kb_agent_assignments — many-to-many KB ↔ agent mapping

  pgvector CREATE EXTENSION already handled in 20260417211347_enable_pgvector.exs.
  ivfflat index: lists=100 is appropriate for up to ~1M vectors per KB; adjust
  lists = sqrt(rows) when row counts are known at production time.
  """

  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS citext"

    # -------------------------------------------------------------------------
    # knowledge_bases
    # -------------------------------------------------------------------------
    create table(:knowledge_bases, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")

      add :slug, :citext, null: false
      add :name, :string, null: false
      add :description, :text
      add :workspace_slug, :string

      add :embedding_model, :string, null: false, default: "text-embedding-3-small"
      add :dimensions, :integer, null: false, default: 1536
      add :chunk_size, :integer, null: false, default: 800
      add :chunk_overlap, :integer, null: false, default: 100

      add :archived_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:knowledge_bases, [:slug])

    create index(:knowledge_bases, [:workspace_slug],
             where: "workspace_slug IS NOT NULL",
             name: :knowledge_bases_workspace_slug_idx
           )

    create index(:knowledge_bases, [:archived_at],
             where: "archived_at IS NULL",
             name: :knowledge_bases_active_idx
           )

    # -------------------------------------------------------------------------
    # kb_chunks
    # -------------------------------------------------------------------------
    create table(:kb_chunks, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")

      add :kb_id,
          references(:knowledge_bases, type: :binary_id, on_delete: :delete_all),
          null: false

      add :source_file_id,
          references(:files, type: :binary_id, on_delete: :nilify_all),
          null: true

      add :source_path, :string, null: false
      add :chunk_index, :integer, null: false
      add :content, :text, null: false
      add :content_hash, :string, null: false
      add :token_count, :integer, null: false, default: 0
      add :embedding, :vector, size: 1536
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:kb_chunks, [:kb_id, :source_path, :chunk_index],
             name: :kb_chunks_kb_source_chunk_idx
           )

    create index(:kb_chunks, [:kb_id, :chunk_index], name: :kb_chunks_kb_chunk_idx)

    create index(:kb_chunks, [:source_file_id],
             where: "source_file_id IS NOT NULL",
             name: :kb_chunks_source_file_idx
           )

    create index(:kb_chunks, [:content_hash], name: :kb_chunks_content_hash_idx)

    # ivfflat cosine-distance ANN index for semantic search.
    # lists=100 is appropriate for up to ~1M rows; tune at scale.
    execute """
    CREATE INDEX kb_chunks_embedding_ivfflat_idx
      ON kb_chunks
      USING ivfflat (embedding vector_cosine_ops)
      WITH (lists = 100)
    """

    # -------------------------------------------------------------------------
    # kb_agent_assignments
    # -------------------------------------------------------------------------
    create table(:kb_agent_assignments, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")

      add :kb_id,
          references(:knowledge_bases, type: :binary_id, on_delete: :delete_all),
          null: false

      add :agent_slug, :string, null: false
      add :priority, :integer, null: false, default: 0

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:kb_agent_assignments, [:kb_id, :agent_slug],
             name: :kb_agent_assignments_kb_agent_idx
           )

    create index(:kb_agent_assignments, [:agent_slug], name: :kb_agent_assignments_agent_idx)
  end

  def down do
    execute "DROP INDEX IF EXISTS kb_chunks_embedding_ivfflat_idx"
    drop table(:kb_agent_assignments)
    drop table(:kb_chunks)
    drop table(:knowledge_bases)
  end
end
