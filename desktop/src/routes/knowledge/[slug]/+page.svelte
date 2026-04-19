<script lang="ts">
/**
 * /knowledge/[slug] — Knowledge Base detail page (Track #105).
 *
 * Tabs: Files | Chunks | Assigned Agents | Search
 *
 * CSS prefix: kd- (KnowledgeDetail)
 * LOC target: ≤ 350
 */
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from "@tanstack/svelte-query";
import { ArrowLeft, BookOpen, RefreshCw } from "lucide-svelte";
import { untrack } from "svelte";
import { writable } from "svelte/store";
import { goto } from "$app/navigation";
import { page } from "$app/stores";
import {
  addFileMutation,
  assignAgentMutation,
  kbChunksQuery,
  knowledgeBaseQuery,
  rebuildIndexMutation,
  searchMutation,
  unassignAgentMutation,
} from "$lib/api/queries/knowledge.js";
import EmptyState from "$lib/design/patterns/EmptyState.svelte";
import SkeletonList from "$lib/design/patterns/SkeletonList.svelte";
import type {
  AddFileBody,
  IndexResult,
  KbAssignment,
  KbChunk,
  KbChunkListResponse,
  KnowledgeBase,
  SearchResponse,
} from "$lib/domain/knowledge/types.js";

const queryClient = useQueryClient();
// SvelteKit guarantees params.slug is defined for [slug] routes.
const slug = $derived($page.params.slug!);

// ── KB detail query ───────────────────────────────────────────────────────────

const detailOptsStore = writable(
  untrack(() => knowledgeBaseQuery(slug) as CreateQueryOptions<KnowledgeBase>),
);
$effect(() => {
  detailOptsStore.set(knowledgeBaseQuery(slug) as CreateQueryOptions<KnowledgeBase>);
});
const detailQ = createQuery<KnowledgeBase>(detailOptsStore);
const kb = $derived($detailQ.data as KnowledgeBase | undefined);

// ── Chunks query (paginated) ──────────────────────────────────────────────────

let chunkOffset = $state(0);
const chunkLimit = 50;

const chunksOptsStore = writable(
  untrack(
    () =>
      kbChunksQuery(slug, chunkLimit, chunkOffset) as CreateQueryOptions<KbChunkListResponse>,
  ),
);
$effect(() => {
  chunksOptsStore.set(
    kbChunksQuery(slug, chunkLimit, chunkOffset) as CreateQueryOptions<KbChunkListResponse>,
  );
});
const chunksQ = createQuery<KbChunkListResponse>(chunksOptsStore);
const chunks = $derived(($chunksQ.data?.data ?? []) as KbChunk[]);

// ── Tab state ─────────────────────────────────────────────────────────────────

type Tab = "files" | "chunks" | "agents" | "search";
let activeTab = $state<Tab>("files");

// ── Add file (file_id JSON form) ──────────────────────────────────────────────

let addFileId = $state("");
let addFileError = $state<string | null>(null);

const addFileMut = createMutation<IndexResult, Error, { slug: string; body: AddFileBody }>(
  addFileMutation() as CreateMutationOptions<IndexResult, Error, { slug: string; body: AddFileBody }>,
);

function handleAddFile(e: Event): void {
  e.preventDefault();
  if (!addFileId.trim()) return;
  addFileError = null;
  $addFileMut.mutate(
    { slug, body: { file_id: addFileId.trim() } },
    {
      onSuccess: () => {
        addFileId = "";
        queryClient.invalidateQueries({ queryKey: ["knowledge-bases", slug] });
        queryClient.invalidateQueries({ queryKey: ["knowledge-bases", slug, "chunks"] });
        activeTab = "chunks";
      },
      onError: (err) => {
        addFileError = err.message;
      },
    },
  );
}

// ── Assign agent ──────────────────────────────────────────────────────────────

let assignSlug = $state("");
let assignError = $state<string | null>(null);
let assignments = $state<KbAssignment[]>([]);

const assignMut = createMutation<KbAssignment, Error, { slug: string; agentSlug: string }>(
  assignAgentMutation() as CreateMutationOptions<
    KbAssignment,
    Error,
    { slug: string; agentSlug: string }
  >,
);

