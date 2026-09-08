<script lang="ts">
/**
 * HistoryPane — cross-session block history with search + filter.
 * CSS prefix: hp-
 * LOC target: ≤ 250.
 *
 * Data flow:
 *   1. On mount: fetch 5 most recent sessions via sessionsQuery (limit=5).
 *   2. For each session: fetch blocks via listBlocks (limit=50).
 *   3. Merge all blocks into a single list, sorted by insertedAt desc.
 *   4. Search + filter applied client-side on the merged list.
 *   5. Click a result → openPane(agent_conversation, sessionId).
 */

import { onMount } from 'svelte';
import { listBlocks } from '$lib/api/queries/blocks.js';
import { listSessions } from '$lib/api/queries/sessions.js';
import type { Block, BlockKind } from '$lib/domain/blocks/types.js';
import type { Session } from '$lib/domain/sessions/types.js';
import { mosaicLayout, type Pane } from '$lib/stores/mosaic-layout.svelte.js';

interface Props {
  workspaceSlug?: string;
}

let { workspaceSlug = 'default' }: Props = $props();

// ── State ────────────────────────────────────────────────────────────────────

type BlockKindFilter = 'all' | BlockKind;

interface EnrichedBlock {
  block: Block;
  sessionTitle: string;
  sessionId: string;
}

let allBlocks = $state<EnrichedBlock[]>([]);
let loading = $state(true);
let error = $state<string | null>(null);
let rawQuery = $state('');
let searchQuery = $state('');
let activeFilter = $state<BlockKindFilter>('all');

// Frecency: clicks per block id, stored in localStorage
function loadClicks(): Record<string, number> {
  try {
    return JSON.parse(localStorage.getItem('hp-frecency') ?? '{}');
  } catch {
    return {};
  }
}
function saveClick(blockId: string): void {
  const map = loadClicks();
  map[blockId] = (map[blockId] ?? 0) + 1;
  try {
    localStorage.setItem('hp-frecency', JSON.stringify(map));
  } catch {
    /* ignore */
  }
}

// ── Debounce search input ────────────────────────────────────────────────────

let debounceTimer: ReturnType<typeof setTimeout>;
function handleQueryInput(e: Event): void {
  clearTimeout(debounceTimer);
  const val = (e.target as HTMLInputElement).value;
  rawQuery = val;
  debounceTimer = setTimeout(() => {
    searchQuery = val.trim().toLowerCase();
  }, 300);
}

// ── Fetch on mount ───────────────────────────────────────────────────────────

onMount(() => {
  loadHistory();
});

async function loadHistory(): Promise<void> {
  loading = true;
  error = null;
  try {
    const sessions: Session[] = await listSessions({ workspaceSlug, limit: 5 });
    const results = await Promise.allSettled(
      sessions.map(async (s) => {
        const list = await listBlocks(s.id, { limit: 50 });
        return list.data.map(
          (b): EnrichedBlock => ({
            block: b,
            sessionId: s.id,
            sessionTitle: (s as { title?: string }).title || `Session ${s.id.slice(0, 6)}`,
          })
        );
      })
    );
    const merged: EnrichedBlock[] = [];
    for (const r of results) {
      if (r.status === 'fulfilled') merged.push(...r.value);
    }
    // Sort by insertedAt desc
    merged.sort((a, b) => b.block.insertedAt.localeCompare(a.block.insertedAt));
    allBlocks = merged;
  } catch (err) {
    error = err instanceof Error ? err.message : 'Failed to load history';
  } finally {
    loading = false;
  }
}

// ── Filtered + searched list ─────────────────────────────────────────────────

