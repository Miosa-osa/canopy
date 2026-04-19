<script lang="ts">
/**
 * Settings › Keyboard Shortcuts — read-only cheatsheet viewer.
 * Pulls from $lib/utils/shortcuts.ts — single source of truth.
 */

import { SHORTCUTS } from '$lib/utils/shortcuts.js';
</script>

<div class="kb-page">
  <p class="kb-desc">
    All keyboard shortcuts in Canopy. Shortcuts are global unless noted.
  </p>

  <div class="kb-sections">
    {#each SHORTCUTS as section (section.label)}
      <section class="kb-section" aria-labelledby="kb-section-{section.label}">
        <h3 class="kb-section-title" id="kb-section-{section.label}">{section.label}</h3>
        <div class="kb-grid">
          {#each section.entries as entry (entry.description)}
            <div class="kb-row">
              <div class="kb-keys" aria-label={entry.keys.join(' ')}>
                {#each entry.keys as key, i (i)}
                  <kbd class="kb-key">{key}</kbd>
                  {#if i < entry.keys.length - 1}
                    <span class="kb-plus" aria-hidden="true">+</span>
                  {/if}
                {/each}
              </div>
              <span class="kb-desc">{entry.description}</span>
            </div>
          {/each}
        </div>
      </section>
    {/each}
  </div>
</div>

<style>
  .kb-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-6);
    max-width: 720px;
  }

  .kb-desc {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
  }

  /* ── Sections ────────────────────────────────────────────────────────────── */

  .kb-sections {
    display: flex;
    flex-direction: column;
    gap: var(--space-6);
  }

  .kb-section {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .kb-section-title {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--fg-subtle);
    margin: 0;
    padding-bottom: var(--space-2);
    border-bottom: 1px solid var(--border);
  }

  /* ── Grid: 2-col (keys | description) ───────────────────────────────────── */

  .kb-grid {
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .kb-row {
    display: grid;
    grid-template-columns: 160px 1fr;
    align-items: center;
    gap: var(--space-4);
    padding: var(--space-1-5) var(--space-2);
    border-radius: var(--radius-sm);
    transition: background var(--dur-instant) var(--ease-out);
  }

  .kb-row:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }

  /* ── Keys ────────────────────────────────────────────────────────────────── */

  .kb-keys {
    display: flex;
    align-items: center;
    gap: 3px;
    flex-wrap: wrap;
  }

  .kb-key {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 22px;
    height: 20px;
    padding: 0 var(--space-1-5);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: color-mix(in oklch, var(--fg) 5%, transparent 95%);
    font-family: var(--font-mono);
    font-size: 11px;
    font-weight: 500;
    color: var(--fg-muted);
    white-space: nowrap;
    user-select: none;
  }

  .kb-plus {
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--fg-subtle);
    user-select: none;
  }

  /* ── Description ─────────────────────────────────────────────────────────── */

  .kb-desc {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
  }
</style>
