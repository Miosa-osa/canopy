<script lang="ts">
/**
 * Settings nested layout — Linear-style left-nav + right pane.
 * Left nav: 280px, section list with icon + label.
 * Active item: 1px --cnp-accent left border + --bg-inset background.
 * Right pane: renders the active section page via children snippet.
 */

import { page } from '$app/state';

let { children } = $props();

interface NavItem {
  path: string;
  label: string;
  icon: string;
}

const NAV_ITEMS: NavItem[] = [
  { path: '/settings/sidebar', label: 'Sidebar', icon: 'sidebar' },
  { path: '/settings/appearance', label: 'Appearance', icon: 'appearance' },
  { path: '/settings/runtimes', label: 'Runtimes', icon: 'runtimes' },
  { path: '/settings/budgets', label: 'Budgets', icon: 'budgets' },
  { path: '/settings/governance', label: 'Governance', icon: 'governance' },
  { path: '/settings/miosa', label: 'MIOSA', icon: 'miosa' },
  { path: '/settings/keyboard', label: 'Keyboard Shortcuts', icon: 'keyboard' },
  { path: '/settings/integrations', label: 'Integrations', icon: 'integrations' },
  { path: '/settings/profile', label: 'Profile', icon: 'profile' },
];

const sectionLabel = $derived(
  NAV_ITEMS.find((n) => page.url.pathname.startsWith(n.path))?.label ?? ''
);
</script>

<div class="sl-shell">
  <!-- Left nav -->
  <nav class="sl-nav" aria-label="Settings navigation">
    <div class="sl-nav-inner">
      <p class="sl-nav-heading" aria-hidden="true">Settings</p>
      <ul class="sl-nav-list" role="list">
        {#each NAV_ITEMS as item (item.path)}
          {@const active = page.url.pathname.startsWith(item.path)}
          <li>
            <a
              href={item.path}
              class="sl-nav-item"
              class:sl-nav-item--active={active}
              aria-current={active ? 'page' : undefined}
            >
              <!-- Icon slot -->
              <span class="sl-nav-icon" aria-hidden="true">
                {#if item.icon === 'sidebar'}
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="9" y1="3" x2="9" y2="21"/></svg>
                {:else if item.icon === 'appearance'}
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/></svg>
                {:else if item.icon === 'runtimes'}
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="4 17 10 11 4 5"/><line x1="12" y1="19" x2="20" y2="19"/></svg>
                {:else if item.icon === 'budgets'}
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
                {:else if item.icon === 'governance'}
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
                {:else if item.icon === 'miosa'}
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/></svg>
                {:else if item.icon === 'keyboard'}
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="6" width="20" height="12" rx="2"/><path d="M6 10h.01M10 10h.01M14 10h.01M18 10h.01M8 14h8"/></svg>
                {:else if item.icon === 'integrations'}
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>
                {:else if item.icon === 'profile'}
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
                {/if}
              </span>
              <span class="sl-nav-label">{item.label}</span>
            </a>
          </li>
        {/each}
      </ul>
    </div>
  </nav>

  <!-- Right pane -->
  <div class="sl-pane" role="main">
    <header class="sl-pane-header">
      <h1 class="sl-pane-title">Settings</h1>
      {#if sectionLabel}
        <h2 class="sl-pane-section">{sectionLabel}</h2>
      {/if}
    </header>
    <div class="sl-pane-content">
      {@render children()}
    </div>
  </div>
</div>

<style>
  .sl-shell {
    display: flex;
    height: 100%;
    overflow: hidden;
  }

  /* ── Left nav ────────────────────────────────────────────────────────────── */

  .sl-nav {
    width: 280px;
    flex-shrink: 0;
    border-right: 1px solid var(--border);
    overflow-y: auto;
    display: flex;
    flex-direction: column;
  }

  .sl-nav-inner {
    padding: var(--space-4) var(--space-3);
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .sl-nav-heading {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--fg-subtle);
    margin: 0 0 var(--space-2) var(--space-2);
  }

  .sl-nav-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .sl-nav-item {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-1-5) var(--space-2);
    border-radius: var(--radius-sm);
    border-left: 1px solid transparent;
    text-decoration: none;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg-muted);
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out),
      border-color var(--dur-instant) var(--ease-out);
    cursor: pointer;
  }

  .sl-nav-item:hover:not(.sl-nav-item--active) {
    background: color-mix(in oklch, var(--fg) 5%, transparent 95%);
    color: var(--fg);
  }

  .sl-nav-item--active {
    background: var(--bg-inset);
    color: var(--fg);
    border-left-color: var(--cnp-accent);
  }

  .sl-nav-item:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: -2px;
  }

  .sl-nav-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    color: inherit;
  }

  .sl-nav-label {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  /* ── Right pane ──────────────────────────────────────────────────────────── */

  .sl-pane {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .sl-pane-header {
    flex-shrink: 0;
    padding: var(--space-6) var(--space-8) var(--space-4);
    border-bottom: 1px solid var(--border);
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .sl-pane-title {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--fg-subtle);
    margin: 0;
  }

  .sl-pane-section {
    font-family: var(--font-sans);
    font-size: var(--text-lg);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
  }

  .sl-pane-content {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-6) var(--space-8);
  }
</style>
