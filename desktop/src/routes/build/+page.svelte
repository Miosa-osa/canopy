<script lang="ts">
  /**
   * /build — Warp-like terminal workspace.
   *
   * Layout:
   *   ┌──────────┬────────────────────────────────────────┐
   *   │          │  Tab strip (MosaicRoot)                │
   *   │ SideRail ├────────────────────────────────────────┤
   *   │          │  Terminal / conversation panes          │
   *   │          │   — composer is per-pane, not global    │
   *   └──────────┴────────────────────────────────────────┘
   *
   * On first mount with an empty layout, seeds one conversation pane.
   * CSS prefix: bld-
   */
  import { Search } from 'lucide-svelte';
  import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
  import { onMount, untrack } from 'svelte';
  import { writable } from 'svelte/store';
  import BuildSideRail from '$lib/design/patterns/build/BuildSideRail.svelte';
  import MosaicRoot from '$lib/design/patterns/mosaic/MosaicRoot.svelte';
  import { defaultLayoutQuery } from '$lib/api/queries/build.js';
  import type { BuildLayout } from '$lib/domain/build/types.js';
  import { ui } from '$lib/stores/ui.svelte.js';
  import { mosaicLayout } from '$lib/stores/mosaic-layout.svelte.js';
  import { activeWorkspace } from '$lib/stores/active-workspace.svelte.js';

  const workspaceSlug = $derived(activeWorkspace.slug ?? 'default');

  const defaultOptsStore = writable(
    untrack(() => defaultLayoutQuery(workspaceSlug) as CreateQueryOptions<BuildLayout | null>),
  );
  $effect(() => {
    defaultOptsStore.set(
      defaultLayoutQuery(workspaceSlug) as CreateQueryOptions<BuildLayout | null>,
    );
  });
  const defaultQ = createQuery<BuildLayout | null>(defaultOptsStore);
  const defaultLayout = $derived<BuildLayout | null>(
    ($defaultQ.data ?? null) as BuildLayout | null,
  );

  onMount(() => {
    seedIfEmpty();
  });

  function seedIfEmpty(): void {
    const tiles = mosaicLayout.allTiles();
    const totalPanes = tiles.reduce((acc, t) => acc + t.panes.length, 0);
    if (totalPanes === 0) {
      mosaicLayout.openPane({
        id: Math.random().toString(36).slice(2, 9),
        kind: 'agent_conversation',
        ref: 'new',
        title: 'New conversation',
        config: {
          cwd: activeWorkspace.rootPath ?? '~',
        },
      });
    }
  }

  function handleGlobalSearchKeydown(e: KeyboardEvent): void {
    if (e.key === 'Enter') {
      ui.openKeywordSearch();
    }
  }
</script>

<div class="bld-cockpit" data-default-layout={defaultLayout?.slug ?? ''}>
  <header class="bld-topbar" aria-label="Build top bar">
    <button
      type="button"
      class="bld-search"
      onclick={() => ui.openKeywordSearch()}
      onkeydown={handleGlobalSearchKeydown}
      aria-label="Search sessions, agents, files"
    >
      <Search size={13} aria-hidden="true" />
      <span class="bld-search__placeholder">Search sessions, agents, files…</span>
      <kbd class="bld-search__kbd">⌘/</kbd>
    </button>
  </header>

  <aside class="bld-rail" aria-label="Build side rail">
    <BuildSideRail {workspaceSlug} />
  </aside>

  <section class="bld-main" aria-label="Build mosaic workspace">
    <MosaicRoot {workspaceSlug} />
  </section>
</div>

<style>
  .bld-cockpit {
    display: grid;
    grid-template-columns: minmax(60px, auto) 1fr;
    grid-template-rows: auto 1fr;
    grid-template-areas:
      'topbar topbar'
      'rail   main';
    width: 100%;
    height: 100%;
    min-height: 0;
    overflow: hidden;
    background: var(--cnp-bg, var(--bg));
  }

  .bld-topbar {
    grid-area: topbar;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 8px 12px;
    border-bottom: 1px solid var(--cnp-border, var(--border));
    background: var(--cnp-bg-elev, var(--bg-elevated));
  }

  .bld-search {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    width: min(420px, 50%);
    padding: 0.4rem 0.75rem;
    background: var(--cnp-bg, transparent);
    border: 1px solid var(--cnp-border, var(--border));
    border-radius: 6px;
    color: var(--cnp-fg-muted, var(--fg-muted));
    font-size: 0.8rem;
    font-family: inherit;
    cursor: text;
    transition: border-color 0.15s, color 0.15s;
  }

  .bld-search:hover {
    border-color: var(--cnp-fg-muted, var(--fg-muted));
    color: var(--cnp-fg, var(--fg));
  }

  .bld-search__placeholder {
    flex: 1;
    text-align: left;
  }

  .bld-search__kbd {
    background: var(--cnp-border, var(--border));
    padding: 0.1rem 0.35rem;
    border-radius: 3px;
    font-size: 0.7rem;
    font-family: ui-monospace, monospace;
  }

  .bld-rail {
    grid-area: rail;
    border-right: 1px solid var(--cnp-border, var(--border));
    overflow: hidden;
    min-height: 0;
  }

  .bld-main {
    grid-area: main;
    display: flex;
    flex-direction: column;
    min-height: 0;
    overflow: hidden;
  }
</style>
