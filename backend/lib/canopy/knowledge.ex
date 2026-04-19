defmodule Canopy.Knowledge do
  @moduledoc """
  Public API for Canopy knowledge bases.

  A knowledge base (KB) is a named store of chunked, embedded text fragments
  used to augment agent sessions with retrieved context (RAG). Chunks are
  stored in `kb_chunks` with pgvector cosine-distance embeddings.

  ## Embedding stub
  The embedding provider is currently stubbed (zero vectors). Search results
  are valid but not semantically ranked — order reflects insertion sequence.
  See `Canopy.Knowledge.Embedder` for the swap-in pattern.

  ## Key operations
    - `create_base/1` — create a named KB
    - `add_file_to_base/3` — chunk + embed + upsert content
    - `search/3` — top-K cosine similarity retrieval
    - `retrieve_for_agent/3` — fan-out search across all agent-assigned KBs
    - `rebuild_index/1` — delete all chunks, re-index from source paths
  """

  import Ecto.Query, only: [from: 2, where: 3]

  alias Canopy.Repo
  alias Canopy.Knowledge.{Chunker, Embedder, KbAgentAssignment, KbChunk, KnowledgeBase}

  # ---------------------------------------------------------------------------
  # Knowledge Base CRUD
  # ---------------------------------------------------------------------------

  @doc """
  Lists knowledge bases. Supports filters:
    - `:workspace` — filter by workspace_slug
    - `:archived` — `true` to include archived, `false` (default) for active only
  """
  @spec list_bases(keyword()) :: {:ok, [KnowledgeBase.t()]}
  def list_bases(filters \\ []) do
    query =
      from(kb in KnowledgeBase, order_by: [asc: kb.name])
      |> apply_workspace_filter(Keyword.get(filters, :workspace))
      |> apply_archived_filter(Keyword.get(filters, :archived, false))

    {:ok, Repo.all(query)}
  end

  @doc "Returns a KB by slug, or `{:error, :not_found}`."
  @spec get_base(String.t()) :: {:ok, KnowledgeBase.t()} | {:error, :not_found}
  def get_base(slug) do
    case Repo.get_by(KnowledgeBase, slug: slug) do
      nil -> {:error, :not_found}
      kb -> {:ok, kb}
    end
  end

  @doc """
  Creates a knowledge base.
  Returns `{:ok, kb}` or `{:error, changeset}`.
  """
  @spec create_base(map()) :: {:ok, KnowledgeBase.t()} | {:error, Ecto.Changeset.t()}
  def create_base(attrs) do
    %KnowledgeBase{}
    |> KnowledgeBase.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Soft-archives a knowledge base by setting `archived_at`.
  Returns `{:ok, kb}` or `{:error, :not_found}`.
  """
  @spec delete_base(String.t()) :: {:ok, KnowledgeBase.t()} | {:error, :not_found}
  def delete_base(id) do
    case Repo.get(KnowledgeBase, id) do
      nil ->
        {:error, :not_found}

      kb ->
        kb
        |> KnowledgeBase.changeset(%{archived_at: DateTime.utc_now()})
        |> Repo.update()
        |> case do
          {:ok, updated} -> {:ok, updated}
          {:error, _} = err -> err
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Chunk count helper (used by show endpoint)
  # ---------------------------------------------------------------------------

  @doc "Returns the count of chunks in a KB."
  @spec chunk_count(String.t()) :: non_neg_integer()
  def chunk_count(kb_id) do
    Repo.aggregate(from(c in KbChunk, where: c.kb_id == ^kb_id), :count, :id)
  end

  @doc "Returns the count of agent assignments for a KB."
  @spec agent_count(String.t()) :: non_neg_integer()
  def agent_count(kb_id) do
    Repo.aggregate(from(a in KbAgentAssignment, where: a.kb_id == ^kb_id), :count, :id)
  end

  # ---------------------------------------------------------------------------
  # File indexing
  # ---------------------------------------------------------------------------

  @doc """
  Adds content to a knowledge base by chunking, embedding, and upserting chunks.

  Accepts either:
    - `{:file_id, uuid}` — looks up content via Canopy.Files; sets `source_file_id`
    - `{:path, path, content_binary}` — uses content directly; `source_file_id` is nil

  Returns `{:ok, chunk_count}` or `{:error, reason}`.
  """
  @spec add_file_to_base(
          String.t(),
          {:file_id, String.t()} | {:path, String.t(), binary()},
          map()
        ) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def add_file_to_base(kb_id, source, metadata \\ %{}) do
    with {:ok, kb} <- get_kb_by_id(kb_id),
         {:ok, source_path, source_file_id, content} <- resolve_source(source),
         chunks <- Chunker.chunk_text(content, kb.chunk_size, kb.chunk_overlap),
         {:ok, _count} <- upsert_chunks(kb, chunks, source_path, source_file_id, metadata) do
      {:ok, length(chunks)}
    end
  end

  # ---------------------------------------------------------------------------
  # Chunk listing
  # ---------------------------------------------------------------------------

  @doc "Returns a paginated list of chunks for a KB."
  @spec list_chunks(String.t(), pos_integer(), non_neg_integer()) :: {:ok, [KbChunk.t()]}
  def list_chunks(kb_id, limit \\ 50, offset \\ 0) do
    chunks =
      from(c in KbChunk,
        where: c.kb_id == ^kb_id,
        order_by: [asc: c.source_path, asc: c.chunk_index],
        limit: ^limit,
        offset: ^offset
      )
      |> Repo.all()

    {:ok, chunks}
  end

  # ---------------------------------------------------------------------------
  # Search
  # ---------------------------------------------------------------------------

  @doc """
  Returns top-K chunks from a single KB by cosine similarity.

  # TODO: wire real embedding provider
  With the stub zero-vector, all cosine distances are equal (degenerate).
  PostgreSQL breaks ties by the physical row order, which in practice is
  chunk_index ascending within each source_path. Results are valid chunks —
  just not semantically ranked until a real provider is wired.
  """
  @spec search(String.t(), String.t(), pos_integer()) :: {:ok, [KbChunk.t()]}
  def search(kb_id, query_string, limit \\ 5) do
    {:ok, kb} = get_kb_by_id(kb_id)
    {:ok, query_vec} = Embedder.embed(query_string, kb.dimensions)

    chunks =
      from(c in KbChunk,
        where: c.kb_id == ^kb_id,
        order_by: fragment("embedding <=> ?::vector", ^query_vec),
        limit: ^limit
      )
      |> Repo.all()

    {:ok, chunks}
  end

  @doc """
  Fan-out search across all KBs assigned to `agent_slug`.
  Returns top-K results globally, sorted by distance then KB priority.
  """
  @spec retrieve_for_agent(String.t(), String.t(), pos_integer()) :: {:ok, [KbChunk.t()]}
  def retrieve_for_agent(agent_slug, query_string, limit \\ 5) do
    kb_ids =
      from(a in KbAgentAssignment,
        where: a.agent_slug == ^agent_slug,
        order_by: [asc: a.priority],
        select: a.kb_id
      )
      |> Repo.all()

    if kb_ids == [] do
      {:ok, []}
    else
      # Use first KB's dimensions as the query vector size (all KBs share 1536 by default).
      dimensions = 1536
      {:ok, query_vec} = Embedder.embed(query_string, dimensions)

      chunks =
        from(c in KbChunk,
          where: c.kb_id in ^kb_ids,
          order_by: fragment("embedding <=> ?::vector", ^query_vec),
          limit: ^limit
        )
        |> Repo.all()

      {:ok, chunks}
    end
  end

  # ---------------------------------------------------------------------------
  # Agent assignments
  # ---------------------------------------------------------------------------

  @doc "Assigns a KB to an agent. Idempotent via unique constraint."
  @spec assign(String.t(), String.t()) ::
          {:ok, KbAgentAssignment.t()} | {:error, Ecto.Changeset.t()}
  def assign(kb_id, agent_slug) do
    %KbAgentAssignment{}
    |> KbAgentAssignment.changeset(%{kb_id: kb_id, agent_slug: agent_slug})
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:kb_id, :agent_slug])
  end

  @doc "Removes a KB ↔ agent assignment. Returns `:ok` (idempotent)."
  @spec unassign(String.t(), String.t()) :: :ok
  def unassign(kb_id, agent_slug) do
    from(a in KbAgentAssignment,
      where: a.kb_id == ^kb_id and a.agent_slug == ^agent_slug
    )
    |> Repo.delete_all()

    :ok
  end

  @doc "Lists all assignments for a KB."
  @spec list_assignments(String.t()) :: {:ok, [KbAgentAssignment.t()]}
  def list_assignments(kb_id) do
    assignments =
      from(a in KbAgentAssignment,
        where: a.kb_id == ^kb_id,
        order_by: [asc: a.priority, asc: a.agent_slug]
      )
      |> Repo.all()

    {:ok, assignments}
  end

  # ---------------------------------------------------------------------------
  # Rebuild
  # ---------------------------------------------------------------------------

  @doc """
  Deletes all chunks for a KB and re-indexes from stored source paths.

  Currently re-indexes only chunks that have `source_file_id` set (Files-backed
  chunks). Directly-uploaded path/content pairs are NOT recoverable after delete
  because the original binary is not stored in Canopy — the UI should warn users
  of this before triggering rebuild.

  Returns `{:ok, new_chunk_count}` or `{:error, reason}`.
  """
  @spec rebuild_index(String.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def rebuild_index(kb_id) do
    with {:ok, kb} <- get_kb_by_id(kb_id) do
      # Gather file-backed sources before delete
      file_backed =
        from(c in KbChunk,
          where: c.kb_id == ^kb_id and not is_nil(c.source_file_id),
          select: %{source_file_id: c.source_file_id, source_path: c.source_path},
          distinct: true
        )
        |> Repo.all()

      # Delete all chunks
      from(c in KbChunk, where: c.kb_id == ^kb_id) |> Repo.delete_all()

      # Re-index file-backed sources
      total =
        file_backed
        |> Enum.reduce(0, fn %{source_file_id: fid, source_path: path}, acc ->
          case add_file_to_base(kb.id, {:file_id, fid}, %{source_path: path}) do
            {:ok, count} -> acc + count
            {:error, _} -> acc
          end
        end)

      {:ok, total}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec get_kb_by_id(String.t()) :: {:ok, KnowledgeBase.t()} | {:error, :not_found}
  defp get_kb_by_id(id) do
    case Repo.get(KnowledgeBase, id) do
      nil -> {:error, :not_found}
      kb -> {:ok, kb}
    end
  end

  @spec resolve_source({:file_id, String.t()} | {:path, String.t(), binary()}) ::
          {:ok, String.t(), String.t() | nil, String.t()} | {:error, term()}
  defp resolve_source({:file_id, file_id}) do
    # Files module stores only metadata; binary lives at workspace.root_path <> "/" <> file.path
    with {:ok, file} <- Canopy.Files.get(file_id),
         {:ok, workspace} <- Canopy.Workspaces.get_by_id(file.workspace_id) do
      full_path = Path.join(workspace.root_path, file.path)

      case File.read(full_path) do
        {:ok, binary} -> {:ok, file.path, file_id, binary}
        {:error, reason} -> {:error, {:file_read_failed, reason}}
      end
    end
  end

  defp resolve_source({:path, path, content}) when is_binary(content) do
    {:ok, path, nil, content}
  end

  @spec upsert_chunks(KnowledgeBase.t(), list(), String.t(), String.t() | nil, map()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  defp upsert_chunks(kb, chunks, source_path, source_file_id, metadata) do
    results =
      Enum.map(chunks, fn %{content: content, chunk_index: idx, token_count: tc} ->
        content_hash = sha256(content)
        {:ok, embedding} = Embedder.embed(content, kb.dimensions)

        attrs = %{
          kb_id: kb.id,
          source_path: source_path,
          source_file_id: source_file_id,
          chunk_index: idx,
          content: content,
          content_hash: content_hash,
          token_count: tc,
          embedding: embedding,
          metadata: metadata
        }

        %KbChunk{}
        |> KbChunk.changeset(attrs)
        |> Repo.insert(
          on_conflict: {:replace, [:content, :content_hash, :token_count, :embedding, :metadata]},
          conflict_target: [:kb_id, :source_path, :chunk_index]
        )
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if errors == [] do
      {:ok, length(results)}
    else
      {:error, :partial_failure}
    end
  end

  @spec sha256(String.t()) :: String.t()
  defp sha256(content) do
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end

  @spec apply_workspace_filter(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  defp apply_workspace_filter(query, nil), do: query

  defp apply_workspace_filter(query, ws),
    do: where(query, [kb], kb.workspace_slug == ^ws)

  @spec apply_archived_filter(Ecto.Query.t(), boolean()) :: Ecto.Query.t()
  defp apply_archived_filter(query, true), do: query

  defp apply_archived_filter(query, false),
    do: where(query, [kb], is_nil(kb.archived_at))
end
