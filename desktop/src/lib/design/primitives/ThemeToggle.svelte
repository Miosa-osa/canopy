<script lang="ts">
/**
 * Theme toggle — floating bottom-right button.
 * Global; does not reach into routes. Pure presentation over the UI store.
 */
import { ui } from '$lib/stores/ui.svelte.js';

const label = $derived(ui.theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode');
</script>

<button
  class="theme-toggle"
  onclick={() => ui.toggleTheme()}
  aria-label={label}
  title="Toggle theme (⌘⇧D)"
>
  {#if ui.theme === 'dark'}
    <!-- Sun -->
    <svg
      width="16"
      height="16"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41" />
    </svg>
  {:else}
    <!-- Moon -->
    <svg
      width="16"
      height="16"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
    </svg>
  {/if}
</button>

<style>
  .theme-toggle {
    position: fixed;
    bottom: var(--space-4);
    right: var(--space-4);
    width: 36px;
    height: 36px;
    border-radius: var(--radius-md);
    border: 1px solid var(--border);
    background: var(--bg-elevated);
    color: var(--fg-muted);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out),
      border-color var(--dur-instant) var(--ease-out);
    z-index: 50;
  }

  .theme-toggle:hover {
    background: var(--bg-inset);
    color: var(--fg);
    border-color: var(--border-strong);
  }

  .theme-toggle:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }
</style>
