<script lang="ts">
/**
 * KnowledgeBasesPanel — list KBs with Assign/Unassign per KB.
 * Uses existing assignAgent / unassignAgent endpoints via knowledge.ts.
 * CSS prefix: kbp- (KnowledgeBasesPanel)
 */
import type { KnowledgeBase } from '$lib/domain/knowledge/types.js';

interface Props {
  agentSlug: string;
  bases: KnowledgeBase[];
  isLoading: boolean;
  assignedSlugs: string[];
  onAssign: (kbSlug: string) => void;
  onUnassign: (kbSlug: string) => void;
  isPending: boolean;
}

let { agentSlug, bases, isLoading, assignedSlugs, onAssign, onUnassign, isPending }: Props =
  $props();

// agentSlug is the display context identifier — referenced in the template aria-label below
</script>

<div class="kbp-root" aria-label="Knowledge bases for agent {agentSlug}">
  {#if isLoading}
    <p class="kbp-hint">Loading knowledge bases…</p>
  {:else if bases.length === 0}
    <p class="kbp-hint">No knowledge bases found. Create one in Settings → Knowledge.</p>
  {:else}
    <div class="kbp-list" role="list">
      {#each bases as kb (kb.slug)}
        {@const assigned = assignedSlugs.includes(kb.slug)}
        <div class="kbp-row" role="listitem">
          <div class="kbp-info">
            <span class="kbp-name">{kb.name}</span>
            {#if kb.description}
              <span class="kbp-desc">{kb.description}</span>
            {/if}
            <div class="kbp-meta">
              <span class="kbp-meta-item">{kb.chunk_count ?? 0} chunks</span>
              <span class="kbp-meta-sep" aria-hidden="true">·</span>
              <span class="kbp-meta-item">{kb.embedding_model}</span>
            </div>
          </div>
          <button
            class="btn-pill btn-pill-sm"
            class:btn-pill-secondary={assigned}
            class:btn-pill-ghost={!assigned}
            onclick={() => (assigned ? onUnassign(kb.slug) : onAssign(kb.slug))}
            disabled={isPending}
            aria-label="{assigned ? 'Unassign' : 'Assign'} knowledge base {kb.name}"
            aria-pressed={assigned}
          >
            {assigned ? 'Assigned' : 'Assign'}
          </button>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .kbp-root {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-6);
  }

  .kbp-hint {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
  }

  .kbp-list {
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .kbp-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-4);
    padding: var(--space-3) var(--space-2);
    border-radius: var(--radius-sm);
    transition: background 0.1s;
  }

  .kbp-row:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }

  .kbp-info {
    display: flex;
    flex-direction: column;
    gap: 2px;
    flex: 1;
    min-width: 0;
  }

  .kbp-name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
  }

  .kbp-desc {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    line-height: 1.5;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .kbp-meta {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    margin-top: 2px;
  }

  .kbp-meta-item {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .kbp-meta-sep {
    color: var(--border);
  }

  /* Override pill ghost for "assign" state */
  :global(.btn-pill-ghost) {
    background: transparent;
    border: 1px solid var(--border);
    color: var(--fg-muted);
  }

  :global(.btn-pill-ghost:hover) {
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    color: var(--fg);
  }
</style>
