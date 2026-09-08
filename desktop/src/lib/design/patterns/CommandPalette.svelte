<script lang="ts">
/**
 * CommandPalette — global ⌘K overlay.
 * Grouped commands catalog from docs/02-frontend-design.md §7.
 * Week 4: fuzzy scoring, recency LRU (last 8 invocations), match highlighting.
 *
 * Scoring (highest wins):
 *   4 — exact prefix match on label words
 *   3 — word-boundary match (first char of any word)
 *   2 — contains match (substring anywhere)
 *   1 — character subsequence
 *   0 — no match
 *
 * Recently-used commands float to top within their group.
 * localStorage key: "canopy.cmd.recent"  (LRU, max 8 ids)
 *
 * Keyboard: ↑/↓ navigate, ↵ execute, Esc close, Tab cycle section.
 */

import { Search } from 'lucide-svelte';
import { goto } from '$app/navigation';
import { ui } from '$lib/stores/ui.svelte.js';
import Kbd from './Kbd.svelte';

interface Command {
  id: string;
  label: string;
  group: string;
  shortcut?: string;
  action: () => void;
}

const allCommands: Command[] = [
  // Navigate
  {
    id: 'go-home',
    label: 'Go to Home',
    group: 'Navigate',
    shortcut: '⌘1',
    action: () => goto('/'),
  },
  {
    id: 'go-runtimes',
    label: 'Go to Runtimes',
    group: 'Navigate',
    shortcut: '⌘2',
    action: () => goto('/runtimes'),
  },
  {
    id: 'go-sessions',
    label: 'Go to Sessions',
    group: 'Navigate',
    shortcut: '⌘3',
    action: () => goto('/sessions'),
  },
  {
    id: 'go-agents',
    label: 'Go to Agents',
    group: 'Navigate',
    shortcut: '⌘4',
    action: () => goto('/agents'),
  },
  {
    id: 'go-workspaces',
    label: 'Go to Workspaces',
    group: 'Navigate',
    shortcut: '⌘5',
    action: () => goto('/workspaces'),
  },
  // Actions
  {
    id: 'new-session',
    label: 'New Session',
    group: 'Actions',
    shortcut: '⌘N',
    action: () => goto('/'),
  },
  {
    id: 'new-agent',
    label: 'New Agent',
    group: 'Actions',
    shortcut: '⌘⇧N',
    action: () => goto('/agents'),
  },
  {
    id: 'new-workspace',
    label: 'New Workspace',
    group: 'Actions',
    shortcut: '⌘⇧W',
    action: () => goto('/workspaces'),
  },
  {
    id: 'resume-last',
    label: 'Resume Last Session',
    group: 'Actions',
    action: () => goto('/sessions'),
  },
  {
    id: 'stop-all',
    label: 'Stop All Running Sessions',
    group: 'Actions',
    action: () => {
      /* stub */
    },
  },
  {
    id: 'running-only',
    label: 'Show Running Sessions Only',
    group: 'Actions',
    action: () => goto('/sessions?status=running'),
  },
  {
    id: 'toggle-theme',
    label: 'Toggle Dark / Light',
    group: 'Actions',
    shortcut: '⌘⇧D',
    action: () => ui.toggleTheme(),
  },
  {
    id: 'settings',
    label: 'Open Settings',
    group: 'Actions',
    shortcut: '⌘,',
    action: () => goto('/settings'),
  },
  {
    id: 'report-bug',
    label: 'Report Bug',
    group: 'Actions',
    action: () => {
      /* stub */
    },
  },
];

// ── Recency LRU ─────────────────────────────────────────────────────────────

const RECENT_KEY = 'canopy.cmd.recent';
const RECENT_MAX = 8;

function readRecent(): string[] {
  try {
    const raw = typeof localStorage !== 'undefined' ? localStorage.getItem(RECENT_KEY) : null;
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.slice(0, RECENT_MAX) : [];
  } catch {
    return [];
  }
}