const unassignMut = createMutation<void, Error, { slug: string; agentSlug: string }>(
  unassignAgentMutation() as CreateMutationOptions<
    void,
    Error,
    { slug: string; agentSlug: string }
  >,
);

function handleAssign(e: Event): void {
  e.preventDefault();
  if (!assignSlug.trim()) return;
  assignError = null;
  $assignMut.mutate(
    { slug, agentSlug: assignSlug.trim() },
    {
      onSuccess: (a) => {
        assignments = [...assignments, a];
        assignSlug = "";
        queryClient.invalidateQueries({ queryKey: ["knowledge-bases", slug] });
      },
      onError: (err) => {
        assignError = err.message;
      },
    },
  );
}

function handleUnassign(agentSlug: string): void {
  $unassignMut.mutate(
    { slug, agentSlug },
    {
      onSuccess: () => {
        assignments = assignments.filter((a) => a.agent_slug !== agentSlug);
        queryClient.invalidateQueries({ queryKey: ["knowledge-bases", slug] });
      },
    },
  );
}

// ── Search tab ────────────────────────────────────────────────────────────────

let searchQuery = $state("");
let searchResults = $state<KbChunk[]>([]);
let searchNote = $state("");
let searchError = $state<string | null>(null);

const searchMut = createMutation<SearchResponse, Error, { slug: string; body: { query: string; limit: number } }>(
  searchMutation() as CreateMutationOptions<
    SearchResponse,
    Error,
    { slug: string; body: { query: string; limit: number } }
  >,
);

function handleSearch(e: Event): void {
  e.preventDefault();
  if (!searchQuery.trim()) return;
  searchError = null;
  $searchMut.mutate(
    { slug, body: { query: searchQuery, limit: 5 } },
    {
      onSuccess: (res) => {
        searchResults = res.data;
        searchNote = res.note;
      },
      onError: (err) => {
        searchError = err.message;
      },
    },
  );
}

// ── Rebuild ───────────────────────────────────────────────────────────────────

const rebuildMut = createMutation<IndexResult, Error, string>(
  rebuildIndexMutation() as CreateMutationOptions<IndexResult, Error, string>,
);

function handleRebuild(): void {
  if (!confirm("Rebuild index? All chunks will be deleted and re-indexed from Files sources."))
    return;
  $rebuildMut.mutate(slug, {
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["knowledge-bases", slug] });
      queryClient.invalidateQueries({ queryKey: ["knowledge-bases", slug, "chunks"] });
    },
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

function preview(content: string, max = 200): string {
  return content.length <= max ? content : content.slice(0, max) + "…";
}
</script>

