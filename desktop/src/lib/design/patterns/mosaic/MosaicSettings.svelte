<script lang="ts">
  /**
   * MosaicSettings — settings popover for the Mosaic shell.
   * Bound to the mosaicPrefs runes store. CSS prefix: ms-
   *
   * Sections (in order):
   *   1. View as           (single-select Panes / Tabs)
   *   2. Density           (single-select compact ☰ / comfortable / roomy ▦)
   *   3. Pane title as     (single-select command / working_directory / branch)
   *   4. Additional metadata (multi-select branch / working_directory / agent / runtime / model)
   *   5. Show details on hover (toggle)
   *
   * Renders inline (caller wraps it in the foundation `<Popover>`'s children
   * snippet). No own positioning logic — receiver supplies the popover.
   *
   * ARIA:
   *   - role="menu" on root, role="menuitemradio" / "menuitemcheckbox" on options
   *   - Esc closes via `onClose` prop
   *   - Focus is trapped inside the popover (cycles between focusable controls)
   *
   * LOC target: ≤ 240.
   */
  import { onMount, tick } from 'svelte';
  import {
    AlignJustify,
    LayoutGrid,
    Rows,
  } from 'lucide-svelte';
  import {
    mosaicPrefs,
    type MosaicDensity,
    type MosaicMetadataField,
    type MosaicTitleFormat,
    type MosaicViewMode,
  } from '$lib/stores/mosaic-prefs.svelte.js';
  import Toggle from '$lib/design/foundation/toggle/Toggle.svelte';
  import Checkbox from '$lib/design/foundation/checkbox/Checkbox.svelte';

  interface Props {
    /** Called when the user dismisses the popover (Esc key). The host owns open state. */
    onClose?: () => void;
  }

  let { onClose }: Props = $props();

  let rootEl = $state<HTMLDivElement | null>(null);

  // ── Static option tables (single source of truth for labels & a11y) ────────

  const VIEW_MODES: ReadonlyArray<{ value: MosaicViewMode; label: string }> = [
    { value: 'panes', label: 'Panes' },
    { value: 'tabs', label: 'Tabs' },
  ];

  const DENSITIES: ReadonlyArray<{
    value: MosaicDensity;
    label: string;
    icon: typeof AlignJustify;
  }> = [
    { value: 'compact', label: 'Compact list', icon: AlignJustify },
    { value: 'comfortable', label: 'Comfortable', icon: Rows },
    { value: 'roomy', label: 'Roomy grid', icon: LayoutGrid },
  ];

  const TITLE_FORMATS: ReadonlyArray<{ value: MosaicTitleFormat; label: string }> = [
    { value: 'command', label: 'Command' },
    { value: 'working_directory', label: 'Working directory' },
    { value: 'branch', label: 'Branch' },
  ];

  const METADATA_FIELDS: ReadonlyArray<{ value: MosaicMetadataField; label: string }> = [
    { value: 'branch', label: 'Branch' },
    { value: 'working_directory', label: 'Working directory' },
    { value: 'agent', label: 'Agent' },
    { value: 'runtime', label: 'Runtime' },
    { value: 'model', label: 'Model' },
  ];

  // ── Focus trap ─────────────────────────────────────────────────────────────

  function focusables(): HTMLElement[] {
    if (!rootEl) return [];
    const sel =
      'button:not([disabled]), [role="menuitemradio"], [role="menuitemcheckbox"], [role="switch"], [role="checkbox"], input:not([disabled]), [tabindex]:not([tabindex="-1"])';
    return Array.from(rootEl.querySelectorAll<HTMLElement>(sel));
  }

  function handleKeydown(e: KeyboardEvent): void {
    if (e.key === 'Escape') {
      e.preventDefault();
      e.stopPropagation();
      onClose?.();
      return;
    }
    if (e.key !== 'Tab') return;
    const els = focusables();
    if (els.length === 0) return;
    const active = document.activeElement as HTMLElement | null;
    const idx = active ? els.indexOf(active) : -1;
    if (e.shiftKey && (idx <= 0)) {
      e.preventDefault();
      els[els.length - 1].focus();
    } else if (!e.shiftKey && idx === els.length - 1) {
      e.preventDefault();
      els[0].focus();
    }
  }

  onMount(() => {
    void tick().then(() => {
      const els = focusables();
      els[0]?.focus();
    });
  });

  // ── Helpers ────────────────────────────────────────────────────────────────

  function isMetadataChecked(field: MosaicMetadataField): boolean {
    return mosaicPrefs.prefs.metadata_fields.includes(field);
  }
</script>

<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
<div
  bind:this={rootEl}
  class="ms-root"
  role="menu"
  tabindex="-1"
  aria-label="Mosaic display settings"
  onkeydown={handleKeydown}
  data-testid="mosaic-settings"
