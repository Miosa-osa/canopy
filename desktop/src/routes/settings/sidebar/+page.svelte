<script lang="ts">
/**
 * Settings › Sidebar — reorder and toggle sidebar items per group.
 * Moved from the monolithic /settings/+page.svelte. Logic unchanged.
 */

import { sidebarConfig } from '$lib/stores/sidebar-config.svelte.js';

let groupOpen = $state<Record<string, boolean>>(
  Object.fromEntries(sidebarConfig.config.groups.map((g) => [g.label, true]))
);

function toggleGroup(label: string): void {
  groupOpen[label] = !groupOpen[label];
}
</script>

<div class="sb-page">
  <div class="sb-section-header">
    <p class="sb-desc">
      Reorder items within each group or hide them from the sidebar. Changes apply immediately.
    </p>
    <button
      class="sb-pill-btn"
      onclick={() => sidebarConfig.reset()}
      aria-label="Reset sidebar to defaults"
    >
      Reset to defaults
    </button>
  </div>

  <div class="sb-groups">
    {#each sidebarConfig.config.groups as group (group.label)}
      <div class="sb-group">
        <button
          class="sb-group-header"
          onclick={() => toggleGroup(group.label)}
          aria-expanded={groupOpen[group.label]}
          aria-controls="sb-group-{group.label}"
        >
          <span class="sb-group-label">{group.label}</span>
          <span class="sb-group-chevron" class:sb-group-chevron--open={groupOpen[group.label]}>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
              <path d="M6 9l6 6 6-6" />
            </svg>
          </span>
        </button>

        {#if groupOpen[group.label]}
          <ul class="sb-item-list" id="sb-group-{group.label}" role="list">
            {#each group.items as item, idx (item.path + item.label)}
              <li class="sb-item" class:sb-item--hidden={item.hidden}>
                <button
                  class="sb-icon-btn"
                  onclick={() => sidebarConfig.moveItemUp(group.label, item.path, item.label)}
                  disabled={idx === 0}
                  aria-label="Move {item.label} up"
                  title="Move up"
                >
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                    <path d="M12 19V5M5 12l7-7 7 7" />
                  </svg>
                </button>

                <button
                  class="sb-icon-btn"
                  onclick={() => sidebarConfig.moveItemDown(group.label, item.path, item.label)}
                  disabled={idx === group.items.length - 1}
                  aria-label="Move {item.label} down"
                  title="Move down"
                >
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                    <path d="M12 5v14M19 12l-7 7-7-7" />
                  </svg>
                </button>

                <span class="sb-item-label">{item.label}</span>

                {#if item.comingSoon}
                  <span class="sb-badge-soon" aria-label="Coming soon">soon</span>
                {/if}

                <button
                  class="sb-icon-btn sb-icon-btn--eye"
                  onclick={() => sidebarConfig.toggleHidden(group.label, item.path, item.label)}
                  aria-label={item.hidden ? `Show ${item.label} in sidebar` : `Hide ${item.label} from sidebar`}
                  aria-pressed={item.hidden}
                  title={item.hidden ? 'Show in sidebar' : 'Hide from sidebar'}
                >
                  {#if item.hidden}
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                      <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24" />
                      <line x1="1" y1="1" x2="23" y2="23" />
                    </svg>
                  {:else}
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
</div>

<style>
  .sb-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-6);
    max-width: 720px;
  }

  .sb-section-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: var(--space-4);
  }

  .sb-desc {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
  }

  /* ── Pill button ─────────────────────────────────────────────────────────── */

  .sb-pill-btn {
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

  .sb-pill-btn:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
    border-color: var(--border-strong);
  }

  .sb-pill-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  /* ── Groups ──────────────────────────────────────────────────────────────── */

  .sb-groups {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .sb-group {
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    overflow: hidden;
  }

  .sb-group-header {
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

  .sb-group-header:hover {
    background: color-mix(in oklch, var(--fg) 7%, transparent 93%);
  }

  .sb-group-header:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: -2px;
  }

  .sb-group-chevron {
    color: var(--fg-subtle);
    transform: rotate(-90deg);
    transition: transform var(--dur-instant) var(--ease-out);
  }

  .sb-group-chevron--open {
    transform: rotate(0deg);
  }

  /* ── Item list ───────────────────────────────────────────────────────────── */

  .sb-item-list {
    list-style: none;
    margin: 0;
    padding: var(--space-1);
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .sb-item {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-1) var(--space-2);
    border-radius: var(--radius-sm);
    min-height: 32px;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .sb-item:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }

  .sb-item--hidden .sb-item-label {
    text-decoration: line-through;
    color: var(--fg-subtle);
  }

  .sb-item-label {
    flex: 1;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .sb-badge-soon {
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

  /* ── Icon buttons ────────────────────────────────────────────────────────── */

  .sb-icon-btn {
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

  .sb-icon-btn:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 10%, transparent 90%);
    color: var(--fg);
  }

  .sb-icon-btn:disabled {
    opacity: 0.25;
    cursor: not-allowed;
  }

  .sb-icon-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  .sb-icon-btn--eye {
    margin-left: auto;
  }
</style>
