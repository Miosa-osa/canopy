<script lang="ts">
  import { page } from '$app/state';
  import { invalidateAll } from '$app/navigation';

  const status = $derived(page.status);
  const message = $derived(page.error?.message ?? 'An unexpected error occurred.');

  const headline = $derived(
    status === 404
      ? 'Page not found'
      : status === 403
        ? 'Access denied'
        : status === 500
          ? 'Server error'
          : 'Something went wrong'
  );

  const isRetryable = $derived(status >= 500 || status === 0);

  async function retry() {
    await invalidateAll();
  }
</script>

<svelte:head>
  <title>{status} — Canopy</title>
</svelte:head>

<div class="app-error">
  <div class="card">
    <div class="status-badge">{status}</div>
    <h1 class="headline">{headline}</h1>
    <p class="message">{message}</p>

    <div class="actions">
      <a href="/app" class="btn-secondary" aria-label="Return to dashboard">
        Back to Dashboard
      </a>
      {#if isRetryable}
        <button class="btn-primary" onclick={retry} aria-label="Retry the current page">
          Retry
        </button>
      {/if}
    </div>
  </div>
</div>

<style>
  .app-error {
    flex: 1;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--bg-secondary, #141414);
    font-family: var(--font-sans, 'Inter', system-ui, sans-serif);
    padding: 1.5rem;
  }

  .card {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1rem;
    background: var(--bg-surface, rgba(255, 255, 255, 0.03));
    border: 1px solid var(--border-default, rgba(255, 255, 255, 0.08));
    border-radius: var(--radius-md, 12px);
    padding: 3rem 2.5rem;
    max-width: 420px;
    width: 100%;
    text-align: center;
  }

  .status-badge {
    font-size: 0.75rem;
    font-weight: 600;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: var(--accent-primary, #3b82f6);
    background: rgba(59, 130, 246, 0.1);
    border: 1px solid rgba(59, 130, 246, 0.2);
    border-radius: 999px;
    padding: 0.25rem 0.75rem;
  }

  .headline {
    margin: 0;
    font-size: 1.375rem;
    font-weight: 600;
    color: var(--text-primary, #ffffff);
    line-height: 1.3;
  }

  .message {
    margin: 0;
    font-size: 0.875rem;
    color: var(--text-secondary, #a0a0a0);
    line-height: 1.6;
    max-width: 320px;
  }

  .actions {
    display: flex;
    align-items: center;
    gap: 0.625rem;
    margin-top: 0.5rem;
    flex-wrap: wrap;
    justify-content: center;
  }

  .btn-secondary {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 0.5rem 1.125rem;
    font-size: 0.875rem;
    font-weight: 500;
    color: var(--text-primary, #ffffff);
    background: var(--bg-elevated, rgba(255, 255, 255, 0.06));
    border: 1px solid var(--border-default, rgba(255, 255, 255, 0.08));
    border-radius: var(--radius-md, 12px);
    text-decoration: none;
    transition: background 150ms ease, border-color 150ms ease;
    cursor: pointer;
  }

  .btn-secondary:hover {
    background: rgba(255, 255, 255, 0.09);
    border-color: var(--border-hover, rgba(255, 255, 255, 0.15));
  }

  .btn-secondary:focus-visible {
    outline: 2px solid var(--accent-primary, #3b82f6);
    outline-offset: 3px;
  }

  .btn-primary {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 0.5rem 1.125rem;
    font-size: 0.875rem;
    font-weight: 500;
    color: #ffffff;
    background: var(--accent-primary, #3b82f6);
    border: 1px solid transparent;
    border-radius: var(--radius-md, 12px);
    cursor: pointer;
    transition: opacity 150ms ease, background 150ms ease;
  }

  .btn-primary:hover {
    opacity: 0.88;
  }

  .btn-primary:focus-visible {
    outline: 2px solid var(--accent-primary, #3b82f6);
    outline-offset: 3px;
  }
</style>