>
  <!-- 1. View as -->
  <fieldset class="ms-section">
    <legend class="ms-legend">View as</legend>
    <div class="ms-segmented" role="radiogroup" aria-label="View mode">
      {#each VIEW_MODES as opt (opt.value)}
        {@const active = mosaicPrefs.prefs.view_mode === opt.value}
        <button
          type="button"
          role="menuitemradio"
          aria-checked={active}
          class="ms-seg-btn"
          class:ms-seg-btn--active={active}
          data-value={opt.value}
          onclick={() => mosaicPrefs.setViewMode(opt.value)}
        >
          {opt.label}
        </button>
      {/each}
    </div>
  </fieldset>

  <!-- 2. Density -->
  <fieldset class="ms-section">
    <legend class="ms-legend">Density</legend>
    <div class="ms-icon-row" role="radiogroup" aria-label="Density">
      {#each DENSITIES as opt (opt.value)}
        {@const active = mosaicPrefs.prefs.density === opt.value}
        {@const Icon = opt.icon}
        <button
          type="button"
          role="menuitemradio"
          aria-checked={active}
          aria-label={opt.label}
          title={opt.label}
          class="ms-icon-btn"
          class:ms-icon-btn--active={active}
          data-value={opt.value}
          onclick={() => mosaicPrefs.setDensity(opt.value)}
        >
          <Icon size={14} aria-hidden="true" />
        </button>
      {/each}
    </div>
  </fieldset>

  <!-- 3. Pane title as -->
  <fieldset class="ms-section">
    <legend class="ms-legend">Pane title as</legend>
    <div class="ms-stack" role="radiogroup" aria-label="Pane title format">
      {#each TITLE_FORMATS as opt (opt.value)}
        {@const active = mosaicPrefs.prefs.pane_title_format === opt.value}
        <button
          type="button"
          role="menuitemradio"
          aria-checked={active}
          class="ms-stack-row"
          class:ms-stack-row--active={active}
          data-value={opt.value}
          onclick={() => mosaicPrefs.setTitleFormat(opt.value)}
        >
          <span class="ms-radio" aria-hidden="true"></span>
          <span>{opt.label}</span>
        </button>
      {/each}
    </div>
  </fieldset>

  <!-- 4. Additional metadata -->
  <fieldset class="ms-section">
    <legend class="ms-legend">Additional metadata</legend>
    <div class="ms-stack" role="group" aria-label="Additional metadata fields">
      {#each METADATA_FIELDS as opt (opt.value)}
        <label class="ms-stack-row ms-stack-row--check" data-value={opt.value}>
          <Checkbox
            checked={isMetadataChecked(opt.value)}
            label={opt.label}
            onchange={() => mosaicPrefs.toggleMetadataField(opt.value)}
          />
        </label>
      {/each}
    </div>
  </fieldset>

  <!-- 5. Show details on hover -->
  <div class="ms-section ms-section--toggle">
    <Toggle
      checked={mosaicPrefs.prefs.show_details_on_hover}
      label="Show details on hover"
      size="sm"
      onchange={(v) => mosaicPrefs.setShowDetailsOnHover(v)}
    />
  </div>
</div>

<style>
  .ms-root {
    display: flex;
    flex-direction: column;
    gap: 14px;
    min-width: 240px;
    font-family: var(--font-sans);
    color: var(--fg);
  }

  .ms-section {
    border: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .ms-legend {
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--fg-subtle);
    margin: 0 0 2px 0;
    padding: 0;
  }

  /* Segmented control (View as) */
  .ms-segmented {
    display: inline-flex;
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    border-radius: var(--radius-sm, 6px);
    padding: 2px;
    gap: 2px;
    width: fit-content;
  }

  .ms-seg-btn {
    appearance: none;
    border: 0;
    background: transparent;
    color: var(--fg-muted);
    font: inherit;
    font-size: 12px;
    padding: 4px 12px;
    border-radius: 4px;
    cursor: pointer;
    transition: background 0.1s ease, color 0.1s ease;
  }

  .ms-seg-btn:hover { color: var(--fg); }

  .ms-seg-btn--active {
    background: var(--bg);
    color: var(--fg);
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.06);
  }

  .ms-seg-btn:focus-visible {
    outline: 2px solid var(--cnp-accent, oklch(0.72 0.18 145));
    outline-offset: 2px;
  }

  /* Icon row (Density) */
  .ms-icon-row {
    display: inline-flex;
    gap: 4px;
  }

  .ms-icon-btn {
    appearance: none;
    border: 1px solid var(--border);
    background: var(--bg);
    color: var(--fg-muted);
    width: 28px;
    height: 28px;
    border-radius: var(--radius-sm, 6px);
    display: inline-flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: background 0.1s ease, color 0.1s ease, border-color 0.1s ease;
  }

  .ms-icon-btn:hover { color: var(--fg); border-color: color-mix(in oklch, var(--fg) 20%, transparent); }

  .ms-icon-btn--active {
    background: color-mix(in oklch, var(--fg) 10%, transparent);
    color: var(--fg);
    border-color: color-mix(in oklch, var(--fg) 30%, transparent);
  }

  .ms-icon-btn:focus-visible {
    outline: 2px solid var(--cnp-accent, oklch(0.72 0.18 145));
    outline-offset: 2px;
  }

  /* Stack rows (radio + checkbox lists) */
  .ms-stack {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .ms-stack-row {
    appearance: none;
    border: 0;
    background: transparent;
    color: var(--fg);
    font: inherit;
    font-size: 12px;
    padding: 6px 4px;
    border-radius: 4px;
    text-align: left;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 8px;
    transition: background 0.1s ease;
  }

  .ms-stack-row:hover { background: color-mix(in oklch, var(--fg) 6%, transparent); }
  .ms-stack-row--check { padding: 4px; cursor: default; }

  .ms-stack-row:focus-visible {
    outline: 2px solid var(--cnp-accent, oklch(0.72 0.18 145));
    outline-offset: -2px;
  }

  .ms-radio {
    display: inline-block;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    border: 1.5px solid color-mix(in oklch, var(--fg) 35%, transparent);
    flex-shrink: 0;
    position: relative;
    transition: border-color 0.1s ease, background 0.1s ease;
  }

  .ms-stack-row--active .ms-radio {
    border-color: var(--fg);
  }

  .ms-stack-row--active .ms-radio::after {
    content: '';
    position: absolute;
    inset: 2px;
    background: var(--fg);
    border-radius: 50%;
  }

  .ms-section--toggle {
    border-top: 1px solid var(--border);
    padding-top: 10px;
  }
</style>
