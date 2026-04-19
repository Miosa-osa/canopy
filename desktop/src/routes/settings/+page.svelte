<script lang="ts">
/**
 * Settings page — sections: Sidebar customization + Appearance.
 * Sidebar section: show all items (hidden + visible) with reorder + toggle controls.
 * Appearance section: mode toggle (Light/Dark/System) + accent color presets.
 * Changes are live — stores update immediately.
 */

import { ui } from '$lib/stores/ui.svelte.js';
import { sidebarConfig } from '$lib/stores/sidebar-config.svelte.js';
import { theme, ACCENT_PRESETS } from '$lib/stores/theme.svelte.js';

// Per-group collapse state for the settings UI (independent of sidebar collapse).
let groupOpen = $state<Record<string, boolean>>(
  Object.fromEntries(sidebarConfig.config.groups.map((g) => [g.label, true]))
);

function toggleGroup(label: string): void {
  groupOpen[label] = !groupOpen[label];
}
</script>

<div class="stg-page">
  <header class="stg-header">
    <h1 class="stg-title">Settings</h1>
  </header>

  <!-- ── Sidebar section ───────────────────────────────────────────────────── -->
  <section class="stg-section" aria-labelledby="stg-sidebar-heading">
    <div class="stg-section-header">
      <h2 class="stg-section-title" id="stg-sidebar-heading">Sidebar</h2>
      <button
        class="stg-pill-btn"
        onclick={() => sidebarConfig.reset()}
        aria-label="Reset sidebar to defaults"
      >
        Reset to defaults
      </button>
    </div>

    <p class="stg-section-desc">
      Reorder items within each group or hide them from the sidebar. Changes apply immediately.
    </p>

    <div class="stg-groups">
      {#each sidebarConfig.config.groups as group (group.label)}
        <div class="stg-group">
          <!-- Group header (collapsible) -->
          <button
            class="stg-group-header"
            onclick={() => toggleGroup(group.label)}
            aria-expanded={groupOpen[group.label]}
            aria-controls="stg-group-{group.label}"
          >
            <span class="stg-group-label">{group.label}</span>
            <span class="stg-group-chevron" class:stg-group-chevron--open={groupOpen[group.label]}>
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M6 9l6 6 6-6" />
              </svg>
            </span>
          </button>

          {#if groupOpen[group.label]}
            <ul
              class="stg-item-list"
              id="stg-group-{group.label}"
              role="list"
            >
              {#each group.items as item, idx (item.path + item.label)}
                <li
                  class="stg-item"
                  class:stg-item--hidden={item.hidden}
                >
                  <!-- Move up -->
                  <button
                    class="stg-icon-btn"
                    onclick={() => sidebarConfig.moveItemUp(group.label, item.path, item.label)}
                    disabled={idx === 0}
                    aria-label="Move {item.label} up"
                    title="Move up"
                  >
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                      <path d="M12 19V5M5 12l7-7 7 7" />
                    </svg>
                  </button>

                  <!-- Move down -->
                  <button
                    class="stg-icon-btn"
                    onclick={() => sidebarConfig.moveItemDown(group.label, item.path, item.label)}
                    disabled={idx === group.items.length - 1}
                    aria-label="Move {item.label} down"
                    title="Move down"
                  >
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                      <path d="M12 5v14M19 12l-7 7-7-7" />
                    </svg>
                  </button>

                  <!-- Item label -->
                  <span class="stg-item-label">{item.label}</span>

                  <!-- Coming soon badge -->
                  {#if item.comingSoon}
                    <span class="stg-badge-soon" aria-label="Coming soon">soon</span>
                  {/if}

                  <!-- Visibility toggle -->
                  <button
                    class="stg-icon-btn stg-icon-btn--eye"
                    onclick={() => sidebarConfig.toggleHidden(group.label, item.path, item.label)}
                    aria-label={item.hidden ? 'Show {item.label} in sidebar' : 'Hide {item.label} from sidebar'}
                    aria-pressed={item.hidden}
                    title={item.hidden ? 'Show in sidebar' : 'Hide from sidebar'}
                  >
                    {#if item.hidden}
                      <!-- Eye-off -->
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                        <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24" />
                        <line x1="1" y1="1" x2="23" y2="23" />
                      </svg>
                    {:else}
                      <!-- Eye -->
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                        <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                        <circle cx="12" cy="12" r="3" />
                      </svg>
                    {/if}
                  </button>
                </li>
              {/each}
            </ul>
          {/if}
        </div>
      {/each}
    </div>
  </section>

  <!-- ── Appearance section ────────────────────────────────────────────────── -->
  <section class="stg-section" aria-labelledby="stg-appearance-heading">
    <div class="stg-section-header">
      <h2 class="stg-section-title" id="stg-appearance-heading">Appearance</h2>
    </div>

    <!-- Mode toggle -->
    <div class="stg-appearance-row">
      <div class="stg-appearance-label">
        <span class="stg-label-text">Mode</span>
        <span class="stg-label-desc">Light, dark, or follow system preference</span>
      </div>
      <div class="stg-mode-group" role="group" aria-label="Color mode">
        {#each (['light', 'dark', 'system'] as const) as mode}
          <button
            class="stg-mode-btn"
            class:stg-mode-btn--active={theme.mode === mode}
            onclick={() => theme.setMode(mode)}
            aria-pressed={theme.mode === mode}
          >
            {mode.charAt(0).toUpperCase() + mode.slice(1)}
          </button>
        {/each}
      </div>
    </div>

    <!-- Accent color presets -->
    <div class="stg-appearance-row stg-appearance-row--wrap">
      <div class="stg-appearance-label">
        <span class="stg-label-text">Accent color</span>
        <span class="stg-label-desc">Applied to focus rings, active states, and progress</span>
      </div>
      <div class="stg-accent-grid" role="group" aria-label="Accent color presets">
        {#each ACCENT_PRESETS as preset}
          <button
            class="stg-accent-swatch"
            class:stg-accent-swatch--active={theme.accent === preset.value}
            style="background: {preset.value};"
            onclick={() => theme.applyPreset(preset)}
            aria-label="Accent color: {preset.label}"
            aria-pressed={theme.accent === preset.value}
            title={preset.label}
          ></button>
        {/each}
        <!-- Native color picker for custom value -->
        <label class="stg-accent-custom" title="Custom color" aria-label="Custom accent color">
          <input
            type="color"
            class="stg-color-input"
            value="#3b6ef8"
            oninput={(e) => {
              const hex = (e.currentTarget as HTMLInputElement).value;
              theme.setAccent(`color(srgb-linear from ${hex} r g b)`);
            }}
            aria-label="Pick a custom accent color"
          />
          <span class="stg-accent-custom-icon" aria-hidden="true">+</span>
        </label>
      </div>
    </div>
  </section>
</div>

<style>
  .stg-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-8);
    padding: var(--space-8) var(--space-10);
    max-width: 640px;
  }

  .stg-header {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .stg-title {
    font-family: var(--font-sans);
    font-size: var(--text-xl);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
  }

  /* ── Sections ────────────────────────────────────────────────────────────── */

  .stg-section {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }

  .stg-section-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-4);
  }

  .stg-section-title {
    font-family: var(--font-sans);
    font-size: var(--text-base);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
  }

  .stg-section-desc {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
  }

  /* ── Pill button ────────────────────────────────────────────────────────── */

  .stg-pill-btn {
    flex-shrink: 0;
    display: inline-flex;
    align-items: center;
    padding: var(--space-1) var(--space-3);
    border-radius: 9999px;
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    cursor: pointer;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out),
      border-color var(--dur-instant) var(--ease-out);
    white-space: nowrap;
  }

  .stg-pill-btn:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
    border-color: var(--border-strong);
  }

  .stg-pill-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  /* ── Groups ─────────────────────────────────────────────────────────────── */

  .stg-groups {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .stg-group {
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    overflow: hidden;
  }

  .stg-group-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    padding: var(--space-2) var(--space-3);
    border: none;
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.08em;
    color: var(--fg-subtle);
    text-transform: uppercase;
    text-align: left;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .stg-group-header:hover {
    background: color-mix(in oklch, var(--fg) 7%, transparent 93%);
  }

  .stg-group-header:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: -2px;
  }

  .stg-group-chevron {
    color: var(--fg-subtle);
    transform: rotate(-90deg);
    transition: transform var(--dur-instant) var(--ease-out);
  }

  .stg-group-chevron--open {
    transform: rotate(0deg);
  }

  /* ── Item list ──────────────────────────────────────────────────────────── */

  .stg-item-list {
    list-style: none;
    margin: 0;
    padding: var(--space-1);
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .stg-item {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-1) var(--space-2);
    border-radius: var(--radius-sm);
    min-height: 32px;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .stg-item:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }

  .stg-item--hidden .stg-item-label {
    text-decoration: line-through;
    color: var(--fg-subtle);
  }

  .stg-item-label {
    flex: 1;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .stg-badge-soon {
    flex-shrink: 0;
    display: inline-flex;
    align-items: center;
    padding: 0 var(--space-1);
    height: 16px;
    border-radius: var(--radius-sm);
    font-family: var(--font-sans);
    font-size: 9px;
    font-weight: 600;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg-subtle);
  }

  /* ── Icon buttons ───────────────────────────────────────────────────────── */

  .stg-icon-btn {
    flex-shrink: 0;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 22px;
    height: 22px;
    border-radius: var(--radius-sm);
    border: none;
    background: transparent;
    color: var(--fg-subtle);
    cursor: pointer;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .stg-icon-btn:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 10%, transparent 90%);
    color: var(--fg);
  }

  .stg-icon-btn:disabled {
    opacity: 0.25;
    cursor: not-allowed;
  }

  .stg-icon-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  .stg-icon-btn--eye {
    margin-left: auto;
  }

  /* ── Appearance ─────────────────────────────────────────────────────────── */

  .stg-appearance-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-4);
    padding: var(--space-3) var(--space-4);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
  }

  .stg-appearance-row--wrap {
    flex-wrap: wrap;
  }

  .stg-appearance-label {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }

  .stg-label-text {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
  }

  .stg-label-desc {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  /* ── Mode group ─────────────────────────────────────────────────────────── */

  .stg-mode-group {
    display: flex;
    gap: 2px;
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    border-radius: var(--radius-md);
    padding: 2px;
    flex-shrink: 0;
  }

  .stg-mode-btn {
    padding: var(--space-1) var(--space-3);
    border-radius: calc(var(--radius-md) - 2px);
    border: none;
    background: transparent;
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    cursor: pointer;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
    white-space: nowrap;
  }

  .stg-mode-btn:hover:not(.stg-mode-btn--active) {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
  }

  .stg-mode-btn--active {
    background: var(--bg-elevated);
    color: var(--fg);
    box-shadow: 0 1px 3px oklch(0 0 0 / 12%);
  }

  .stg-mode-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  /* ── Accent swatches ────────────────────────────────────────────────────── */

  .stg-accent-grid {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-2);
    align-items: center;
  }

  .stg-accent-swatch {
    width: 22px;
    height: 22px;
    border-radius: 50%;
    border: 2px solid transparent;
    cursor: pointer;
    transition:
      transform var(--dur-instant) var(--ease-out),
      box-shadow var(--dur-instant) var(--ease-out);
    flex-shrink: 0;
  }

  .stg-accent-swatch:hover {
    transform: scale(1.12);
  }

  .stg-accent-swatch--active {
    box-shadow: 0 0 0 2px var(--bg), 0 0 0 4px currentColor;
    outline: none;
  }

  .stg-accent-swatch:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  /* ── Custom color picker ────────────────────────────────────────────────── */

  .stg-accent-custom {
    position: relative;
    width: 22px;
    height: 22px;
    border-radius: 50%;
    border: 1.5px dashed var(--border-strong);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .stg-accent-custom:hover {
    border-color: var(--fg-muted);
  }

  .stg-color-input {
    position: absolute;
    inset: 0;
    opacity: 0;
    width: 100%;
    height: 100%;
    cursor: pointer;
    border: none;
    padding: 0;
  }

  .stg-accent-custom-icon {
    font-size: 14px;
    font-weight: 400;
    line-height: 1;
    color: var(--fg-subtle);
    pointer-events: none;
    user-select: none;
  }
</style>
