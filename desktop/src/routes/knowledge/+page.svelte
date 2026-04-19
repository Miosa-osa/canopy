<script lang="ts">
/**
 * /knowledge — Knowledge Bases list page (Track #105).
 *
 * Layout:
 *   - Header: "Knowledge Bases" + "+ New Knowledge Base" pill
 *   - Inline create form (toggleable)
 *   - Card list: name, description, chunk count, agent count, workspace chip, archive action
 *   - Empty state when no KBs exist
 *
 * CSS prefix: kb- (KnowledgeBases)
 * LOC target: ≤ 300
 */
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from "@tanstack/svelte-query";
import { BookOpen, Plus, Trash2 } from "lucide-svelte";
import { untrack } from "svelte";
import { writable } from "svelte/store";
import { goto } from "$app/navigation";
import {
  archiveBaseMutation,
  createBaseMutation,
  knowledgeBasesQuery,
} from "$lib/api/queries/knowledge.js";
import EmptyState from "$lib/design/patterns/EmptyState.svelte";
import SkeletonList from "$lib/design/patterns/SkeletonList.svelte";
import type { CreateBaseBody, KnowledgeBase } from "$lib/domain/knowledge/types.js";

const queryClient = useQueryClient();

// ── Query ─────────────────────────────────────────────────────────────────────

const listOptsStore = writable(
  untrack(() => knowledgeBasesQuery() as CreateQueryOptions<KnowledgeBase[]>),
);
const listQ = createQuery<KnowledgeBase[]>(listOptsStore);
const bases = $derived(($listQ.data ?? []) as KnowledgeBase[]);

// ── Create form state ─────────────────────────────────────────────────────────

let createOpen = $state(false);
let form = $state<CreateBaseBody>({ slug: "", name: "", description: "" });
let createError = $state<string | null>(null);

const createMut = createMutation<KnowledgeBase, Error, CreateBaseBody>(
  createBaseMutation() as CreateMutationOptions<KnowledgeBase, Error, CreateBaseBody>,
);

function handleCreate(e: Event): void {
  e.preventDefault();
  createError = null;
  $createMut.mutate(form, {
    onSuccess: (kb) => {
      createOpen = false;
      form = { slug: "", name: "", description: "" };
      queryClient.invalidateQueries({ queryKey: ["knowledge-bases"] });
      goto(`/knowledge/${kb.slug}`);
    },
    onError: (err) => {
      createError = err.message;
    },
  });
}

// ── Archive mutation ──────────────────────────────────────────────────────────

const archiveMut = createMutation<KnowledgeBase, Error, string>(
  archiveBaseMutation() as CreateMutationOptions<KnowledgeBase, Error, string>,
);

