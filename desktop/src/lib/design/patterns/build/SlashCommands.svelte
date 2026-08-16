<script lang="ts" module>
  /**
   * Pure helpers — extracted so vitest can test them in a Node project
   * without spinning up a Svelte renderer.
   */
  import {
    type BuildCommand,
    FALLBACK_BUILTINS,
    groupBySource,
  } from '$lib/api/queries/build-commands.js';

  export type { BuildCommand } from '$lib/api/queries/build-commands.js';

  /**
   * Filter a command list by a free-text query (case-insensitive substring
   * on `name + description`). Server-side filtering already runs via `?q=`,
   * but we re-apply on the client so an additional keystroke is responsive
   * before the next round-trip lands.
   */
  export function filterCommands(
    commands: readonly BuildCommand[],
    query: string,
  ): BuildCommand[] {
    const q = query.trim().toLowerCase();
    if (!q) return [...commands];
    return commands.filter(
      (c) =>
        c.name.toLowerCase().includes(q) ||
        c.description.toLowerCase().includes(q),
    );
  }

  /**
   * Re-export the bucket helper so the palette template can lay rows out
   * by source (BUILT-IN / RUNTIMES / DRIVE / TEMPLATES / SKILLS).
   */
  export { groupBySource, FALLBACK_BUILTINS };
</script>

<script lang="ts">
  /**
   * SlashCommands — inline command palette that appears in the Build
   * composer when the input starts with `/`.
   *
   * Commands are aggregated server-side from five sources:
   *   builtin → runtime → drive_workflow → drive_prompt → template → skill
   *
   * Each source becomes its own group in the dropdown. Filter narrows
   * across all groups; ↑/↓ navigates the flattened ordered list; Enter
   * picks the active row; Esc dismisses.
   *
   * Loading state shows a one-line shimmer. Error state falls back to the
   * canonical 10 built-ins so the palette never renders empty on a network
   * blip.
   *
   * REUSE — talks to `commandsQuery()` (no new fetcher); `groupBySource`
   * lives in the query factory module and is reused 1:1 here.
   *
   * CSS prefix: bld-slash-
   */
  import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
  import {
    BookOpen,
    Bot,
    FileText,
    GitBranch,
    GitCommit,
    History,
    LayoutTemplate,
    type Icon as LucideIcon,
    MessageCircle,
    Plug,
    Plus,
    Sparkles,
    Wand2,
    Zap,
  } from 'lucide-svelte';
  import { untrack } from 'svelte';
  import { writable } from 'svelte/store';
  import {
    commandsQuery,
  } from '$lib/api/queries/build-commands.js';

  interface Props {
    /** Substring after the leading `/` typed into the composer. */
    query: string;
    /** Fires with the canonical command form (e.g. `"/agent "`). */
    onpick: (command: string, item?: BuildCommand) => void;
  }

  let { query, onpick }: Props = $props();

  // ── Query the multi-source registry ────────────────────────────────────────
  // Re-issue the server query as the user types. We rely on TanStack Query's
  // 30s `staleTime` (set in the factory) to keep churn minimal — typical
  // typing only invalidates the in-memory cache, not network.
  const optsStore = writable(
    untrack(() =>
      commandsQuery({ q: query }) as CreateQueryOptions<BuildCommand[]>,
    ),
  );
  $effect(() => {
    optsStore.set(
      commandsQuery({ q: query }) as CreateQueryOptions<BuildCommand[]>,
    );
  });
  const cmdsQ = createQuery<BuildCommand[]>(optsStore);

  // Local aliases so Svelte's derived declarations can reference stable
  // instance-scope bindings.
  const groupBySourceLocal = groupBySource;
  const filterCommandsLocal = filterCommands;
  const FALLBACK_BUILTINS_LOCAL = FALLBACK_BUILTINS;

  /** Final list after the network response — falls back to built-ins on error. */
  const commands = $derived<BuildCommand[]>(
    $cmdsQ.isError ? [...FALLBACK_BUILTINS_LOCAL] : ($cmdsQ.data ?? []),
  );

  /** Local re-filter as a hedge while a new server query is in-flight. */
  const filtered = $derived<BuildCommand[]>(
    filterCommandsLocal(commands, query),
  );

  /** Bucket by source for grouped display. */
  const groups = $derived(groupBySourceLocal(filtered));

  /** Flat list — drives ↑/↓ keyboard nav across groups. */
  const flat = $derived<BuildCommand[]>(groups.flatMap((g) => g.items));

  // ── Keyboard nav ───────────────────────────────────────────────────────────
  let activeIdx = $state(0);

  // Reset cursor when filter changes its result set length (avoid OOB).
  $effect(() => {
    if (activeIdx >= flat.length) {
      activeIdx = Math.max(0, flat.length - 1);
    }
  });

  function handleKeydown(e: KeyboardEvent): void {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      activeIdx = Math.min(activeIdx + 1, flat.length - 1);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      activeIdx = Math.max(activeIdx - 1, 0);
    } else if (e.key === 'Enter' && flat[activeIdx]) {
      e.preventDefault();
      onpick(`${flat[activeIdx].name} `, flat[activeIdx]);
    }
  }

  // ── Icon resolution ────────────────────────────────────────────────────────
  // We can't ship every lucide icon — pick a small lookup table for the icons
  // the backend actually emits. Unknown names fall back to a sensible default.
  const ICONS: Record<string, typeof LucideIcon> = {
    Bot,
    Sparkles,
    FileText,
    History,
    Wand2,
    Plus,
    BookOpen,
    Plug,
    GitBranch,
    MessageCircle,
    GitCommit,
    LayoutTemplate,
    Zap,
  };

  function resolveIcon(name: string): typeof LucideIcon {
    return ICONS[name] ?? Bot;
  }

  /** Flat row index for a row in `groups[gi].items[ii]` — needed for highlight. */
  function flatIndex(gi: number, ii: number): number {
    let n = 0;
    for (let i = 0; i < gi; i++) n += groups[i].items.length;
    return n + ii;
  }
