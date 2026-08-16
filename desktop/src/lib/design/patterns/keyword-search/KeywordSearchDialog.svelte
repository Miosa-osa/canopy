<script lang="ts">
/**
 * KeywordSearchDialog — global fuzzy search across sessions, agents, workspaces,
 * tasks, runs. Triggered by ⌘/ binding. Indexes TanStack Query cache.
 *
 * CSS prefix: ksd-
 * LOC target: ≤ 260.
 */

import { useQueryClient } from '@tanstack/svelte-query';
import { Search } from 'lucide-svelte';
import { goto } from '$app/navigation';
import Kbd from '$lib/design/patterns/Kbd.svelte';

interface SearchHit {
  id: string;
  label: string;
  sublabel?: string;
  kind: 'session' | 'agent' | 'workspace' | 'task' | 'run';
  href: string;
}

interface Props {
  open?: boolean;
  onclose?: () => void;
}

let { open = false, onclose }: Props = $props();

const queryClient = useQueryClient();

let query = $state('');
let activeIndex = $state(0);
let inputEl = $state<HTMLInputElement | null>(null);

// ── Cache mining ────────────────────────────────────────────────────────────

function mineCache(): SearchHit[] {
  const hits: SearchHit[] = [];
  const cache = queryClient.getQueryCache();

  for (const q of cache.getAll()) {
    const data = q.state.data;
    if (!data || !Array.isArray(data)) continue;

    const key = q.queryKey;
    const firstKey = Array.isArray(key) ? key[0] : null;

    for (const item of data as Record<string, unknown>[]) {
      if (firstKey === 'sessions' && item.id && (item.prompt || item.agentSlug)) {
        hits.push({
          id: String(item.id),
          label: String(item.prompt ?? item.agentSlug ?? item.id).slice(0, 80),
          sublabel: `session · ${item.status ?? ''}`,
          kind: 'session',
          href: `/sessions/${item.id}`,
        });
      } else if (firstKey === 'agents' && item.slug) {
        hits.push({
          id: String(item.slug),
          label: String(item.name ?? item.slug),
          sublabel: `agent`,
          kind: 'agent',
          href: `/agents/${item.slug}`,
        });
      } else if (firstKey === 'workspaces' && item.slug) {
        hits.push({
          id: String(item.slug),
          label: String(item.name ?? item.slug),
          sublabel: `workspace`,
          kind: 'workspace',
          href: `/workspaces/${item.slug}`,
        });
      } else if (firstKey === 'tasks' && item.id) {
        hits.push({
          id: String(item.id),
          label: String(item.title ?? item.id),
          sublabel: `task · ${item.status ?? ''}`,
          kind: 'task',
          href: `/tasks/${item.id}`,
        });
      } else if (firstKey === 'runs' && item.id) {
        hits.push({
          id: String(item.id),
          label: String(item.shortId ?? item.id),
          sublabel: `run · ${item.status ?? ''}`,
          kind: 'run',
          href: `/sessions/${item.sessionId ?? ''}`,
        });
      }
    }
  }

  return hits;
}

// ── Fuzzy filter ─────────────────────────────────────────────────────────────

function score(hit: SearchHit, q: string): number {
  const label = hit.label.toLowerCase();
  const lower = q.toLowerCase();
  if (label.startsWith(lower)) return 4;
  if (label.includes(lower)) return 2;
  // subsequence
  let ni = 0;
  for (let hi = 0; hi < label.length && ni < lower.length; hi++) {
    if (label[hi] === lower[ni]) ni++;
  }
  return ni === lower.length ? 1 : 0;
}

const results = $derived.by(() => {
  const q = query.trim();
  const all = mineCache();
  if (!q) return all.slice(0, 24);
  return all
    .map((h) => ({ h, s: score(h, q) }))
    .filter(({ s }) => s > 0)
    .sort((a, b) => b.s - a.s)
    .map(({ h }) => h)
    .slice(0, 24);
});

// ── Kind icon text ────────────────────────────────────────────────────────────

const KIND_LABEL: Record<SearchHit['kind'], string> = {
  session: 'S',
  agent: 'A',
  workspace: 'W',
  task: 'T',
  run: 'R',
};

// ── Keyboard nav ─────────────────────────────────────────────────────────────

function navigate(hit: SearchHit): void {
  void goto(hit.href);
  close();
}

function close(): void {
  query = '';
  activeIndex = 0;
  onclose?.();
}

function handleKeydown(e: KeyboardEvent): void {
  switch (e.key) {
    case 'ArrowDown':
      e.preventDefault();
      activeIndex = Math.min(activeIndex + 1, results.length - 1);
      break;
    case 'ArrowUp':
      e.preventDefault();
      activeIndex = Math.max(activeIndex - 1, 0);
      break;
    case 'Enter':
      e.preventDefault();
      if (results[activeIndex]) navigate(results[activeIndex]);
      break;
    case 'Escape':
      e.preventDefault();
      close();
      break;
  }
}