const filtered = $derived.by<EnrichedBlock[]>(() => {
  const clicks = loadClicks();
  let list = allBlocks;

  if (activeFilter !== 'all') {
    list = list.filter((e) => e.block.kind === activeFilter);
  }

  if (searchQuery) {
    list = list.filter((e) => {
      const text = [e.block.inputText ?? '', e.block.outputText ?? '', e.sessionTitle]
        .join(' ')
        .toLowerCase();
      return text.includes(searchQuery);
    });
  }

  // Frecency sort when no explicit search
  if (!searchQuery) {
    const now = Date.now();
    list = [...list].sort((a, b) => {
      const ca = clicks[a.block.id] ?? 0;
      const cb = clicks[b.block.id] ?? 0;
      const ra = now - new Date(a.block.insertedAt).getTime();
      const rb = now - new Date(b.block.insertedAt).getTime();
      // frecency = clicks * (1 / age_hours), higher is better
      const fa = ca / Math.max(ra / 3_600_000, 0.001);
      const fb = cb / Math.max(rb / 3_600_000, 0.001);
      return fb - fa;
    });
  }

  return list;
});

// ── Actions ──────────────────────────────────────────────────────────────────

function openSession(sessionId: string): void {
  const pane: Pane = {
    id: Math.random().toString(36).slice(2, 9),
    kind: 'agent_conversation',
    ref: sessionId,
    title: 'Session',
    config: { sessionId },
  };
  mosaicLayout.openPane(pane);
}

function handleResultClick(entry: EnrichedBlock): void {
  saveClick(entry.block.id);
  openSession(entry.sessionId);
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function relativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60_000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  return `${Math.floor(hrs / 24)}d ago`;
}

function blockPreview(block: Block): string {
  const raw = block.inputText ?? block.outputText ?? '';
  return raw.length > 120 ? raw.slice(0, 120) + '…' : raw;
}

const KIND_LABELS: Record<BlockKind, string> = {
  command: 'CMD',
  agent_message: 'MSG',
  tool_call: 'TOOL',
  tool_result: 'RES',
  approval: 'APPR',
  diff: 'DIFF',
  system_event: 'SYS',
  error: 'ERR',
};

const FILTERS: Array<{ id: BlockKindFilter; label: string }> = [
  { id: 'all', label: 'All' },
  { id: 'command', label: 'Commands' },
  { id: 'agent_message', label: 'Agent Messages' },
  { id: 'tool_call', label: 'Tool Calls' },
  { id: 'error', label: 'Errors' },
];
</script>

