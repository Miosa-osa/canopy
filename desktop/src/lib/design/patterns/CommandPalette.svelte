<script lang="ts">
/**
 * CommandPalette — global ⌘K overlay (Core-OSS lift).
 * Grouped commands catalog from docs/02-frontend-design.md §7.
 * Fuzzy search, keyboard navigation (j/k or arrows, ↵ executes, esc closes).
 * Uses Foundation Modal backdrop pattern with custom content.
 * LOC target: ≤ 200.
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
  // Go to
  { id: 'go-home', label: 'Go to Home', group: 'Go to', shortcut: '⌘1', action: () => goto('/') },
  {
    id: 'go-runtimes',
    label: 'Go to Runtimes',
    group: 'Go to',
    shortcut: '⌘2',
    action: () => goto('/runtimes'),
  },
  {
    id: 'go-sessions',
    label: 'Go to Sessions',
    group: 'Go to',
    shortcut: '⌘3',
    action: () => goto('/sessions'),
  },
  {
    id: 'go-agents',
    label: 'Go to Agents',
    group: 'Go to',
    shortcut: '⌘4',
    action: () => goto('/agents'),
  },
  {
    id: 'go-workspaces',
    label: 'Go to Workspaces',
    group: 'Go to',
    shortcut: '⌘5',
    action: () => goto('/workspaces'),
  },
  // Create
  {
    id: 'new-session',
    label: 'New Session',
    group: 'Create',
    shortcut: '⌘N',
    action: () => goto('/'),
  },
  {
    id: 'new-agent',
    label: 'New Agent',
    group: 'Create',
    shortcut: '⌘⇧N',
    action: () => goto('/agents'),
  },
  {
    id: 'new-workspace',
    label: 'New Workspace',
    group: 'Create',
    shortcut: '⌘⇧W',
    action: () => goto('/workspaces'),
  },
  // Sessions
  {
    id: 'resume-last',
    label: 'Resume Last Session',
    group: 'Sessions',
    action: () => goto('/sessions'),
  },
  {
    id: 'stop-all',
    label: 'Stop All Running Sessions',
    group: 'Sessions',
    action: () => {
      /* stub */
    },
  },
  {
    id: 'running-only',
    label: 'Show Running Sessions Only',
    group: 'Sessions',
    action: () => goto('/sessions?status=running'),
  },
  // Theme
  {
    id: 'toggle-theme',
    label: 'Toggle Dark / Light',
    group: 'Theme',
    shortcut: '⌘⇧D',
    action: () => ui.toggleTheme(),
  },
  // System
  {
    id: 'settings',
    label: 'Open Settings',
    group: 'System',
    shortcut: '⌘,',
    action: () => goto('/settings'),
  },
  {
    id: 'report-bug',
    label: 'Report Bug',
    group: 'System',
    action: () => {
      /* stub */
    },
  },
];

let query = $state('');
let activeIndex = $state(0);

const open = $derived(ui.commandPaletteOpen);

function close(): void {
  ui.closeCommandPalette();
  query = '';
  activeIndex = 0;
}

/** Simple fuzzy match — case-insensitive substring. */
function matches(cmd: Command, q: string): boolean {
  const lower = q.toLowerCase();
  return cmd.label.toLowerCase().includes(lower) || cmd.group.toLowerCase().includes(lower);
}

const filtered = $derived(
  query.trim() === '' ? allCommands : allCommands.filter((c) => matches(c, query.trim()))
);

const grouped = $derived(
  filtered.reduce<Record<string, Command[]>>((acc, cmd) => {
    if (!acc[cmd.group]) {
      acc[cmd.group] = [];
    }
    acc[cmd.group].push(cmd);
    return acc;
  }, {})
);

function execute(cmd: Command): void {
  cmd.action();
  close();
}

function handleKeydown(e: KeyboardEvent): void {
  switch (e.key) {
    case 'ArrowDown':
    case 'j':
      e.preventDefault();
      activeIndex = Math.min(activeIndex + 1, filtered.length - 1);
      break;
    case 'ArrowUp':
    case 'k':
      e.preventDefault();
      activeIndex = Math.max(activeIndex - 1, 0);
      break;
    case 'Enter':
      e.preventDefault();
      if (filtered[activeIndex]) execute(filtered[activeIndex]);
      break;
    case 'Escape':
      e.preventDefault();
      close();
      break;
  }
}

/** Reset active index on query change. */
$effect(() => {
  void query;
  activeIndex = 0;
});

let itemIndex = $state(0);
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
        autofocus
        aria-label="Command search"
        autocomplete="off"
      />
      <Kbd chord="esc" />
    </div>

    <!-- Results -->
    <div class="cnp-cp__results" role="listbox" aria-label="Commands">
      {#if filtered.length === 0}
        <p class="cnp-cp__empty">No commands found.</p>
      {:else}
        {#each Object.entries(grouped) as [groupName, cmds] (groupName)}
          <div class="cnp-cp__group">
            <span class="cnp-cp__group-label">{groupName}</span>
            {#each cmds as cmd (cmd.id)}
              {@const idx = filtered.indexOf(cmd)}
              <button
                class="cnp-cp__item"
                class:cnp-cp__item--active={activeIndex === idx}
                onclick={() => execute(cmd)}
                role="option"
                aria-selected={activeIndex === idx}
                id="cmd-{cmd.id}"
              >
                <span class="cnp-cp__item-label">{cmd.label}</span>
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

  @keyframes cnp-cp-backdrop-fade {
    from { opacity: 0; }
    to { opacity: 1; }
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