function writeRecent(ids: string[]): void {
  try {
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem(RECENT_KEY, JSON.stringify(ids.slice(0, RECENT_MAX)));
    }
  } catch {
    /* non-fatal */
  }
}

function pushRecent(id: string): void {
  const prev = readRecent().filter((x) => x !== id);
  writeRecent([id, ...prev]);
}

// ── Fuzzy scoring ────────────────────────────────────────────────────────────

/**
 * Score a command against a query string.
 * Returns 0–4. Higher = better match.
 */
function fuzzyScore(cmd: Command, q: string): number {
  if (!q) return 1; // all commands shown equally when no query
  const label = cmd.label.toLowerCase();
  const lower = q.toLowerCase();

  // 4: exact prefix on any word boundary
  const words = label.split(/\s+/);
  if (words.some((w) => w.startsWith(lower))) return 4;

  // 3: first character of any word starts with first char of q (word-boundary)
  if (words.some((w) => w.charAt(0) === lower.charAt(0)) && label.includes(lower.charAt(0))) {
    // Only award 3 if it's genuinely a word-boundary match, not just random
    if (words.some((w) => w.startsWith(lower.charAt(0)) && label.includes(lower))) return 3;
  }

  // 2: contains match
  if (label.includes(lower)) return 2;

  // 1: character subsequence
  if (isSubsequence(lower, label)) return 1;

  return 0;
}

function isSubsequence(needle: string, haystack: string): boolean {
  let ni = 0;
  for (let hi = 0; hi < haystack.length && ni < needle.length; hi++) {
    if (haystack[hi] === needle[ni]) ni++;
  }
  return ni === needle.length;
}

/**
 * Find match spans for highlighting.
 * Returns array of [start, end] pairs (exclusive end) for chars that match.
 */
function matchSpans(label: string, q: string): Array<[number, number]> {
  if (!q.trim()) return [];
  const lower = q.toLowerCase();
  const labelLower = label.toLowerCase();

  // Try substring highlight first
  const idx = labelLower.indexOf(lower);
  if (idx !== -1) return [[idx, idx + lower.length]];

  // Fall back to subsequence character positions
  const spans: Array<[number, number]> = [];
  let ni = 0;
  for (let hi = 0; hi < labelLower.length && ni < lower.length; hi++) {
    if (labelLower[hi] === lower[ni]) {
      spans.push([hi, hi + 1]);
      ni++;
    }
  }
  return spans;
}

/**
 * Merge spans into an array of {text, highlighted} segments for rendering.
 */
interface LabelSegment {
  text: string;
  bold: boolean;
}

function segmentLabel(label: string, q: string): LabelSegment[] {
  const spans = matchSpans(label, q);
  if (spans.length === 0) return [{ text: label, bold: false }];

  const segments: LabelSegment[] = [];
  let cursor = 0;
  for (const [start, end] of spans) {
    if (start > cursor) segments.push({ text: label.slice(cursor, start), bold: false });
    segments.push({ text: label.slice(start, end), bold: true });
    cursor = end;
  }
  if (cursor < label.length) segments.push({ text: label.slice(cursor), bold: false });
  return segments;
}

// ── Component state ──────────────────────────────────────────────────────────

let query = $state('');
let activeIndex = $state(0);
let searchInputEl = $state<HTMLInputElement | null>(null);
let recentIds = $state<string[]>([]);

const open = $derived(ui.commandPaletteOpen);

function close(): void {
  ui.closeCommandPalette();
  query = '';
  activeIndex = 0;
}

/** Filter + score commands. Returns sorted results with score ≥ 1 (or all when empty). */
const filtered = $derived.by(() => {
  const q = query.trim();
  if (!q) return allCommands;

  return allCommands
    .map((cmd) => ({ cmd, score: fuzzyScore(cmd, q) }))
    .filter(({ score }) => score > 0)
    .sort((a, b) => b.score - a.score)
    .map(({ cmd }) => cmd);
});

