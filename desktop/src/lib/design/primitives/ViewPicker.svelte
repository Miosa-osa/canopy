<script lang="ts">
/**
 * ViewPicker — layout / density / sort controls for list pages.
 *
 * CSS prefix: vp-
 * Three inline control groups:
 *   Layout  — Grid | List | (Board, when boardEnabled=true)
 *   Density — Compact | Comfortable | Roomy
 *   Sort    — configurable per-page via sortOptions prop
 *
 * State is persisted per-route in localStorage under `canopy.view.<routeSlug>`.
 */

export type ViewLayout = 'grid' | 'list' | 'board';
export type ViewDensity = 'compact' | 'comfortable' | 'roomy';
export type ViewSort = string; // caller defines valid values via sortOptions

export interface SortOption {
  value: ViewSort;
  label: string;
}

export interface ViewState {
  layout: ViewLayout;
  density: ViewDensity;
  sort: ViewSort;
}

interface Props {
  /** localStorage key suffix — use the route slug, e.g. "sessions". */
  routeSlug: string;
  /** Current view state (bindable). */
  view: ViewState;
  /** Whether the Board layout option is available. Default false. */
  boardEnabled?: boolean;
  /** Sort options available for this page. */
  sortOptions?: SortOption[];
}

const DEFAULT_SORT_OPTIONS: SortOption[] = [
  { value: 'recent', label: 'Recent' },
  { value: 'oldest', label: 'Oldest' },
  { value: 'name_asc', label: 'Name A–Z' },
  { value: 'name_desc', label: 'Name Z–A' },
  { value: 'status', label: 'Status' },
];

let {
  routeSlug,
  view = $bindable(),
  boardEnabled = false,
  sortOptions = DEFAULT_SORT_OPTIONS,
}: Props = $props();

const LS_KEY = `canopy.view.${routeSlug}`;

// Load persisted state once on mount.
$effect(() => {
  if (typeof localStorage === 'undefined') return;
  try {
    const raw = localStorage.getItem(LS_KEY);
    if (!raw) return;
    const saved = JSON.parse(raw) as Partial<ViewState>;
    view = {
      layout: saved.layout ?? view.layout,
      density: saved.density ?? view.density,
      sort: saved.sort ?? view.sort,
    };
  } catch {
    // corrupt storage — ignore
  }
});

// Persist on every change.
$effect(() => {
  if (typeof localStorage === 'undefined') return;
  try {
    localStorage.setItem(LS_KEY, JSON.stringify(view));
  } catch {
    // quota exceeded — ignore
  }
});

function setLayout(l: ViewLayout): void {
  view = { ...view, layout: l };
}
function setDensity(d: ViewDensity): void {
  view = { ...view, density: d };
}
function setSort(s: ViewSort): void {
  view = { ...view, sort: s };
}

const LAYOUT_OPTIONS: Array<{ value: ViewLayout; label: string }> = [
  { value: 'list', label: 'List' },
  { value: 'grid', label: 'Grid' },
  ...(boardEnabled ? [{ value: 'board' as ViewLayout, label: 'Board' }] : []),
];

const DENSITY_OPTIONS: Array<{ value: ViewDensity; label: string }> = [
  { value: 'compact', label: 'Compact' },
  { value: 'comfortable', label: 'Comfortable' },
  { value: 'roomy', label: 'Roomy' },
];
</script>

<div class="vp-root" role="toolbar" aria-label="View options">
  <!-- Layout toggle -->
  <div class="vp-group" role="group" aria-label="Layout">
    {#each LAYOUT_OPTIONS as opt (opt.value)}
      <button
        class="vp-btn"
        class:vp-btn--active={view.layout === opt.value}
        onclick={() => setLayout(opt.value)}
        aria-pressed={view.layout === opt.value}
        aria-label="Layout: {opt.label}"
      >
        {opt.label}
      </button>
    {/each}
  </div>

  <span class="vp-sep" aria-hidden="true"></span>

  <!-- Density toggle -->
  <div class="vp-group" role="group" aria-label="Density">
    {#each DENSITY_OPTIONS as opt (opt.value)}
      <button
        class="vp-btn"
        class:vp-btn--active={view.density === opt.value}
        onclick={() => setDensity(opt.value)}
        aria-pressed={view.density === opt.value}
        aria-label="Density: {opt.label}"
      >
        {opt.label}
      </button>
    {/each}
  </div>

  <span class="vp-sep" aria-hidden="true"></span>

  <!-- Sort dropdown -->
  <select
    class="vp-sort"
    value={view.sort}
    onchange={(e) => setSort((e.currentTarget as HTMLSelectElement).value)}
    aria-label="Sort order"
  >
    {#each sortOptions as opt (opt.value)}
      <option value={opt.value}>{opt.label}</option>
    {/each}
  </select>
</div>

<style>
  .vp-root {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
  }

  .vp-group {
    display: flex;
    align-items: center;
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    border-radius: var(--radius-md);
    padding: 2px;
    gap: 1px;
  }

  .vp-btn {
    padding: 3px 8px;
    border: none;
    background: transparent;
    border-radius: var(--radius-sm);
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 500;
    color: var(--fg-muted);
    cursor: pointer;
    white-space: nowrap;
    transition: background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .vp-btn:hover {
    color: var(--fg);
  }

  .vp-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  .vp-btn--active {
    background: var(--bg-elevated);
    color: var(--fg);
  }

  .vp-sep {
    display: block;
    width: 1px;
    height: 16px;
    background: var(--border);
    flex-shrink: 0;
  }

  .vp-sort {
    font-size: 11px;
    font-family: var(--font-sans);
    color: var(--fg);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 3px 6px;
    outline: none;
    cursor: pointer;
  }

  .vp-sort:focus-visible {
    border-color: var(--cnp-accent);
  }

  @media (prefers-reduced-motion: reduce) {
    .vp-btn {
      transition: none;
    }
  }
</style>