<div class="hp-root">
  <!-- Search bar -->
  <div class="hp-search">
    <input
      class="hp-search__input"
      type="text"
      placeholder="Search blocks across sessions…"
      aria-label="Search block history"
      value={rawQuery}
      oninput={handleQueryInput}
    />
  </div>

  <!-- Filter chips -->
  <div class="hp-filters" role="group" aria-label="Filter by block kind">
    {#each FILTERS as f (f.id)}
      <button
        class="hp-chip"
        class:hp-chip--active={activeFilter === f.id}
        onclick={() => { activeFilter = f.id; }}
        aria-pressed={activeFilter === f.id}
      >
        {f.label}
      </button>
    {/each}
  </div>

  <!-- Results -->
  <div class="hp-list" role="list">
    {#if loading}
      <div class="hp-empty">Loading history…</div>
    {:else if error}
      <div class="hp-empty hp-empty--error">{error}</div>
    {:else if filtered.length === 0}
      <div class="hp-empty">
        <span class="hp-empty__label">No blocks found</span>
        <span class="hp-empty__hint">Start a conversation to build history</span>
      </div>
    {:else}
      {#each filtered as entry (entry.block.id)}
        <button
          class="hp-result"
          role="listitem"
          onclick={() => handleResultClick(entry)}
          aria-label="Open session: {entry.sessionTitle}"
        >
          <span class="hp-result__kind hp-result__kind--{entry.block.kind}">
            {KIND_LABELS[entry.block.kind]}
          </span>
          <span class="hp-result__body">
            <span class="hp-result__content">{blockPreview(entry.block)}</span>
            <span class="hp-result__meta">
              <span class="hp-result__session">{entry.sessionTitle}</span>
              <span class="hp-result__time">{relativeTime(entry.block.insertedAt)}</span>
            </span>
          </span>
        </button>
      {/each}
    {/if}
  </div>
</div>

<style>
  .hp-root {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
    font-family: var(--font-sans);
  }

  /* ── Search ─────────────────────────────────────────────────── */
  .hp-search {
    padding: 12px 12px 8px;
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .hp-search__input {
    width: 100%;
    box-sizing: border-box;
    background: color-mix(in oklch, var(--fg) 5%, transparent);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: 7px 10px;
    font-size: var(--text-sm);
    font-family: var(--font-sans);
    color: var(--fg);
    outline: none;
    transition: border-color 0.12s ease;
  }
  .hp-search__input::placeholder { color: var(--fg-subtle); }
  .hp-search__input:focus { border-color: var(--cnp-accent, oklch(0.72 0.18 145)); }

  /* ── Filter chips ───────────────────────────────────────────── */
  .hp-filters {
    display: flex;
    gap: 6px;
    padding: 8px 12px;
    flex-shrink: 0;
    overflow-x: auto;
    scrollbar-width: none;
    border-bottom: 1px solid var(--border);
  }
  .hp-filters::-webkit-scrollbar { display: none; }

  .hp-chip {
    flex-shrink: 0;
    padding: 3px 10px;
    border-radius: 99px;
    border: 1px solid var(--border);
    background: transparent;
    font-size: 11px;
    font-weight: 500;
    color: var(--fg-muted);
    cursor: pointer;
    transition: background 0.1s ease, color 0.1s ease, border-color 0.1s ease;
    font-family: var(--font-sans);
  }
  .hp-chip:hover { background: color-mix(in oklch, var(--fg) 8%, transparent); color: var(--fg); }
  .hp-chip--active {
    background: var(--cnp-accent, oklch(0.72 0.18 145));
    border-color: transparent;
    color: oklch(0.12 0 0);
  }

  /* ── Results list ───────────────────────────────────────────── */
  .hp-list {
    flex: 1;
    overflow-y: auto;
    padding: 6px;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .hp-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 6px;
    flex: 1;
    min-height: 120px;
    padding: 24px;
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    text-align: center;
  }
  .hp-empty--error { color: var(--color-error, oklch(0.55 0.2 20)); }
  .hp-empty__label { font-weight: 500; color: var(--fg-muted); }
  .hp-empty__hint { font-size: 11px; }

  .hp-result {
    display: flex;
    align-items: flex-start;
    gap: 10px;
    width: 100%;
    padding: 9px 10px;
    border-radius: var(--radius-md);
    border: none;
    background: transparent;
    cursor: pointer;
    text-align: left;
    transition: background 0.08s ease;
  }
  .hp-result:hover { background: color-mix(in oklch, var(--fg) 7%, transparent); }

  .hp-result__kind {
    flex-shrink: 0;
    font-size: 9px;
    font-weight: 700;
    letter-spacing: 0.07em;
    text-transform: uppercase;
    padding: 2px 5px;
    border-radius: var(--radius-sm);
    background: color-mix(in oklch, var(--fg) 10%, transparent);
    color: var(--fg-muted);
    margin-top: 1px;
    min-width: 32px;
    text-align: center;
  }
  .hp-result__kind--error { background: color-mix(in oklch, oklch(0.55 0.2 20) 20%, transparent); color: oklch(0.55 0.2 20); }
  .hp-result__kind--command { background: color-mix(in oklch, oklch(0.72 0.18 260) 15%, transparent); color: oklch(0.72 0.18 260); }
  .hp-result__kind--agent_message { background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 15%, transparent); color: var(--cnp-accent, oklch(0.72 0.18 145)); }

  .hp-result__body {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .hp-result__content {
    font-size: var(--text-sm);
    color: var(--fg);
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
    line-height: 1.45;
  }

  .hp-result__meta {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .hp-result__session {
    font-size: 11px;
    color: var(--fg-subtle);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 160px;
  }

  .hp-result__time {
    font-size: 11px;
    color: var(--fg-subtle);
    flex-shrink: 0;
    margin-left: auto;
  }
</style>
