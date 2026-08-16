<script lang="ts">
/**
 * Settings › Appearance — mode toggle + accent presets + theme picker grid.
 * Theme picker sets the full palette (colors + terminal) via themeRegistry.
 * Mode toggle and accent picker remain as overrides on top of the base theme.
 */

import { ACCENT_PRESETS, theme } from '$lib/stores/theme.svelte.js';
import { themeRegistry, themes } from '$lib/stores/theme-registry.svelte.js';
</script>

<div class="ap-page">
  <!-- ── Theme picker ──────────────────────────────────────────────────────── -->
  <div class="ap-section">
    <div class="ap-section-header">
      <span class="ap-label">Theme</span>
      <span class="ap-label-desc">Full palette including terminal colors</span>
    </div>
    <div class="ap-theme-grid" role="group" aria-label="Theme presets">
      {#each themes as t}
        {@const isActive = themeRegistry.activeThemeId === t.id}
        <button
          class="ap-theme-card"
          class:ap-theme-card--active={isActive}
          onclick={() => themeRegistry.setTheme(t.id)}
          aria-pressed={isActive}
          aria-label="Theme: {t.name}"
          title={t.name}
        >
          <!-- Mini preview -->
          <div
            class="ap-preview"
            style="background: {t.colors.bg}; border-color: {t.colors.border};"
          >
            <!-- Simulated sidebar strip -->
            <div class="ap-preview-sidebar" style="background: {t.colors.bgElevated};"></div>
            <!-- Simulated content area -->
            <div class="ap-preview-content">
              <div class="ap-preview-line ap-preview-line--title" style="background: {t.colors.fg};"></div>
              <div class="ap-preview-line" style="background: {t.colors.fgMuted};"></div>
              <div class="ap-preview-line ap-preview-line--accent" style="background: {t.colors.accent};"></div>
            </div>
          </div>
          <!-- Label -->
          <div class="ap-theme-meta">
            <span class="ap-theme-name" style="color: var(--fg);">{t.name}</span>
            <span
              class="ap-variant-badge"
              class:ap-variant-badge--light={t.variant === 'light'}
            >{t.variant}</span>
          </div>
          <!-- Active checkmark -->
          {#if isActive}
            <div class="ap-theme-check" aria-hidden="true">
              <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M2 6l3 3 5-5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </div>
          {/if}
        </button>
      {/each}
    </div>
  </div>

  <!-- ── Mode toggle ────────────────────────────────────────────────────────── -->
  <div class="ap-row">
    <div class="ap-label-col">
      <span class="ap-label">Mode override</span>
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

  <!-- ── Accent color presets ──────────────────────────────────────────────── -->
  <div class="ap-row ap-row--wrap">
    <div class="ap-label-col">
      <span class="ap-label">Accent override</span>
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

  /* ── Theme section ────────────────────────────────────────────────────────── */

  .ap-section {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-4);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
  }

  .ap-section-header {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .ap-theme-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));
    gap: var(--space-3);
  }

  .ap-theme-card {
    position: relative;
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-2);
    border: 1.5px solid var(--border);
    border-radius: var(--radius-md);
    background: transparent;
    cursor: pointer;
    transition:
      border-color 0.12s ease,
      box-shadow 0.12s ease;
    text-align: left;
  }

  .ap-theme-card:hover:not(.ap-theme-card--active) {
    border-color: var(--fg-subtle);
  }

  .ap-theme-card--active {
    border-color: var(--user-accent, var(--cnp-accent));
    box-shadow: 0 0 0 1px var(--user-accent, var(--cnp-accent));
  }

  .ap-theme-card:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  /* Mini preview box */
  .ap-preview {
    width: 100%;
    aspect-ratio: 16 / 10;
    border-radius: calc(var(--radius-md) - 2px);
    border: 1px solid;
    overflow: hidden;
    display: flex;
    flex-shrink: 0;
  }

  .ap-preview-sidebar {
    width: 28%;
    height: 100%;
    flex-shrink: 0;
  }

  .ap-preview-content {
    flex: 1;
    padding: 5px 6px;
    display: flex;
    flex-direction: column;
    gap: 3px;
    justify-content: center;
  }

  .ap-preview-line {
    height: 3px;
    border-radius: 2px;
    width: 80%;
    opacity: 0.7;
  }

  .ap-preview-line--title {
    width: 60%;
    opacity: 1;
  }

  .ap-preview-line--accent {
    width: 40%;
    opacity: 0.9;
  }

  /* Theme name + variant badge */
  .ap-theme-meta {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-1);
    min-width: 0;
  }

  .ap-theme-name {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ap-variant-badge {
    font-family: var(--font-sans);
    font-size: 9px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    padding: 1px 4px;
    border-radius: var(--radius-sm);
    background: color-mix(in oklch, var(--fg) 10%, transparent 90%);
    color: var(--fg-muted);
    flex-shrink: 0;
  }

  .ap-variant-badge--light {
    background: color-mix(in oklch, var(--warning, oklch(0.70 0.16 85)) 15%, transparent 85%);
    color: var(--warning, oklch(0.70 0.16 85));
  }

  /* Active checkmark */
  .ap-theme-check {
    position: absolute;
    top: var(--space-1);
    right: var(--space-1);
    width: 18px;
    height: 18px;
    border-radius: 50%;
    background: var(--user-accent, var(--cnp-accent));
    color: var(--user-accent-fg, #fff);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  /* ── Row ──────────────────────────────────────────────────────────────────── */

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

  /* ── Mode group ───────────────────────────────────────────────────────────── */

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

  /* ── Accent swatches ──────────────────────────────────────────────────────── */

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

  /* ── Custom color picker ──────────────────────────────────────────────────── */

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