<div class="kd-page">
  <!-- Breadcrumb + header -->
  <header class="kd-header">
    <div class="kd-breadcrumb">
      <button class="kd-back btn-compact btn-compact-ghost" onclick={() => goto("/knowledge")}>
        <ArrowLeft size={13} />
        Knowledge Bases
      </button>
    </div>

    {#if $detailQ.isPending}
      <div class="kd-title-row">
        <span class="kd-title-skeleton"></span>
      </div>
    {:else if kb}
      <div class="kd-title-row">
        <BookOpen size={15} class="kd-icon" />
        <div class="kd-title-group">
          <h1 class="kd-title">{kb.name}</h1>
          {#if kb.description}
            <p class="kd-description">{kb.description}</p>
          {/if}
        </div>
        <div class="kd-header-meta">
          {#if kb.workspace_slug}
            <span class="kd-chip">{kb.workspace_slug}</span>
          {/if}
          <span class="kd-stat">{kb.chunk_count ?? 0} chunks</span>
          <span class="kd-stat">{kb.agent_count ?? 0} agents</span>
          <button
            class="btn-compact btn-compact-ghost"
            onclick={handleRebuild}
            disabled={$rebuildMut.isPending}
            title="Rebuild index"
            aria-label="Rebuild index"
          >
            <RefreshCw size={13} class={$rebuildMut.isPending ? "kd-spin" : ""} />
          </button>
        </div>
      </div>
    {/if}

    <!-- Tabs -->
    <nav class="kd-tabs" role="tablist" aria-label="Knowledge base sections">
      {#each (["files", "chunks", "agents", "search"] as const) as tab}
        <button
          role="tab"
          aria-selected={activeTab === tab}
          class="kd-tab"
          class:kd-tab--active={activeTab === tab}
          onclick={() => (activeTab = tab)}
        >
          {tab === "files" ? "Files" : tab === "chunks" ? "Chunks" : tab === "agents" ? "Assigned Agents" : "Search"}
        </button>
      {/each}
    </nav>
  </header>

  <!-- Tab content -->
  <div class="kd-content">

    <!-- FILES TAB -->
    {#if activeTab === "files"}
      <div class="kd-section">
        <h2 class="kd-section-title">Add File by ID</h2>
        <p class="kd-section-hint">
          Enter a Files module file ID to chunk and embed its content into this knowledge base.
        </p>
        <form class="kd-inline-form" onsubmit={handleAddFile} novalidate>
          <input
            class="kd-input"
            type="text"
            placeholder="file UUID from /files"
            bind:value={addFileId}
            autocomplete="off"
          />
          <button
            type="submit"
            class="btn-pill btn-pill-primary btn-pill-sm"
            disabled={$addFileMut.isPending}
          >
            {$addFileMut.isPending ? "Indexing…" : "Add File"}
          </button>
        </form>
        {#if addFileError}
          <span class="kd-error" role="alert">{addFileError}</span>
        {/if}
        {#if $addFileMut.isSuccess && $addFileMut.data}
          <span class="kd-success">
            Indexed {$addFileMut.data.indexed_chunks ?? 0} chunks.
          </span>
        {/if}
      </div>
    {/if}

    <!-- CHUNKS TAB -->
    {#if activeTab === "chunks"}
      {#if $chunksQ.isPending}
        <div class="kd-skeleton-wrap"><SkeletonList count={5} /></div>
      {:else if chunks.length === 0}
        <EmptyState icon={BookOpen} title="No chunks yet" body="Add a file to index content." />
      {:else}
        <div class="kd-table-wrap">
          <table class="kd-table">
            <thead>
              <tr>
                <th class="kd-th">#</th>
                <th class="kd-th">Source</th>
                <th class="kd-th kd-th-tokens">Tokens</th>
                <th class="kd-th kd-th-preview">Content Preview</th>
                <th class="kd-th">Metadata</th>
              </tr>
            </thead>
            <tbody>
              {#each chunks as chunk (chunk.id)}
                <tr class="kd-row">
                  <td class="kd-td kd-td-idx">{chunk.chunk_index}</td>
                  <td class="kd-td kd-td-source">
                    <span class="kd-mono">{chunk.source_path}</span>
                  </td>
                  <td class="kd-td kd-td-tokens">{chunk.token_count}</td>
                  <td class="kd-td kd-td-preview">{preview(chunk.content)}</td>
                  <td class="kd-td kd-td-meta">
                    {#if Object.keys(chunk.metadata).length > 0}
                      <span class="kd-mono kd-meta-keys">
                        {Object.keys(chunk.metadata).join(", ")}
                      </span>
                    {:else}
                      <span class="kd-subtle">—</span>
                    {/if}
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
        <div class="kd-pagination">
          <button
            class="btn-compact btn-compact-ghost"
            disabled={chunkOffset === 0}
            onclick={() => (chunkOffset = Math.max(0, chunkOffset - chunkLimit))}
          >
            Previous
          </button>
          <span class="kd-page-info">Offset {chunkOffset}</span>
          <button
            class="btn-compact btn-compact-ghost"
            disabled={chunks.length < chunkLimit}
            onclick={() => (chunkOffset = chunkOffset + chunkLimit)}
          >
            Next
          </button>
        </div>
      {/if}
    {/if}

    <!-- AGENTS TAB -->
    {#if activeTab === "agents"}
      <div class="kd-section">
        <h2 class="kd-section-title">Assign Agent</h2>
        <form class="kd-inline-form" onsubmit={handleAssign} novalidate>
          <input
            class="kd-input"
            type="text"
            placeholder="agent-slug"
            bind:value={assignSlug}
            autocomplete="off"
          />
          <button
            type="submit"
            class="btn-pill btn-pill-primary btn-pill-sm"
            disabled={$assignMut.isPending}
          >
            {$assignMut.isPending ? "Assigning…" : "Assign"}
          </button>
        </form>
        {#if assignError}
          <span class="kd-error" role="alert">{assignError}</span>
        {/if}
        {#if assignments.length > 0}
          <ul class="kd-agent-list" role="list">
            {#each assignments as a (a.id)}
              <li class="kd-agent-row">
                <span class="kd-mono">{a.agent_slug}</span>
                <span class="kd-subtle">priority {a.priority}</span>
                <button
                  class="btn-compact btn-compact-ghost kd-remove-btn"
                  onclick={() => handleUnassign(a.agent_slug)}
                  aria-label="Remove {a.agent_slug}"
                >
                  Remove
                </button>
              </li>
            {/each}
          </ul>
        {:else}
          <p class="kd-empty-hint">No agents assigned yet.</p>
        {/if}
      </div>
    {/if}

    <!-- SEARCH TAB -->
    {#if activeTab === "search"}
      <div class="kd-section">
        <h2 class="kd-section-title">Search</h2>
        <p class="kd-section-hint">
          Preview — relevance ranking is insertion-order until a real embedding provider is wired.
        </p>
        <form class="kd-inline-form" onsubmit={handleSearch} novalidate>
          <input
            class="kd-input kd-input-wide"
            type="text"
            placeholder="Enter a search query…"
            bind:value={searchQuery}
            autocomplete="off"
          />
          <button
            type="submit"
            class="btn-pill btn-pill-primary btn-pill-sm"
            disabled={$searchMut.isPending}
          >
            {$searchMut.isPending ? "Searching…" : "Search"}
          </button>
        </form>
        {#if searchError}
          <span class="kd-error" role="alert">{searchError}</span>
        {/if}
        {#if searchNote}
          <p class="kd-note">{searchNote}</p>
        {/if}
        {#if searchResults.length > 0}
          <ul class="kd-result-list" role="list">
            {#each searchResults as chunk, i (chunk.id)}
              <li class="kd-result">
                <div class="kd-result-header">
                  <span class="kd-result-rank">#{i + 1}</span>
                  <span class="kd-mono">{chunk.source_path}</span>
                  <span class="kd-subtle">chunk {chunk.chunk_index}</span>
                  <span class="kd-subtle">{chunk.token_count} tokens</span>
                </div>
                <p class="kd-result-content">{preview(chunk.content, 400)}</p>
              </li>
            {/each}
          </ul>
        {/if}
      </div>
    {/if}
  </div>
</div>

<style>
  /* ── Layout ── */
  .kd-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
    background: var(--bg);
  }

  .kd-header {
    flex-shrink: 0;
    border-bottom: 1px solid var(--border);
    padding: var(--space-3) var(--space-6) 0;
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .kd-breadcrumb {
    padding-bottom: var(--space-1);
  }

  .kd-back {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    display: flex;
    align-items: center;
    gap: var(--space-1);
  }

  .kd-title-row {
    display: flex;
    align-items: flex-start;
    gap: var(--space-2);
  }

  :global(.kd-icon) {
    color: var(--fg-muted);
    margin-top: 2px;
    flex-shrink: 0;
  }

  .kd-title-group {
    flex: 1;
    min-width: 0;
  }

  .kd-title {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
  }

  .kd-description {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    margin: 2px 0 0;
  }

  .kd-title-skeleton {
    display: block;
    width: 200px;
    height: 18px;
    background: var(--bg-inset);
    border-radius: var(--radius-sm);
    animation: pulse 1.2s ease-in-out infinite;
  }

  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.4; }
  }

  .kd-header-meta {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    margin-left: auto;
    flex-shrink: 0;
  }

  .kd-chip {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--cnp-accent);
    background: color-mix(in oklch, var(--cnp-accent) 10%, transparent 90%);
    border: 1px solid color-mix(in oklch, var(--cnp-accent) 30%, transparent 70%);
    border-radius: var(--radius-sm);
    padding: 1px 6px;
  }

  .kd-stat {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  :global(.kd-spin) {
    animation: spin 1s linear infinite;
  }
  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  /* ── Tabs ── */
  .kd-tabs {
    display: flex;
    gap: 0;
    margin-top: var(--space-1);
  }

  .kd-tab {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    padding: var(--space-2) var(--space-3);
    background: transparent;
    border: none;
    border-bottom: 2px solid transparent;
    cursor: pointer;
    transition:
      color var(--dur-instant) var(--ease-out),
      border-color var(--dur-instant) var(--ease-out);
    margin-bottom: -1px;
  }

  .kd-tab:hover {
    color: var(--fg);
  }

  .kd-tab--active {
    color: var(--fg);
    border-bottom-color: var(--cnp-accent);
  }

  /* ── Content ── */
  .kd-content {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-5) var(--space-6);
  }

  .kd-skeleton-wrap {
    padding-top: var(--space-2);
  }

  /* ── Sections (Files / Agents / Search) ── */
  .kd-section {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    max-width: 560px;
  }

  .kd-section-title {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin: 0;
  }

  .kd-section-hint {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    margin: 0;
    line-height: 1.5;
  }

  .kd-inline-form {
    display: flex;
    gap: var(--space-2);
    align-items: center;
  }

  .kd-input {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: var(--space-2) var(--space-3);
    outline: none;
    flex: 1;
    min-width: 0;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .kd-input-wide {
    max-width: 360px;
  }

  .kd-input:focus {
    border-color: var(--cnp-accent);
    box-shadow: 0 0 0 2px color-mix(in oklch, var(--cnp-accent) 20%, transparent 80%);
  }

  .kd-error {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--signal-error);
  }

  .kd-success {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--signal-success, oklch(64% 0.18 145));
  }

  .kd-note {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    background: var(--bg-inset);
    border-left: 2px solid var(--border);
    padding: var(--space-2) var(--space-3);
    margin: 0;
    line-height: 1.5;
    border-radius: 0 var(--radius-sm) var(--radius-sm) 0;
  }

  .kd-empty-hint {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    margin: 0;
  }

  /* ── Agent list ── */
  .kd-agent-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .kd-agent-row {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-2) var(--space-3);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
  }

  .kd-remove-btn {
    margin-left: auto;
    color: var(--fg-subtle);
    font-size: var(--text-xs);
  }

  .kd-remove-btn:hover {
    color: var(--signal-error);
  }

  /* ── Chunks table ── */
  .kd-table-wrap {
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    overflow: auto;
  }

  .kd-table {
    width: 100%;
    border-collapse: collapse;
  }

  .kd-th {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-muted);
    padding: var(--space-2) var(--space-3);
    text-align: left;
    background: var(--bg-inset);
    border-bottom: 1px solid var(--border);
    white-space: nowrap;
  }

  .kd-th-tokens,
  .kd-th-preview {
    min-width: 80px;
  }

  .kd-th-preview {
    min-width: 240px;
  }

  .kd-row:hover {
    background: color-mix(in oklch, var(--fg) 3%, transparent 97%);
  }

  .kd-td {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    padding: var(--space-2) var(--space-3);
    border-bottom: 1px solid var(--border);
    vertical-align: top;
  }

  .kd-td-idx {
    color: var(--fg-subtle);
    width: 36px;
  }

  .kd-td-source {
    max-width: 160px;
  }

  .kd-td-tokens {
    text-align: right;
    width: 64px;
  }

  .kd-td-preview {
    max-width: 360px;
    color: var(--fg);
    line-height: 1.5;
  }

  .kd-td-meta {
    max-width: 120px;
  }

  /* ── Pagination ── */
  .kd-pagination {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: var(--space-3);
    padding: var(--space-3) 0;
  }

  .kd-page-info {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  /* ── Search results ── */
  .kd-result-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .kd-result {
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-3) var(--space-4);
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .kd-result-header {
    display: flex;
    align-items: center;
    gap: var(--space-3);
  }

  .kd-result-rank {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--cnp-accent);
    font-weight: 600;
  }

  .kd-result-content {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    margin: 0;
    line-height: 1.6;
    white-space: pre-wrap;
    word-break: break-word;
  }

  /* ── Shared utilities ── */
  .kd-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  .kd-meta-keys {
    color: var(--fg-subtle);
  }

  .kd-subtle {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }
</style>