$effect(() => {
  void query;
  activeIndex = 0;
});

$effect(() => {
  if (open) {
    inputEl?.focus();
  }
});
</script>

{#if open}
  <!-- Backdrop -->
  <div
    class="ksd-backdrop"
    onclick={close}
    onkeydown={(e) => { if (e.key === 'Escape') close(); }}
    role="presentation"
    aria-hidden="true"
  ></div>

  <!-- Dialog -->
  <div
    class="ksd-dialog glass-panel"
    role="dialog"
    aria-label="Global search"
    aria-modal="true"
    tabindex="-1"
    onkeydown={handleKeydown}
  >
    <div class="ksd-search">
      <Search size={14} class="ksd-search-icon" aria-hidden="true" />
      <input
        class="ksd-input"
        type="text"
        placeholder="Search sessions, agents, workspaces, tasks…"
        bind:value={query}
        bind:this={inputEl}
        aria-label="Global search"
        autocomplete="off"
      />
      <Kbd chord="esc" />
    </div>

    <div class="ksd-results" role="listbox" aria-label="Search results">
      {#if results.length === 0}
        <p class="ksd-empty">
          {query.trim() ? 'No matches found.' : 'Start typing to search…'}
        </p>
      {:else}
        {#each results as hit, i (hit.id + hit.kind)}
          <button
            class="ksd-row"
            class:ksd-row--active={activeIndex === i}
            onclick={() => navigate(hit)}
            role="option"
            aria-selected={activeIndex === i}
          >
            <span class="ksd-kind ksd-kind--{hit.kind}" aria-label={hit.kind}>
              {KIND_LABEL[hit.kind]}
            </span>
            <span class="ksd-label">{hit.label}</span>
            {#if hit.sublabel}
              <span class="ksd-sub">{hit.sublabel}</span>
            {/if}
          </button>
        {/each}
      {/if}
    </div>
  </div>
{/if}

<style>
  .ksd-backdrop {
    position: fixed;
    inset: 0;
    z-index: 200;
    background: rgba(0, 0, 0, 0.5);
    backdrop-filter: blur(4px);
    animation: ksd-fade var(--dur-fast) var(--ease-out) both;
  }

  .ksd-dialog {
    position: fixed;
    top: 18%;
    left: 50%;
    transform: translateX(-50%);
    z-index: 201;
    width: 580px;
    max-width: calc(100vw - 2rem);
    max-height: 64vh;
    display: flex;
    flex-direction: column;
    border-radius: var(--radius-xl);
    overflow: hidden;
    animation: ksd-enter var(--dur-normal) var(--ease-out) both;
  }

  .ksd-search {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-3) var(--space-4);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  :global(.ksd-search-icon) {
    color: var(--fg-subtle);
    flex-shrink: 0;
  }

  .ksd-input {
    flex: 1;
    background: transparent;
    border: none;
    outline: none;
    font-family: var(--font-sans);
    font-size: var(--text-base);
    color: var(--fg);
    caret-color: var(--cnp-accent);
  }

  .ksd-input::placeholder {
    color: var(--fg-subtle);
  }

  .ksd-results {
    overflow-y: auto;
    padding: var(--space-2);
    flex: 1;
  }

  .ksd-empty {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    text-align: center;
    padding: var(--space-6);
    margin: 0;
  }

  .ksd-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-3);
    border: none;
    background: transparent;
    border-radius: var(--radius-md);
    cursor: pointer;
    width: 100%;
    text-align: left;
    transition: background var(--dur-instant) var(--ease-out);
    min-height: 34px;
  }

  .ksd-row:hover,
  .ksd-row--active {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
  }

  .ksd-kind {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 18px;
    height: 18px;
    border-radius: var(--radius-sm);
    font-family: var(--font-mono);
    font-size: 10px;
    font-weight: 700;
    flex-shrink: 0;
    background: color-mix(in oklch, var(--fg) 10%, transparent);
    color: var(--fg-muted);
  }

  .ksd-kind--session { color: var(--cnp-accent); background: color-mix(in oklch, var(--cnp-accent) 15%, transparent); }
  .ksd-kind--agent   { color: var(--fg); background: color-mix(in oklch, var(--fg) 12%, transparent); }

  .ksd-label {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    flex: 1;
  }

  .ksd-sub {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    white-space: nowrap;
    flex-shrink: 0;
  }

  @keyframes ksd-fade {
    from { opacity: 0; }
    to { opacity: 1; }
  }

  @keyframes ksd-enter {
    from { opacity: 0; transform: translateX(-50%) translateY(-8px) scale(0.97); }
    to { opacity: 1; transform: translateX(-50%) translateY(0) scale(1); }
  }
</style>
