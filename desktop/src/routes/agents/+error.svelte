<script lang="ts">
/**
 * Agents route error boundary.
 * Shown when /agents or /agents/[slug] load functions throw.
 */
import { page } from '$app/state';
import { goto } from '$app/navigation';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';

const status = $derived(page.status);
const message = $derived(page.error?.message ?? 'This agent may no longer exist.');
</script>

<div class="ae-err">
  <EmptyState
    title="Couldn't load agents"
    body={status === 404 ? 'Agent not found. It may have been removed from the library.' : message}
    action="Browse Agents"
    onAction={() => goto('/agents')}
  />
  {#if status !== 404}
    <details class="ae-err__details">
      <summary class="ae-err__summary">Technical details</summary>
      <pre class="ae-err__pre">{status} — {message}</pre>
    </details>
  {/if}
</div>

<style>
  .ae-err {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100%;
    gap: var(--space-4);
  }

  .ae-err__details {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    max-width: 480px;
    width: 100%;
  }

  .ae-err__summary {
    cursor: pointer;
    user-select: none;
    color: var(--fg-subtle);
    padding: var(--space-1);
  }

  .ae-err__pre {
    margin: var(--space-2) 0 0;
    padding: var(--space-3);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    overflow-x: auto;
    white-space: pre-wrap;
    word-break: break-all;
  }
</style>
