<script lang="ts">
/**
 * WorkspaceSwitcher — sidebar trigger + popover for switching active workspace.
 * Reads/writes ui.currentWorkspaceSlug. Fetches via workspacesQuery().
 * Keyboard: ↑/↓ navigate list, ↵ select, Escape close. ⌘⇧W (layout-level).
 * CSS prefix: ws- (WorkspaceSwitcher)
 * LOC target: ≤ 250
 */
import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
import { ChevronDown } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { workspacesQuery } from '$lib/api/queries/workspaces.js';
import NewWorkspaceDialog from '$lib/design/patterns/workspace/NewWorkspaceDialog.svelte';
import type { Workspace } from '$lib/domain/workspaces/types.js';
import { activeWorkspace } from '$lib/stores/active-workspace.svelte.js';
import { toasts } from '$lib/stores/toasts.svelte.js';
import { ui } from '$lib/stores/ui.svelte.js';

// ── TanStack Query (canonical writable+untrack+$effect bridge) ───────────────

const queryOptsStore = writable(
  untrack(() => workspacesQuery() as CreateQueryOptions<Workspace[]>)
);
const workspacesQ = createQuery<Workspace[]>(queryOptsStore);

const workspaces = $derived(($workspacesQ.data ?? []) as Workspace[]);

// ── Template emoji map (matches WorkspaceCard.svelte) ────────────────────────

const TEMPLATE_EMOJI: Record<string, string> = {
  blank: '📄',
  'sales-engine': '💼',
  'dev-shop': '⚙️',
  'content-factory': '🎬',
};

function emojiFor(ws: Workspace): string {
  return ws.template ? (TEMPLATE_EMOJI[ws.template] ?? '📁') : '📁';
}

// ── Local state ───────────────────────────────────────────────────────────────

let searchQuery = $state('');
let activeIndex = $state(0);
let triggerEl = $state<HTMLButtonElement | null>(null);
let searchEl = $state<HTMLInputElement | null>(null);
let newDialogOpen = $state(false);

const isOpen = $derived(ui.workspaceSwitcherOpen);

const filtered = $derived(
  searchQuery.trim() === ''
    ? workspaces
    : workspaces.filter(
        (w) =>
          w.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
          w.slug.toLowerCase().includes(searchQuery.toLowerCase())
      )
);

const currentWorkspace = $derived(
  workspaces.find((w) => w.slug === ui.currentWorkspaceSlug) ?? null
);

const triggerLabel = $derived(
  currentWorkspace ? `${emojiFor(currentWorkspace)} ${currentWorkspace.name}` : '📁 No workspace'
);

// Auto-select the first workspace when none is saved in localStorage.
$effect(() => {
  if (!ui.currentWorkspaceSlug && workspaces.length > 0) {
    ui.setCurrentWorkspace(workspaces[0].slug);
  }
});

// Keep the active-workspace store in sync with the workspace pool whenever
// the API list updates. This is what makes `setActive(slug)` resolvable
// downstream and refreshes name/rootPath after a rename.
$effect(() => {
  activeWorkspace.syncPool(workspaces);
});

// Reset activeIndex when filtered list changes
$effect(() => {
  // Track filtered length to reset cursor
  void filtered.length;
  activeIndex = 0;
});

// Focus search input when popover opens
$effect(() => {
  if (isOpen) {
    searchQuery = '';
    // Tick needed to let the popover render before focusing
    setTimeout(() => searchEl?.focus(), 0);
  }
});

// ── Interaction handlers ──────────────────────────────────────────────────────

function open(): void {
  ui.openWorkspaceSwitcher();
}

function close(): void {
  ui.closeWorkspaceSwitcher();
}

function select(ws: Workspace): void {
  ui.setCurrentWorkspace(ws.slug);
  // Mirror to the active-workspace store so name/rootPath propagate to
  // every module that reads `activeWorkspace.*`.
  activeWorkspace.setActive(ws.slug);
  toasts.success(`Switched to ${ws.name}`);
  close();
}

function openNewDialog(): void {
  close();
  newDialogOpen = true;
}

function closeNewDialog(): void {
  newDialogOpen = false;
}

function handleTriggerKeydown(e: KeyboardEvent): void {
  if (e.key === 'Enter' || e.key === ' ') {
    e.preventDefault();
    ui.toggleWorkspaceSwitcher();
  }
}

function handleListKeydown(e: KeyboardEvent): void {
  if (e.key === 'Escape') {
    e.preventDefault();
    close();
    triggerEl?.focus();
    return;
  }
  if (e.key === 'ArrowDown') {
    e.preventDefault();
    activeIndex = Math.min(activeIndex + 1, filtered.length - 1);
    return;
  }
  if (e.key === 'ArrowUp') {
    e.preventDefault();
    activeIndex = Math.max(activeIndex - 1, 0);
    return;
  }
  if (e.key === 'Enter' && filtered[activeIndex]) {
    e.preventDefault();
    select(filtered[activeIndex]);
  }
}

function handleBackdropClick(e: MouseEvent): void {
  if (e.target === e.currentTarget) close();
}
</script>

<!-- Trigger -->
<button
  bind:this={triggerEl}
  class="ws-trigger btn-compact btn-compact-ghost"
  aria-haspopup="listbox"
  aria-expanded={isOpen}
  aria-label="Switch workspace"
  onclick={open}
  onkeydown={handleTriggerKeydown}
>
  <span class="ws-trigger__label">{triggerLabel}</span>
  <ChevronDown size={11} aria-hidden="true" class="ws-trigger__chevron" />
