<script lang="ts">
  /**
   * SearchSection — cross-file ripgrep search inside the active workspace.
   * CSS prefix: brl-search-.
   *
   * Input + regex/case toggles → fires a debounced TanStack Query.
   * Results grouped by file (groupByFile()). Click a hit → opens a FileViewer
   * pane scoped to that file with the line passed via pane config.
   *
   * If the /search endpoint is missing (404), the query returns
   * { available: false, hits: [] } and we render a "Search backend pending"
   * empty state — the toggles + input still work.
   *
   * LOC target: ≤ 230.
   */
  import {
    type CreateQueryOptions,
    createQuery,
  } from "@tanstack/svelte-query";
  import { Regex, Search, Type } from "lucide-svelte";
  import { untrack } from "svelte";
  import { writable } from "svelte/store";
  import {
    type BackendStatus,
    groupByFile,
    type SearchHit,
    searchQuery,
  } from "$lib/api/queries/search.js";
  import { mosaicLayout, type Pane } from "$lib/stores/mosaic-layout.svelte.js";

  interface Props {
    workspaceSlug: string;
  }

  let { workspaceSlug }: Props = $props();

  // ── Local state ────────────────────────────────────────────────────────────
  let rawInput = $state("");
  let debouncedQ = $state("");
  let useRegex = $state(false);
  let caseSensitive = $state(false);

  type FilterChip = "all" | "files" | "sessions" | "blocks" | "drive";
  let activeFilter = $state<FilterChip>("all");

  const CHIPS: { id: FilterChip; label: string }[] = [
    { id: "all", label: "All" },
    { id: "files", label: "Files" },
    { id: "sessions", label: "Sessions" },
    { id: "blocks", label: "Blocks" },
    { id: "drive", label: "Drive" },
  ];

  // Debounce: 250ms after user stops typing.
  let debounceTimer: ReturnType<typeof setTimeout> | null = null;
  $effect(() => {
    const value = rawInput;
    if (debounceTimer) clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
      debouncedQ = value;
    }, 250);
    return () => {
      if (debounceTimer) clearTimeout(debounceTimer);
    };
  });

  // ── TanStack Query (canonical writable bridge) ─────────────────────────────
  function buildOpts(): CreateQueryOptions<BackendStatus> {
    return searchQuery({
      workspaceSlug,
      q: debouncedQ,
      regex: useRegex,
      caseSensitive,
      limit: 100,
    }) as CreateQueryOptions<BackendStatus>;
  }

  const optsStore = writable(untrack(() => buildOpts()));
  $effect(() => {
    optsStore.set(buildOpts());
  });
  const searchQ = createQuery<BackendStatus>(optsStore);

  const groups = $derived(
    $searchQ.data ? groupByFile($searchQ.data.hits) : [],
  );
  const totalHits = $derived(
    $searchQ.data ? $searchQ.data.hits.length : 0,
  );

  // "files" shows actual results; everything else is future — show "Coming soon".
  const filteredGroups = $derived(
    activeFilter === "all" || activeFilter === "files" ? groups : [],
  );
  const showComingSoon = $derived(
    activeFilter !== "all" && activeFilter !== "files",
  );

  // ── Handlers ───────────────────────────────────────────────────────────────
  function openHit(hit: SearchHit): void {
    const fileName =
      hit.filePath.split("/").pop() ?? hit.filePath;
    const pane: Pane = {
      id: Math.random().toString(36).slice(2, 9),
      kind: "file",
      // Encoded ref includes line for FileViewer dispatcher to pick up.
      ref: `path:${workspaceSlug}:${hit.filePath}#L${hit.lineNumber}`,
      title: `${fileName}:${hit.lineNumber}`,
    };
    mosaicLayout.openPane(pane);
  }

  /** Highlight the matched span inside the line text. */
  function highlightLine(hit: SearchHit): { before: string; match: string; after: string } {
    const before = hit.lineText.slice(0, hit.matchStart);
    const match = hit.lineText.slice(hit.matchStart, hit.matchEnd);
    const after = hit.lineText.slice(hit.matchEnd);
    return { before, match, after };
  }
