/**
 * Knowledge domain types — matches /api/v1/knowledge-bases backend shape.
 * Phase 5 Wave 2 Track #105.
 */

/** A knowledge base — named collection of chunked, embedded documents for RAG. */
export interface KnowledgeBase {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  workspace_slug: string | null;
  embedding_model: string;
  dimensions: number;
  chunk_size: number;
  chunk_overlap: number;
  chunk_count?: number;
  agent_count?: number;
  archived_at: string | null;
  inserted_at: string;
  updated_at: string;
}

/** A single chunk of indexed content within a KB. */
export interface KbChunk {
  id: string;
  kb_id: string;
  source_file_id: string | null;
  source_path: string;
  chunk_index: number;
  content: string;
  content_hash: string;
  token_count: number;
  metadata: Record<string, unknown>;
  inserted_at: string;
}

/** A KB-to-agent assignment record. */
export interface KbAssignment {
  id: string;
  kb_id: string;
  agent_slug: string;
  priority: number;
  inserted_at: string;
}

/** Request body for creating a knowledge base. */
export interface CreateBaseBody {
  slug: string;
  name: string;
  description?: string;
  workspace_slug?: string;
  embedding_model?: string;
  dimensions?: number;
  chunk_size?: number;
  chunk_overlap?: number;
}

/** Request body for adding a Files-backed file to a KB. */
export interface AddFileBody {
  file_id: string;
}

/** Request body for KB semantic search. */
export interface SearchBody {
  query: string;
  limit?: number;
}

/** Paginated chunk list response. */
export interface KbChunkListResponse {
  data: KbChunk[];
  limit: number;
  offset: number;
}

/** Search result response. */
export interface SearchResponse {
  data: KbChunk[];
  query: string;
  note: string;
}

/** Result of adding a file or rebuilding the index. */
export interface IndexResult {
  indexed_chunks?: number;
  rebuilt_chunks?: number;
}