/** Grouped commands — recent float to top within their group. */
const grouped = $derived.by(() => {
  const groups: Record<string, Command[]> = {};
  const q = query.trim();

  for (const cmd of filtered) {
    if (!groups[cmd.group]) groups[cmd.group] = [];
    groups[cmd.group].push(cmd);
  }

  // Within each group, push recent commands to front
  if (!q && recentIds.length > 0) {
    for (const group of Object.values(groups)) {
      group.sort((a, b) => {
        const ai = recentIds.indexOf(a.id);
        const bi = recentIds.indexOf(b.id);
        if (ai === -1 && bi === -1) return 0;
        if (ai === -1) return 1;
        if (bi === -1) return -1;
        return ai - bi;
      });
    }
  }

  return groups;
});

/** Flat ordered list for keyboard index tracking. */
const flatFiltered = $derived(Object.values(grouped).flat());

/** Recent commands group (shown when query is empty). */
const recentCommands = $derived(
  !query.trim()
    ? recentIds
        .map((id) => allCommands.find((c) => c.id === id))
        .filter((c): c is Command => c !== undefined)
    : []
);

function execute(cmd: Command): void {
  pushRecent(cmd.id);
  recentIds = readRecent();
  cmd.action();
  close();
}

function handleKeydown(e: KeyboardEvent): void {
  switch (e.key) {
    case 'ArrowDown':
    case 'j':
      e.preventDefault();
      activeIndex = Math.min(activeIndex + 1, flatFiltered.length - 1);
      break;
    case 'ArrowUp':
    case 'k':
      e.preventDefault();
      activeIndex = Math.max(activeIndex - 1, 0);
      break;
    case 'Tab':
      // Cycle through sections
      e.preventDefault();
      activeIndex = activeIndex < flatFiltered.length - 1 ? activeIndex + 1 : 0;
      break;
    case 'Enter':
      e.preventDefault();
      if (flatFiltered[activeIndex]) execute(flatFiltered[activeIndex]);
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
    recentIds = readRecent();
    searchInputEl?.focus();
  }
});
</script>