</script>

<svelte:window onkeydown={handleKeydown} />

{#if $cmdsQ.isLoading}
  <div class="bld-slash-panel" role="status" aria-busy="true" aria-label="Loading commands">
    <div class="bld-slash-shimmer">
      <span class="bld-slash-shimmer-row"></span>
      <span class="bld-slash-shimmer-row"></span>
      <span class="bld-slash-shimmer-row"></span>
    </div>
  </div>
{:else if flat.length > 0}
  <div class="bld-slash-panel" role="listbox" aria-label="Slash commands">
    {#each groups as group, gi (group.source)}
      <div class="bld-slash-heading">{group.label}</div>
      <ul class="bld-slash-list">
        {#each group.items as cmd, ii (cmd.source + ':' + cmd.name)}
          {@const idx = flatIndex(gi, ii)}
          {@const ActiveIcon = resolveIcon(cmd.icon)}
          <li>
            <button
              type="button"
              class="bld-slash-row"
              class:active={idx === activeIdx}
              role="option"
              aria-selected={idx === activeIdx}
              onclick={() => onpick(`${cmd.name} `, cmd)}
              onmouseenter={() => (activeIdx = idx)}
            >
              <span class="bld-slash-icon">
                <ActiveIcon size={14} aria-hidden="true" />
              </span>
              <span class="bld-slash-name">{cmd.name}</span>
              <span class="bld-slash-desc">{cmd.description}</span>
            </button>
          </li>
        {/each}
      </ul>
    {/each}
    <div class="bld-slash-hint">
      <kbd>↑</kbd> <kbd>↓</kbd> to navigate · <kbd>esc</kbd> to dismiss
    </div>
  </div>
{/if}

<style>
  .bld-slash-panel {
    position: absolute;
    bottom: 100%;
    left: 12px;
    right: 12px;
    margin-bottom: 4px;
    background: var(--cnp-bg-elev, var(--bg-elevated));
    border: 1px solid var(--cnp-border, var(--border));
    border-radius: 8px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
    overflow: hidden;
    z-index: 30;
  }

  .bld-slash-heading {
    padding: 0.5rem 0.75rem;
    font-size: 0.7rem;
    font-weight: 500;
    color: var(--cnp-fg-muted, var(--fg-muted));
    text-transform: uppercase;
    letter-spacing: 0.08em;
    border-bottom: 1px solid var(--cnp-border, var(--border));
  }

  .bld-slash-list {
    list-style: none;
    margin: 0;
    padding: 0.25rem 0;
    max-height: 280px;
    overflow-y: auto;
  }

  .bld-slash-row {
    display: grid;
    grid-template-columns: 24px 160px 1fr;
    align-items: center;
    gap: 0.5rem;
    width: 100%;
    padding: 0.4rem 0.75rem;
    background: transparent;
    border: 0;
    color: var(--cnp-fg, var(--fg));
    font-family: inherit;
    font-size: 0.85rem;
    text-align: left;
    cursor: pointer;
  }

  .bld-slash-row.active {
    background: var(--cnp-bg, var(--bg));
  }

  .bld-slash-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    color: var(--cnp-fg-muted, var(--fg-muted));
  }

  .bld-slash-name {
    font-family: ui-monospace, monospace;
    font-size: 0.85rem;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .bld-slash-desc {
    color: var(--cnp-fg-muted, var(--fg-muted));
    font-size: 0.8rem;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .bld-slash-hint {
    padding: 0.4rem 0.75rem;
    font-size: 0.7rem;
    color: var(--cnp-fg-muted, var(--fg-muted));
    border-top: 1px solid var(--cnp-border, var(--border));
  }

  .bld-slash-hint kbd {
    background: var(--cnp-border, var(--border));
    padding: 0.1rem 0.3rem;
    border-radius: 3px;
    font-size: 0.65rem;
    font-family: ui-monospace, monospace;
  }

  .bld-slash-shimmer {
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding: 10px 12px;
  }

  .bld-slash-shimmer-row {
    height: 12px;
    border-radius: 4px;
    background: linear-gradient(
      90deg,
      color-mix(in oklch, var(--fg, #fff) 6%, transparent) 0%,
      color-mix(in oklch, var(--fg, #fff) 14%, transparent) 50%,
      color-mix(in oklch, var(--fg, #fff) 6%, transparent) 100%
    );
    background-size: 200% 100%;
    animation: bld-slash-shimmer 1.4s ease-in-out infinite;
  }

  @keyframes bld-slash-shimmer {
    0% { background-position: 200% 0; }
    100% { background-position: -200% 0; }
  }
</style>
