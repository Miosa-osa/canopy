<script lang="ts">
/**
 * /drive/[slug] — Drive entry deep-link page.
 *
 * Looks up the entry by slug across both scopes (personal first, then
 * team) and renders the kind-appropriate detail view. Used as a stable
 * URL surface for sharing references to drive entries.
 *
 * CSS prefix: ds-
 */

import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
import { ChevronLeft } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { page } from '$app/stores';
import { driveListQuery } from '$lib/api/queries/drive.js';
import type { DriveEntry } from '$lib/domain/drive/types.js';

const slug = $derived($page.params.slug);

// We don't have an exact /drive?slug=… endpoint that respects scope
// disambiguation in Phase A, so we list and filter client-side. That's
// fine for the typical (small-ish) drive size in personal scope.
const listStore = writable(
  untrack(() => driveListQuery({ limit: 1000 }) as CreateQueryOptions<DriveEntry[]>)
);
const listQ = createQuery<DriveEntry[]>(listStore);

const entry = $derived(($listQ.data ?? []).find((e) => e.slug === slug) ?? null);
</script>

<div class="ds-page">
  <a class="ds-back" href="/drive">
    <ChevronLeft size={14} aria-hidden="true" />
    Back to Drive
  </a>

  {#if $listQ.isLoading}
    <p class="ds-empty">Loading…</p>
  {:else if !entry}
    <h1 class="ds-title">Not found</h1>
    <p class="ds-empty">No drive entry has slug <code>{slug}</code>.</p>
  {:else}
    <header class="ds-header">
      <h1 class="ds-title">{entry.name}</h1>
      <div class="ds-meta">
        <span>{entry.kind}</span>
        <span>·</span>
        <span>{entry.scope}</span>
        <span>·</span>
        <span class="ds-mono">{entry.slug}</span>
      </div>
    </header>

    <section class="ds-section">
      <h2 class="ds-section-title">Body</h2>
      <pre class="ds-code">{JSON.stringify(entry.body, null, 2)}</pre>
    </section>

    {#if entry.tags.length > 0}
      <section class="ds-section">
        <h2 class="ds-section-title">Tags</h2>
        <div class="ds-tag-list">
          {#each entry.tags as tag (tag)}
            <span class="ds-tag">{tag}</span>
          {/each}
        </div>
      </section>
    {/if}

    <section class="ds-section">
      <h2 class="ds-section-title">Details</h2>
      <dl class="ds-dl">
        <dt>id</dt>
        <dd class="ds-mono">{entry.id}</dd>
        <dt>parent</dt>
        <dd class="ds-mono">{entry.parentId ?? "(root)"}</dd>
        <dt>position</dt>
        <dd>{entry.position}</dd>
        <dt>archived</dt>
        <dd>{entry.archivedAt ?? "no"}</dd>
        <dt>created</dt>
        <dd>{entry.insertedAt}</dd>
        <dt>updated</dt>
        <dd>{entry.updatedAt}</dd>
      </dl>
    </section>
  {/if}
</div>

<style>
  .ds-page {
    padding: 1.5rem 2rem 4rem;
    max-width: 900px;
    margin: 0 auto;
    color: var(--cnp-fg);
  }

  .ds-back {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    color: var(--cnp-fg-muted);
    text-decoration: none;
    font-size: 0.85rem;
    margin-bottom: 1rem;
  }

  .ds-back:hover {
    color: var(--cnp-fg);
  }

  .ds-header {
    margin-bottom: 1.5rem;
    padding-bottom: 0.75rem;
    border-bottom: 1px solid var(--cnp-border);
  }

  .ds-title {
    font-family: var(--cnp-font-serif, Georgia, serif);
    font-size: 1.75rem;
    font-weight: 500;
    letter-spacing: -0.025em;
    margin: 0 0 0.4rem;
  }

  .ds-meta {
    display: flex;
    gap: 0.4rem;
    font-size: 0.8rem;
    color: var(--cnp-fg-muted);
  }

  .ds-section {
    margin-bottom: 1.5rem;
  }

  .ds-section-title {
    font-size: 0.85rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: var(--cnp-fg-muted);
    margin: 0 0 0.5rem;
  }

  .ds-code {
    background: var(--cnp-bg-elev);
    border: 1px solid var(--cnp-border);
    border-radius: 4px;
    padding: 0.75rem;
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.8rem;
    overflow-x: auto;
  }

  .ds-mono {
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.85rem;
  }

  .ds-empty {
    color: var(--cnp-fg-muted);
    font-size: 0.9rem;
  }

  .ds-tag-list {
    display: flex;
    gap: 0.4rem;
    flex-wrap: wrap;
  }

  .ds-tag {
    padding: 0.2rem 0.5rem;
    background: var(--cnp-bg-elev);
    border: 1px solid var(--cnp-border);
    border-radius: 4px;
    font-size: 0.75rem;
  }

  .ds-dl {
    display: grid;
    grid-template-columns: 8rem 1fr;
    gap: 0.4rem 1rem;
    margin: 0;
    font-size: 0.85rem;
  }

  .ds-dl dt {
    color: var(--cnp-fg-muted);
  }

  .ds-dl dd {
    margin: 0;
  }
</style>