function handleArchive(slug: string): void {
  if (!confirm(`Archive knowledge base "${slug}"?`)) return;
  $archiveMut.mutate(slug, {
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["knowledge-bases"] });
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
</script>

<div class="kb-page">
  <!-- Header -->
  <header class="kb-header">
    <div class="kb-header-inner">
      <div class="kb-title-row">
        <BookOpen size={16} class="kb-icon" />
        <h1 class="kb-title">Knowledge Bases</h1>
      </div>
      <button
        class="btn-pill btn-pill-primary btn-pill-sm"
        onclick={() => (createOpen = !createOpen)}
        aria-expanded={createOpen}
      >
        <Plus size={13} />
        New Knowledge Base
      </button>
    </div>

    <!-- Inline create form -->
    {#if createOpen}
      <form class="kb-create-form glass-panel" onsubmit={handleCreate} novalidate>
        <div class="kb-form-row">
          <label class="kb-form-label" for="kb-slug">Slug</label>
          <input
            id="kb-slug"
            class="kb-form-input"
            type="text"
            placeholder="my-knowledge-base"
            bind:value={form.slug}
            required
            autocomplete="off"
          />
        </div>
        <div class="kb-form-row">
          <label class="kb-form-label" for="kb-name">Name</label>
          <input
            id="kb-name"
            class="kb-form-input"
            type="text"
            placeholder="Product Docs"
            bind:value={form.name}
            required
            autocomplete="off"
          />
        </div>
        <div class="kb-form-row">
          <label class="kb-form-label" for="kb-desc">Description</label>
          <input
            id="kb-desc"
            class="kb-form-input"
            type="text"
            placeholder="Optional description"
            bind:value={form.description}
            autocomplete="off"
          />
        </div>
        <div class="kb-form-actions">
          {#if createError}
            <span class="kb-form-error" role="alert">{createError}</span>
          {/if}
          <button
            type="button"
            class="btn-compact btn-compact-ghost"
            onclick={() => (createOpen = false)}
          >
            Cancel
          </button>
          <button
            type="submit"
            class="btn-pill btn-pill-primary btn-pill-sm"
            disabled={$createMut.isPending}
          >
            {$createMut.isPending ? "Creating…" : "Create"}
          </button>
        </div>
      </form>
    {/if}
  </header>

  <!-- Content -->
  <div class="kb-content">
    {#if $listQ.isPending}
      <div class="kb-skeleton-wrap">
        <SkeletonList count={4} />
      </div>
    {:else if $listQ.isError}
      <EmptyState
        icon={BookOpen}
        title="Failed to load knowledge bases"
        body={$listQ.error?.message ?? "Unknown error"}
      />
    {:else if bases.length === 0}
      <EmptyState
        icon={BookOpen}
        title="No knowledge bases yet"
        body="Create a knowledge base to enable RAG for your agents"
      />
    {:else}
      <ul class="kb-list" role="list">
        {#each bases as kb (kb.id)}
          <li class="kb-card">
            <button
              class="kb-card-body"
              onclick={() => goto(`/knowledge/${kb.slug}`)}
              aria-label="Open {kb.name}"
            >
              <div class="kb-card-main">
                <span class="kb-card-name">{kb.name}</span>
                {#if kb.description}
                  <span class="kb-card-desc">{kb.description}</span>
                {/if}
              </div>
              <div class="kb-card-meta">
                {#if kb.workspace_slug}
                  <span class="kb-chip">{kb.workspace_slug}</span>
                {/if}
                <span class="kb-meta-item">{kb.chunk_count ?? 0} chunks</span>
                <span class="kb-meta-item">{kb.agent_count ?? 0} agents</span>
                <span class="kb-meta-date">{formatDate(kb.inserted_at)}</span>
              </div>
            </button>
            <button
              class="kb-archive-btn btn-compact btn-compact-ghost"
              onclick={() => handleArchive(kb.slug)}
              aria-label="Archive {kb.name}"
              title="Archive"
            >
              <Trash2 size={13} />
            </button>
          </li>
        {/each}
      </ul>
    {/if}
  </div>
</div>

<style>
  /* ── Layout ── */
  .kb-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
    background: var(--bg);
  }

  .kb-header {
    flex-shrink: 0;
    border-bottom: 1px solid var(--border);
    padding: var(--space-4) var(--space-6);
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .kb-header-inner {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
  }

  .kb-title-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .kb-title {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
  }

  :global(.kb-icon) {
    color: var(--fg-muted);
  }

  /* ── Create form ── */
  .kb-create-form {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-4);
    border-radius: var(--radius-md);
  }

  .kb-form-row {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .kb-form-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
  }

  .kb-form-input {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: var(--space-2) var(--space-3);
    outline: none;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .kb-form-input:focus {
    border-color: var(--cnp-accent);
    box-shadow: 0 0 0 2px color-mix(in oklch, var(--cnp-accent) 20%, transparent 80%);
  }

  .kb-form-actions {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: var(--space-2);
  }

  .kb-form-error {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--signal-error);
    margin-right: auto;
  }

  /* ── Content ── */
  .kb-content {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-4) var(--space-6);
  }

  .kb-skeleton-wrap {
    padding-top: var(--space-2);
  }

  /* ── Card list ── */
  .kb-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .kb-card {
    display: flex;
    align-items: stretch;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    overflow: hidden;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .kb-card:hover {
    border-color: color-mix(in oklch, var(--fg) 20%, transparent 80%);
  }

  .kb-card-body {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-4);
    padding: var(--space-3) var(--space-4);
    text-align: left;
    background: transparent;
    border: none;
    cursor: pointer;
    min-width: 0;
  }

  .kb-card-main {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }

  .kb-card-name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .kb-card-desc {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .kb-card-meta {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    flex-shrink: 0;
  }

  .kb-chip {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--cnp-accent);
    background: color-mix(in oklch, var(--cnp-accent) 10%, transparent 90%);
    border: 1px solid color-mix(in oklch, var(--cnp-accent) 30%, transparent 70%);
    border-radius: var(--radius-sm);
    padding: 1px 6px;
    white-space: nowrap;
  }

  .kb-meta-item {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    white-space: nowrap;
  }

  .kb-meta-date {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    white-space: nowrap;
  }

  .kb-archive-btn {
    flex-shrink: 0;
    padding: 0 var(--space-3);
    border-radius: 0;
    border-left: 1px solid var(--border);
    color: var(--fg-subtle);
  }

  .kb-archive-btn:hover {
    color: var(--signal-error);
    background: color-mix(in oklch, var(--signal-error) 8%, transparent 92%);
  }
</style>
