<script lang="ts">
/**
 * Global error boundary — rendered by SvelteKit when a +page.svelte or its
 * load function throws an unhandled error.
 *
 * Keeps the shell intact (sidebar + theme) while showing a useful fallback.
 */
import { page } from '$app/state';

const status = $derived(page.status);
const message = $derived(page.error?.message ?? 'Unknown error');
</script>

<div class="error-container">
  <div class="error-card">
    <div class="error-status">{status}</div>
    <h1 class="error-title">Something broke.</h1>
    <p class="error-message">{message}</p>

    <div class="error-actions">
      <a class="error-link" href="/">Back home</a>
    </div>
  </div>
</div>

<style>
  .error-container {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 100%;
    padding: var(--space-8);
  }

  .error-card {
    max-width: 560px;
    text-align: center;
    padding: var(--space-10) var(--space-8);
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: var(--radius-xl);
  }

  .error-status {
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    letter-spacing: 0.02em;
    margin-bottom: var(--space-4);
  }

  .error-title {
    font-family: var(--font-serif);
    font-size: var(--text-2xl);
    font-weight: 400;
    letter-spacing: -0.025em;
    color: var(--fg);
    margin: 0 0 var(--space-4) 0;
  }

  .error-message {
    font-size: var(--text-base);
    color: var(--fg-muted);
    line-height: 1.55;
    margin: 0 0 var(--space-6) 0;
  }

  .error-actions {
    display: flex;
    justify-content: center;
    gap: var(--space-3);
  }

  .error-link {
    color: var(--accent);
    text-decoration: none;
    font-size: var(--text-sm);
    padding: var(--space-2) var(--space-4);
    border: 1px solid var(--border);
    border-radius: 9999px;
    transition:
      background var(--dur-instant) var(--ease-out),
      border-color var(--dur-instant) var(--ease-out);
  }

  .error-link:hover {
    background: var(--bg-inset);
    border-color: var(--border-strong);
  }

  .error-link:focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: 2px;
  }
</style>
