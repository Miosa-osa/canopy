<script lang="ts">
  /**
   * FileSearchBar — top-bar search input for the /files project explorer.
   * CSS prefix: fsb- (File Search Bar).
   *
   * Behaviour:
   *   • Text input that shows the live query (no live-search — debouncing
   *     is irrelevant here because we hand off to the global keyword-search
   *     dialog).
   *   • Enter or click the magnifier → opens the global keyword-search
   *     overlay scoped to the active workspace via `ui.openKeywordSearch()`
   *     (the overlay reads `activeWorkspace.slug` for its scope).
   *   • Cmd/Ctrl+P or "/" inside the input also opens the dialog.
   *
   * No new fetcher — the actual search lives in KeywordSearchDialog.
   *
   * LOC target: ≤ 150.
   */
  import { Search } from "lucide-svelte";
  import { ui } from "$lib/stores/ui.svelte.js";

  interface Props {
    workspaceSlug: string | null;
    placeholder?: string;
  }

  let {
    workspaceSlug,
    placeholder = "Search files in this workspace…",
  }: Props = $props();

  let query = $state("");

  function openOverlay(): void {
    if (!workspaceSlug) return;
    ui.openKeywordSearch();
  }

  function onKeydown(ev: KeyboardEvent): void {
    if (ev.key === "Enter") {
      ev.preventDefault();
      openOverlay();
    } else if (ev.key === "Escape") {
      query = "";
    }
  }
</script>

<div class="fsb" role="search">
  <button
    type="button"
    class="fsb__icon"
    aria-label="Open workspace search"
    onclick={openOverlay}
    disabled={!workspaceSlug}
    title="Open keyword search (⌘K)"
  >
    <Search size={13} aria-hidden="true" />
  </button>
  <input
    class="fsb__input"
    type="search"
    bind:value={query}
    onkeydown={onKeydown}
    placeholder={workspaceSlug ? placeholder : "Select a workspace to search…"}
    aria-label="Search files"
    spellcheck={false}
    autocomplete="off"
    disabled={!workspaceSlug}
  />
  <span class="fsb__hint" aria-hidden="true">↵ to open search</span>
</div>

<style>
  .fsb {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    width: 100%;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 2px var(--space-2);
    transition: border-color var(--dur-instant, 80ms) var(--ease-out, ease-out);
  }

  .fsb:focus-within {
    border-color: var(--border-strong, var(--cnp-accent, #6e8df1));
  }

  .fsb__icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    background: transparent;
    border: none;
    padding: 4px;
    color: var(--fg-subtle);
    cursor: pointer;
    border-radius: var(--radius-sm);
    transition: color 80ms ease-out;
  }

  .fsb__icon:hover:not(:disabled) {
    color: var(--fg);
  }

  .fsb__icon:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .fsb__input {
    flex: 1;
    background: transparent;
    border: none;
    outline: none;
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--fg);
    padding: 4px 0;
    min-width: 0;
  }

  .fsb__input::placeholder {
    color: var(--fg-subtle);
  }

  .fsb__input:disabled {
    cursor: not-allowed;
  }

  .fsb__hint {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    white-space: nowrap;
    flex-shrink: 0;
  }

  @media (max-width: 640px) {
    .fsb__hint { display: none; }
  }
</style>