</script>

<div class="brl-search">
  <header class="brl-search__header">
    <span class="brl-search__title">Search</span>
    {#if totalHits > 0}
      <span class="brl-search__count">{totalHits}</span>
    {/if}
  </header>

  <div class="brl-search__controls">
    <div class="brl-search__input-wrap">
      <span class="brl-search__icon" aria-hidden="true">
        <Search size={12} />
      </span>
      <input
        type="search"
        class="brl-search__input"
        placeholder="Search files…"
        bind:value={rawInput}
        aria-label="Search across files"
      />
    </div>

    <div class="brl-search__toggles" role="group" aria-label="Search options">
      <button
        type="button"
        class="brl-search__toggle"
        class:brl-search__toggle--active={caseSensitive}
        aria-pressed={caseSensitive}
        title="Match case (Aa)"
        onclick={() => (caseSensitive = !caseSensitive)}
      >
        <Type size={12} aria-hidden="true" />
      </button>
      <button
        type="button"
        class="brl-search__toggle"
        class:brl-search__toggle--active={useRegex}
        aria-pressed={useRegex}
        title="Use regular expression (.*)"
        onclick={() => (useRegex = !useRegex)}
      >
        <Regex size={12} aria-hidden="true" />
      </button>
    </div>
  </div>

  <div class="brl-search__chips" role="group" aria-label="Filter results by type">
    {#each CHIPS as chip (chip.id)}
      <button
        type="button"
        class="brl-search__chip"
        class:brl-search__chip--active={activeFilter === chip.id}
        aria-pressed={activeFilter === chip.id}
        onclick={() => (activeFilter = chip.id)}
      >
        {chip.label}
      </button>
    {/each}
  </div>

  <div class="brl-search__body">
    {#if debouncedQ.trim().length === 0}
      <div class="brl-search__empty">Type to search across files</div>
    {:else if $searchQ.isLoading}
      <div class="brl-search__empty">Searching…</div>
    {:else if $searchQ.isError}
      <div class="brl-search__error">Search failed</div>
    {:else if $searchQ.data && !$searchQ.data.available}
      <div class="brl-search__empty">Search backend pending</div>
    {:else if showComingSoon}
      <div class="brl-search__empty">Coming soon</div>
    {:else if filteredGroups.length === 0}
      <div class="brl-search__empty">No matches</div>
    {:else}
      <ul class="brl-search__groups" role="list">
        {#each filteredGroups as group (group.filePath)}
          <li class="brl-search__group">
            <div class="brl-search__file" title={group.filePath}>
              {group.filePath}
              <span class="brl-search__file-count">{group.hits.length}</span>
            </div>
            <ul class="brl-search__hits" role="list">
              {#each group.hits as hit, i (i)}
                {@const parts = highlightLine(hit)}
                <li>
                  <button
                    type="button"
                    class="brl-search__hit"
                    onclick={() => openHit(hit)}
                  >
                    <span class="brl-search__line">{hit.lineNumber}</span>
                    <span class="brl-search__text">
                      <span>{parts.before}</span><mark
                        class="brl-search__mark">{parts.match}</mark><span
                        >{parts.after}</span
                      >
                    </span>
                  </button>
                </li>
              {/each}
            </ul>
          </li>
        {/each}
      </ul>
    {/if}
  </div>
</div>

<style>
  .brl-search {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  .brl-search__header {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    padding: 10px var(--space-3) 6px;
    border-bottom: 1px solid var(--border, rgba(0, 0, 0, 0.08));
  }

  .brl-search__title {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    color: var(--fg-muted);
    letter-spacing: 0.04em;
    text-transform: uppercase;
  }

  .brl-search__count {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .brl-search__controls {
    padding: var(--space-2);
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .brl-search__input-wrap {
    position: relative;
  }

  .brl-search__icon {
    position: absolute;
    left: 8px;
    top: 50%;
    transform: translateY(-50%);
    color: var(--fg-subtle);
    pointer-events: none;
  }

  .brl-search__input {
    width: 100%;
    height: 28px;
    padding: 0 var(--space-2) 0 26px;
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--fg);
    background: var(--bg-inset, rgba(0, 0, 0, 0.04));
    border: 1px solid var(--border, rgba(0, 0, 0, 0.08));
    border-radius: var(--radius-sm, 4px);
    outline: none;
  }

  .brl-search__input:focus-visible {
    border-color: var(--cnp-accent, #1e96eb);
  }

  .brl-search__toggles {
    display: flex;
    gap: var(--space-1, 4px);
  }

  .brl-search__toggle {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 26px;
    height: 22px;
    border: 1px solid var(--border, rgba(0, 0, 0, 0.08));
    background: transparent;
    color: var(--fg-subtle);
    border-radius: var(--radius-sm, 4px);
    cursor: pointer;
    transition: all 80ms ease-out;
  }

  .brl-search__toggle:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .brl-search__toggle--active {
    background: color-mix(in oklch, var(--cnp-accent, #1e96eb) 14%, transparent 86%);
    border-color: var(--cnp-accent, #1e96eb);
    color: var(--fg);
  }

  .brl-search__chips {
    display: flex;
    flex-wrap: nowrap;
    gap: var(--space-1, 4px);
    padding: 0 var(--space-2) var(--space-2);
    overflow-x: auto;
    scrollbar-width: none;
  }

  .brl-search__chips::-webkit-scrollbar {
    display: none;
  }

  .brl-search__chip {
    flex-shrink: 0;
    display: inline-flex;
    align-items: center;
    height: 20px;
    padding: 0 8px;
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 500;
    color: var(--fg-muted);
    background: transparent;
    border: 1px solid var(--border, rgba(0, 0, 0, 0.08));
    border-radius: var(--radius-sm, 4px);
    cursor: pointer;
    transition: all 80ms ease-out;
    white-space: nowrap;
  }

  .brl-search__chip:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .brl-search__chip--active {
    background: var(--cnp-accent, #1e96eb);
    border-color: var(--cnp-accent, #1e96eb);
    color: #fff;
  }

  .brl-search__chip--active:hover {
    background: color-mix(in oklch, var(--cnp-accent, #1e96eb) 90%, black 10%);
    color: #fff;
  }

  .brl-search__body {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
  }

  .brl-search__empty,
  .brl-search__error {
    padding: var(--space-6) var(--space-3);
    text-align: center;
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
  }

  .brl-search__error {
    color: var(--signal-error, #eb4335);
  }

  .brl-search__groups {
    list-style: none;
    margin: 0;
    padding: 0;
  }

  .brl-search__group {
    border-bottom: 1px solid var(--border, rgba(0, 0, 0, 0.06));
  }

  .brl-search__file {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-2);
    padding: 6px var(--space-3);
    font-family: var(--font-mono);
    font-size: 11px;
    font-weight: 500;
    color: var(--fg-muted);
    background: var(--bg-inset, rgba(0, 0, 0, 0.02));
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .brl-search__file-count {
    flex-shrink: 0;
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .brl-search__hits {
    list-style: none;
    margin: 0;
    padding: 0;
  }

  .brl-search__hit {
    display: flex;
    gap: var(--space-2);
    width: 100%;
    padding: 4px var(--space-3) 4px var(--space-4);
    border: none;
    background: transparent;
    text-align: left;
    color: var(--fg-muted);
    font-family: var(--font-mono);
    font-size: 11px;
    cursor: pointer;
  }

  .brl-search__hit:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .brl-search__line {
    flex-shrink: 0;
    width: 32px;
    color: var(--fg-subtle);
    text-align: right;
  }

  .brl-search__text {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .brl-search__mark {
    background: color-mix(in oklch, var(--cnp-accent, #1e96eb) 30%, transparent 70%);
    color: var(--fg);
    border-radius: 2px;
    padding: 0 1px;
  }
</style>