{#if open}
  <!-- Backdrop -->
  <div
    class="cnp-cp-backdrop"
    onclick={close}
    onkeydown={(e) => { if (e.key === 'Escape') close(); }}
    role="presentation"
    aria-hidden="true"
  ></div>

  <!-- Palette container -->
  <div
    class="cnp-cp glass-panel"
    role="dialog"
    aria-label="Command palette"
    aria-modal="true"
    tabindex="-1"
    onkeydown={handleKeydown}
  >
    <!-- Search input -->
    <div class="cnp-cp__search">
      <Search size={14} class="cnp-cp__search-icon" aria-hidden="true" />
      <input
        class="cnp-cp__input"
        type="text"
        placeholder="Type a command or search..."
        bind:value={query}
        bind:this={searchInputEl}
        aria-label="Command search"
        autocomplete="off"
      />
      <Kbd chord="esc" />
    </div>

    <!-- Results -->
    <div class="cnp-cp__results" role="listbox" aria-label="Commands">
      {#if flatFiltered.length === 0}
        <p class="cnp-cp__empty">No commands found.</p>
      {:else}
        <!-- Recent group (only when no query) -->
        {#if recentCommands.length > 0 && !query.trim()}
          <div class="cnp-cp__group">
            <span class="cnp-cp__group-label">Recent</span>
            {#each recentCommands as cmd (cmd.id)}
              {@const idx = flatFiltered.indexOf(cmd)}
              <button
                class="cnp-cp__item"
                class:cnp-cp__item--active={activeIndex === idx}
                onclick={() => execute(cmd)}
                role="option"
                aria-selected={activeIndex === idx}
                id="cmd-recent-{cmd.id}"
              >
                <span class="cnp-cp__item-label">{cmd.label}</span>
                {#if cmd.shortcut}
                  <Kbd chord={cmd.shortcut} />
                {/if}
              </button>
            {/each}
          </div>
        {/if}

        <!-- Main groups -->
        {#each Object.entries(grouped) as [groupName, cmds] (groupName)}
          <div class="cnp-cp__group">
            <span class="cnp-cp__group-label">{groupName}</span>
            {#each cmds as cmd (cmd.id)}
              {@const idx = flatFiltered.indexOf(cmd)}
              {@const segments = segmentLabel(cmd.label, query.trim())}
              <button
                class="cnp-cp__item"
                class:cnp-cp__item--active={activeIndex === idx}
                onclick={() => execute(cmd)}
                role="option"
                aria-selected={activeIndex === idx}
                id="cmd-{cmd.id}"
              >
                <span class="cnp-cp__item-label">
                  {#each segments as seg (seg.text + seg.bold)}
                    {#if seg.bold}
                      <strong class="cnp-cp__match">{seg.text}</strong>
                    {:else}
                      {seg.text}
                    {/if}
                  {/each}
                </span>
                {#if cmd.shortcut}
                  <Kbd chord={cmd.shortcut} />
                {/if}
              </button>
            {/each}
          </div>
        {/each}
      {/if}
    </div>
  </div>
{/if}

<style>
  .cnp-cp-backdrop {
    position: fixed;
    inset: 0;
    z-index: 200;
    background: rgba(0, 0, 0, 0.5);
    backdrop-filter: blur(4px);
    animation: cnp-cp-fade var(--dur-fast) var(--ease-out) both;
  }

  .cnp-cp {
    position: fixed;
    top: 20%;
    left: 50%;
    transform: translateX(-50%);
    z-index: 201;
    width: 560px;
    max-width: calc(100vw - 2rem);
    max-height: 60vh;
    display: flex;
    flex-direction: column;
    border-radius: var(--radius-xl);
    overflow: hidden;
    animation: cnp-cp-enter var(--dur-normal) var(--ease-out) both;
  }

  .cnp-cp__search {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-3) var(--space-4);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  :global(.cnp-cp__search-icon) {
    color: var(--fg-subtle);
    flex-shrink: 0;
  }

  .cnp-cp__input {
    flex: 1;
    background: transparent;
    border: none;
    outline: none;
    font-family: var(--font-sans);
    font-size: var(--text-base);
    color: var(--fg);
    caret-color: var(--cnp-accent);
  }

  .cnp-cp__input::placeholder {
    color: var(--fg-subtle);
  }

  .cnp-cp__results {
    overflow-y: auto;
    padding: var(--space-2);
    flex: 1;
  }

  .cnp-cp__empty {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    text-align: center;
    padding: var(--space-6);
    margin: 0;
  }

  .cnp-cp__group {
    display: flex;
    flex-direction: column;
    gap: 1px;
    margin-bottom: var(--space-2);
  }

  .cnp-cp__group-label {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.08em;
    color: var(--fg-subtle);
    padding: var(--space-1) var(--space-3);
    text-transform: uppercase;
    user-select: none;
  }

  .cnp-cp__item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-2) var(--space-3);
    border: none;
    background: transparent;
    border-radius: var(--radius-md);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    width: 100%;
    text-align: left;
    transition: background var(--dur-instant) var(--ease-out);
    min-height: 32px;
  }

  .cnp-cp__item:hover,
  .cnp-cp__item--active {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
  }

  .cnp-cp__item-label {
    font-weight: 500;
  }

  .cnp-cp__match {
    font-weight: 700;
    color: var(--fg);
  }

  @keyframes cnp-cp-fade {
    from { opacity: 0; }
    to { opacity: 1; }
  }

  @keyframes cnp-cp-enter {
    from { opacity: 0; transform: translateX(-50%) translateY(-8px) scale(0.97); }
    to { opacity: 1; transform: translateX(-50%) translateY(0) scale(1); }
  }
</style>