</button>

<!-- Popover -->
{#if isOpen}
  <!-- Invisible backdrop to catch outside clicks -->
  <div
    class="ws-backdrop"
    role="presentation"
    onclick={handleBackdropClick}
  ></div>

  <div
    class="ws-popover glass-panel"
    role="listbox"
    aria-label="Workspaces"
    tabindex="-1"
    onkeydown={handleListKeydown}
  >
    <!-- Search -->
    <div class="ws-search-wrap">
      <input
        bind:this={searchEl}
        class="ws-search"
        type="search"
        placeholder="Search workspaces…"
        bind:value={searchQuery}
        aria-label="Search workspaces"
        autocomplete="off"
        spellcheck={false}
      />
    </div>

    <!-- List -->
    <div class="ws-list" role="presentation">
      {#if $workspacesQ.isLoading}
        <div class="ws-empty">Loading…</div>
      {:else if workspaces.length === 0}
        <div class="ws-empty">
          <p class="ws-empty__text">No workspaces yet.</p>
          <button
            class="btn-compact btn-compact-ghost ws-cta"
            onclick={openNewDialog}
          >
            Create your first workspace
          </button>
        </div>
      {:else if filtered.length === 0}
        <div class="ws-empty">
          <p class="ws-empty__text">No results for "{searchQuery}"</p>
        </div>
      {:else}
        {#each filtered as ws, i (ws.slug)}
          <button
            class="ws-item"
            class:ws-item--active={ws.slug === ui.currentWorkspaceSlug}
            class:ws-item--focused={i === activeIndex}
            role="option"
            aria-selected={ws.slug === ui.currentWorkspaceSlug}
            onclick={() => select(ws)}
            onmouseenter={() => { activeIndex = i; }}
          >
            <span class="ws-item__emoji" aria-hidden="true">{emojiFor(ws)}</span>
            <span class="ws-item__name">{ws.name}</span>
            {#if ws.slug === ui.currentWorkspaceSlug}
              <span class="ws-item__check" aria-hidden="true">✓</span>
            {/if}
          </button>
        {/each}
      {/if}
    </div>

    <!-- Footer -->
    <div class="ws-footer">
      <button
        class="ws-new-btn"
        onclick={openNewDialog}
        aria-label="Create new workspace"
      >
        + New workspace
      </button>
    </div>
  </div>
{/if}

<!-- New workspace dialog (rendered as a sibling so backdrop can cover the popover) -->
<NewWorkspaceDialog open={newDialogOpen} onClose={closeNewDialog} />

<style>
  /* Trigger */
  .ws-trigger {
    width: 100%;
    display: flex;
    align-items: center;
    gap: var(--space-1);
    justify-content: space-between;
    font-size: var(--text-sm);
    font-family: var(--font-sans);
    padding: var(--space-1) var(--space-2);
    color: var(--fg-muted);
    border-radius: var(--radius-md);
    min-height: 28px;
    overflow: hidden;
  }

  .ws-trigger__label {
    flex: 1;
    text-align: left;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-size: var(--text-sm);
  }

  :global(.ws-trigger__chevron) {
    flex-shrink: 0;
    opacity: 0.5;
  }

  /* Backdrop */
  .ws-backdrop {
    position: fixed;
    inset: 0;
    z-index: 49;
  }

  /* Popover */
  .ws-popover {
    position: absolute;
    bottom: calc(100% + var(--space-2));
    left: var(--space-2);
    right: var(--space-2);
    z-index: 50;
    display: flex;
    flex-direction: column;
    border-radius: var(--radius-lg);
    overflow: hidden;
    box-shadow:
      0 8px 32px color-mix(in oklch, var(--bg) 40%, transparent 60%),
      0 2px 8px color-mix(in oklch, var(--bg) 30%, transparent 70%);
  }

  /* Search */
  .ws-search-wrap {
    padding: var(--space-2);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .ws-search {
    width: 100%;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-1) var(--space-2);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    box-sizing: border-box;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .ws-search:focus {
    border-color: var(--border-strong);
  }

  .ws-search::placeholder {
    color: var(--fg-subtle);
  }

  /* List */
  .ws-list {
    flex: 1;
    overflow-y: auto;
    max-height: 220px;
    padding: var(--space-1);
  }

  .ws-item {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    width: 100%;
    padding: var(--space-1) var(--space-2);
    background: transparent;
    border: none;
    border-radius: var(--radius-sm);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    text-align: left;
    min-height: 28px;
    transition: background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .ws-item:hover,
  .ws-item--focused {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .ws-item--active {
    color: var(--fg);
    font-weight: 500;
  }

  .ws-item__emoji {
    flex-shrink: 0;
    font-size: 14px;
  }

  .ws-item__name {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .ws-item__check {
    flex-shrink: 0;
    font-size: 11px;
    color: var(--fg-muted);
  }

  /* Empty */
  .ws-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-4);
    text-align: center;
  }

  .ws-empty__text {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    margin: 0;
  }

  .ws-cta {
    font-size: var(--text-sm);
  }

  /* Footer */
  .ws-footer {
    border-top: 1px solid var(--border);
    padding: var(--space-1);
    flex-shrink: 0;
  }

  .ws-new-btn {
    display: block;
    width: 100%;
    padding: var(--space-1) var(--space-2);
    background: transparent;
    border: none;
    border-radius: var(--radius-sm);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    text-align: left;
    min-height: 28px;
    transition: background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .ws-new-btn:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }
</style>
