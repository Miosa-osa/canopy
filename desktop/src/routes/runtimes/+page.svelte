<script lang="ts">
/**
 * /runtimes — Runtime Dashboard.
 *
 * Renders three sections:
 *   1. CLI Runtimes — up to 9 RuntimeCards from the runtimesQuery()
 *   2. API Runtimes  — placeholder "+ Add"
 *   3. MCP Servers   — placeholder "+ Add"
 *
 * Loading state: 9 skeleton card placeholders.
 * Error state: Alert with retry.
 *
 * TanStack QueryClientProvider assumed from root layout (+layout.svelte).
 */
// TODO: QueryClient setup assumed from layout
import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
import { runtimesQuery } from '$lib/api/queries/runtimes.js';
import Alert from '$lib/design/foundation/alert/Alert.svelte';
import Skeleton from '$lib/design/foundation/skeleton/Skeleton.svelte';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import RuntimeCard from '$lib/design/patterns/RuntimeCard.svelte';
import type { Runtime } from '$lib/domain/runtimes/types.js';

const query = createQuery<Runtime[]>(runtimesQuery() as CreateQueryOptions<Runtime[]>);

/** Render 9 skeleton cards while loading. */
const skeletonRange = Array.from({ length: 9 }, (_, i) => i);
</script>

<div class="rd-page">
  <header class="rd-header">
    <h1 class="rd-title">Runtimes</h1>
    <p class="rd-subtitle">Manage AI adapter runtimes — CLI, API, and MCP server connections.</p>
  </header>

  <!-- ── CLI Runtimes ─────────────────────────────────────────────────── -->
  <section class="rd-section" aria-labelledby="rd-cli-heading">
    <div class="rd-section-header">
      <h2 class="rd-section-title" id="rd-cli-heading">CLI Runtimes</h2>
    </div>

    {#if $query.isError}
      <Alert variant="error" title="Failed to load runtimes" dismissible>
        {($query.error as Error).message}
        <button
          class="btn-pill btn-pill-sm btn-pill-primary"
          onclick={() => $query.refetch()}
          style="margin-top: 8px;"
        >
          Retry
        </button>
      </Alert>
    {:else}
      <div class="rd-grid" aria-busy={$query.isLoading}>
        {#if $query.isLoading}
          {#each skeletonRange as i (i)}
            <div class="rd-skeleton-card glass-card" aria-hidden="true">
              <div class="rd-sk-header">
                <Skeleton class="rd-sk-icon" />
                <div class="rd-sk-meta">
                  <Skeleton class="rd-sk-name" />
                  <Skeleton class="rd-sk-ver" />
                </div>
              </div>
              <div class="rd-sk-divider"></div>
              <div class="rd-sk-pills">
                <Skeleton class="rd-sk-pill" />
                <Skeleton class="rd-sk-pill" />
              </div>
              <div class="rd-sk-divider"></div>
              <Skeleton class="rd-sk-cta" />
            </div>
          {/each}
        {:else if $query.data && $query.data.length > 0}
          {#each $query.data.slice(0, 9) as runtime (runtime.type)}
            <RuntimeCard {runtime} />
          {/each}
        {:else}
          <div class="rd-grid-empty">
            <EmptyState
              title="No runtimes configured"
              body="Install a CLI adapter such as claude, openai, or ollama to get started."
            />
          </div>
        {/if}
      </div>
    {/if}
  </section>

  <!-- ── API Runtimes ─────────────────────────────────────────────────── -->
  <section class="rd-section" aria-labelledby="rd-api-heading">
    <div class="rd-section-header">
      <h2 class="rd-section-title" id="rd-api-heading">API Runtimes</h2>
      <button class="btn-pill btn-pill-sm btn-pill-secondary rd-add-btn" disabled>
        + Add
      </button>
    </div>
    <div class="rd-placeholder glass-panel">
      <span class="rd-placeholder-text">API runtime connections — available in Week 2.</span>
    </div>
  </section>

  <!-- ── MCP Servers ──────────────────────────────────────────────────── -->
  <section class="rd-section" aria-labelledby="rd-mcp-heading">
    <div class="rd-section-header">
      <h2 class="rd-section-title" id="rd-mcp-heading">MCP Servers</h2>
      <button class="btn-pill btn-pill-sm btn-pill-secondary rd-add-btn" disabled>
        + Add
      </button>
    </div>
    <div class="rd-placeholder glass-panel">
      <span class="rd-placeholder-text">Model Context Protocol servers — available in Week 2.</span>
    </div>
  </section>
</div>

<style>
  .rd-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-6);
    padding: var(--space-6) var(--space-6);
    overflow-y: auto;
    height: 100%;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .rd-header {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .rd-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    letter-spacing: var(--tracking-2xl);
    line-height: var(--lh-2xl);
  }

  .rd-subtitle {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    line-height: 1.5;
  }

  .rd-section {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .rd-section-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .rd-section-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-lg);
    font-weight: 600;
    color: var(--fg);
    letter-spacing: var(--tracking-lg);
  }

  .rd-add-btn {
    opacity: 0.5;
  }

  .rd-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: var(--space-3);
  }

  .rd-grid-empty {
    grid-column: 1 / -1;
  }

  /* Skeleton cards */
  .rd-skeleton-card {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-4);
  }

  .rd-sk-header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .rd-sk-meta {
    display: flex;
    flex-direction: column;
    flex: 1;
    gap: 4px;
  }

  :global(.rd-sk-icon) {
    width: 28px !important;
    height: 28px !important;
    border-radius: 6px !important;
    flex-shrink: 0;
  }

  :global(.rd-sk-name) {
    height: 13px !important;
    width: 80% !important;
    border-radius: 4px !important;
  }

  :global(.rd-sk-ver) {
    height: 10px !important;
    width: 50% !important;
    border-radius: 4px !important;
  }

  .rd-sk-divider {
    height: 1px;
    background: var(--border);
    opacity: 0.5;
  }

  .rd-sk-pills {
    display: flex;
    gap: var(--space-1);
  }

  :global(.rd-sk-pill) {
    height: 20px !important;
    width: 60px !important;
    border-radius: 9999px !important;
  }

  :global(.rd-sk-cta) {
    height: 28px !important;
    width: 80px !important;
    border-radius: 9999px !important;
  }

  .rd-placeholder {
    padding: var(--space-5) var(--space-4);
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .rd-placeholder-text {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    font-style: italic;
  }
</style>
