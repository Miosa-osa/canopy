<script lang="ts">
/**
 * /runtimes — Runtime Dashboard.
 *
 * Groups runtimes into three categories (Agent Runtimes / API Providers /
 * IDE Extensions) and three status buckets (Installed / API Keys Needed /
 * Not Installed). Deduplicates "-local" aliases using the same key strategy
 * as OnboardingWizard/RuntimeStep: lowercase + strip non-alphanumeric.
 *
 * CSS prefix: rd-
 */
import { type CreateQueryOptions, createQuery, useQueryClient } from '@tanstack/svelte-query';
import { goto } from '$app/navigation';
import { runtimesQuery } from '$lib/api/queries/runtimes.js';
import Skeleton from '$lib/design/foundation/skeleton/Skeleton.svelte';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import RuntimeCard from '$lib/design/patterns/RuntimeCard.svelte';
import type { ViewState } from '$lib/design/primitives/ViewPicker.svelte';
import ViewPicker from '$lib/design/primitives/ViewPicker.svelte';
import type { Runtime } from '$lib/domain/runtimes/types.js';
import { useListKeyboard } from '$lib/utils/useListKeyboard.svelte.js';

const queryClient = useQueryClient();
const query = createQuery<Runtime[]>(runtimesQuery() as CreateQueryOptions<Runtime[]>);

const rawRuntimes = $derived(($query.data ?? []) as Runtime[]);

// ─── Dedup ───────────────────────────────────────────────────────────────────
// Key = name lowercased with non-alphanumeric stripped  (same as RuntimeStep).
// Keep the `installed` variant when there's a conflict; prefer shorter type
// name (without "-local") when install status is equal.
function dedup(runtimes: Runtime[]): Runtime[] {
  const seen = new Map<string, Runtime>();
  for (const rt of runtimes) {
    const key = rt.name.toLowerCase().replace(/[^a-z0-9]/g, '');
    const existing = seen.get(key);
    if (!existing) {
      seen.set(key, rt);
    } else {
      const rtInstalled = rt.status === 'installed';
      const exInstalled = existing.status === 'installed';
      if (rtInstalled && !exInstalled) {
        seen.set(key, rt);
      } else if (!rtInstalled && !exInstalled) {
        // Both not installed — prefer shorter type (drops "-local" alias)
        if (rt.type.length < existing.type.length) seen.set(key, rt);
      }
      // existing is installed and rt is not → keep existing (no change)
    }
  }
  return [...seen.values()];
}

// ─── Category ────────────────────────────────────────────────────────────────
type Category = 'cli' | 'api' | 'ide';

function categorize(rt: Runtime): Category {
  const t = rt.type.toLowerCase();
  if (
    t.endsWith('-api') ||
    t === 'anthropic-api' ||
    t === 'openai-api' ||
    t === 'groq-api' ||
    t === 'mistral-api'
  )
    return 'api';
  if (t === 'cline' || t === 'continue-cli' || t.startsWith('cursor-')) return 'ide';
  return 'cli';
}

const CATEGORY_ORDER: Category[] = ['cli', 'api', 'ide'];

const CATEGORY_LABELS: Record<Category, string> = {
  cli: 'Agent Runtimes',
  api: 'API Providers',
  ide: 'IDE Extensions',
};

// ─── Status label ─────────────────────────────────────────────────────────────
// CLI/IDE tools: installed → "Ready to use" | not installed → "Install to use"
// API providers: always "API key needed" regardless of install status
function statusLabel(rt: Runtime, cat: Category): string {
  if (cat === 'api') return 'API key needed';
  return rt.status === 'installed' ? 'Ready to use' : 'Install to use';
}

// ─── Grouped derivation ───────────────────────────────────────────────────────
interface GroupEntry {
  runtime: Runtime;
  category: Category;
  label: string;
}

const grouped = $derived.by(() => {
  const deduped = dedup(rawRuntimes);
  const map = new Map<Category, GroupEntry[]>();
  for (const cat of CATEGORY_ORDER) map.set(cat, []);

  for (const rt of deduped) {
    const cat = categorize(rt);
    map.get(cat)!.push({ runtime: rt, category: cat, label: statusLabel(rt, cat) });
  }

  // Sort: installed first, then alphabetical by name
  for (const [cat, entries] of map) {
    map.set(
      cat,
      entries.sort((a, b) => {
        const aInst = a.runtime.status === 'installed' ? 0 : 1;
        const bInst = b.runtime.status === 'installed' ? 0 : 1;
        if (aInst !== bInst) return aInst - bInst;
        return a.runtime.name.localeCompare(b.runtime.name);
      })
    );
  }

  return map;
});

const runtimes = $derived(dedup(rawRuntimes));

const kb = useListKeyboard({
  items: () => runtimes,
  onSelect: (runtime) => goto(`/runtimes/${runtime.type}`),
  onRefresh: () => {
    queryClient.invalidateQueries({ queryKey: ['runtimes'] });
  },
});

/** Render 6 skeleton cards while loading. */
const skeletonRange = Array.from({ length: 6 }, (_, i) => i);

let view = $state<ViewState>({ layout: 'grid', density: 'comfortable', sort: 'name_asc' });
</script>

<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
<div
  class="rd-page"
  role="region"
  aria-label="Runtimes list"
  onkeydown={kb.handleKeydown}
>
  <header class="rd-header">
    <div style="display:flex;align-items:center;justify-content:space-between;gap:var(--space-2)">
      <h1 class="rd-title">Runtimes</h1>
      <ViewPicker routeSlug="runtimes" bind:view />
    </div>
    <p class="rd-subtitle">
      AI CLI adapters and API providers detected on this machine.
    </p>
  </header>

  {#if $query.isError}
    <EmptyState
      title="Couldn't load runtimes"
      body={($query.error as Error).message || 'Check your connection and try again.'}
      action="Retry"
      onAction={() => $query.refetch()}
    />
  {:else if $query.isLoading}
    <div class="rd-grid" aria-busy="true">
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
    </div>
  {:else if runtimes.length === 0}
    <EmptyState
      title="No runtimes detected"
      body="Install a CLI adapter such as claude, codex, or ollama. Canopy auto-detects them on next refresh."
    />
  {:else}
    {#each CATEGORY_ORDER as cat (cat)}
      {@const entries = grouped.get(cat) ?? []}
      {#if entries.length > 0}
        {@const installedCount = entries.filter(e => e.runtime.status === 'installed').length}
        <section class="rd-section" aria-labelledby="rd-{cat}-heading">
          <div class="rd-section-header">
            <h2 class="rd-section-title" id="rd-{cat}-heading">
              {CATEGORY_LABELS[cat]}
            </h2>
            <span class="rd-count">{entries.length}</span>
            {#if installedCount > 0}
              <span class="rd-installed-badge">{installedCount} installed</span>
            {/if}
          </div>
          <div class="rd-grid">
            {#each entries as { runtime } (runtime.type)}
              <RuntimeCard {runtime} />
            {/each}
          </div>
        </section>
      {/if}
    {/each}
  {/if}
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
    align-items: baseline;
    gap: var(--space-2);
  }

  .rd-section-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg-muted);
    letter-spacing: 0.04em;
    text-transform: uppercase;
  }

  .rd-count {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  .rd-installed-badge {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--signal-success, #22c55e);
    background: color-mix(in oklch, var(--signal-success, #22c55e) 12%, transparent 88%);
    border: 1px solid color-mix(in oklch, var(--signal-success, #22c55e) 25%, transparent 75%);
    padding: 1px 6px;
    border-radius: 9999px;
  }

  .rd-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
    gap: var(--space-3);
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
</style>
