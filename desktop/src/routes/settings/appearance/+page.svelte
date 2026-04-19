<script lang="ts">
/**
 * Settings › Appearance — mode toggle (Light/Dark/System) + accent color presets.
 * Moved from the monolithic /settings/+page.svelte. Logic unchanged.
 */

import { ACCENT_PRESETS, theme } from '$lib/stores/theme.svelte.js';
</script>

<div class="ap-page">
  <!-- Mode toggle -->
  <div class="ap-row">
    <div class="ap-label-col">
      <span class="ap-label">Mode</span>
      <span class="ap-label-desc">Light, dark, or follow system preference</span>
    </div>
    <div class="ap-mode-group" role="group" aria-label="Color mode">
      {#each (['light', 'dark', 'system'] as const) as mode}
        <button
          class="ap-mode-btn"
          class:ap-mode-btn--active={theme.mode === mode}
          onclick={() => theme.setMode(mode)}
          aria-pressed={theme.mode === mode}
        >
          {mode.charAt(0).toUpperCase() + mode.slice(1)}
        </button>
      {/each}
    </div>
  </div>

  <!-- Accent color presets -->
  <div class="ap-row ap-row--wrap">
    <div class="ap-label-col">
      <span class="ap-label">Accent color</span>
      <span class="ap-label-desc">Applied to focus rings, active states, and progress</span>
    </div>
    <div class="ap-accent-grid" role="group" aria-label="Accent color presets">
      {#each ACCENT_PRESETS as preset}
        <button
          class="ap-swatch"
          class:ap-swatch--active={theme.accent === preset.value}
          style="background: {preset.value};"
          onclick={() => theme.applyPreset(preset)}
          aria-label="Accent color: {preset.label}"
          aria-pressed={theme.accent === preset.value}
          title={preset.label}
        ></button>
      {/each}
      <label class="ap-custom" title="Custom color" aria-label="Custom accent color">
        <input
          type="color"
          class="ap-color-input"
          value="#3b6ef8"
          oninput={(e) => {
            const hex = (e.currentTarget as HTMLInputElement).value;
            theme.setAccent(`color(srgb-linear from ${hex} r g b)`);
          }}
          aria-label="Pick a custom accent color"
        />
        <span class="ap-custom-icon" aria-hidden="true">+</span>
      </label>
    </div>
  </div>
</div>

<style>
  .ap-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    max-width: 720px;
  }

  /* ── Row ─────────────────────────────────────────────────────────────────── */

  .ap-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-4);
    padding: var(--space-3) var(--space-4);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
  }

  .ap-row--wrap {
    flex-wrap: wrap;
  }

  .ap-label-col {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }

  .ap-label {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
  }

  .ap-label-desc {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  /* ── Mode group ──────────────────────────────────────────────────────────── */

  .ap-mode-group {
    display: flex;
    gap: 2px;
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    border-radius: var(--radius-md);
    padding: 2px;
    flex-shrink: 0;
  }

  .ap-mode-btn {
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

  .ap-mode-btn:hover:not(.ap-mode-btn--active) {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
  }

  .ap-mode-btn--active {
    background: var(--bg-elevated);
    color: var(--fg);
    box-shadow: 0 1px 3px oklch(0 0 0 / 12%);
  }

  .ap-mode-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  /* ── Accent swatches ─────────────────────────────────────────────────────── */

  .ap-accent-grid {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-2);
    align-items: center;
  }

  .ap-swatch {
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

  .ap-swatch:hover {
    transform: scale(1.12);
  }

  .ap-swatch--active {
    box-shadow:
      0 0 0 2px var(--bg),
      0 0 0 4px currentColor;
    outline: none;
  }

  .ap-swatch:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  /* ── Custom color picker ─────────────────────────────────────────────────── */

  .ap-custom {
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

  .ap-custom:hover {
    border-color: var(--fg-muted);
  }

  .ap-color-input {
    position: absolute;
    inset: 0;
    opacity: 0;
    width: 100%;
    height: 100%;
    cursor: pointer;
    border: none;
    padding: 0;
  }

  .ap-custom-icon {
    font-size: 14px;
    font-weight: 400;
    line-height: 1;
    color: var(--fg-subtle);
    pointer-events: none;
    user-select: none;
  }
</style>
