<script lang="ts">
/**
 * Sessions route error boundary.
 * Shown when /sessions or /sessions/[id] load functions throw.
 * Uses EmptyState for consistent visual treatment.
 */

import { goto } from '$app/navigation';
import { page } from '$app/state';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';

const status = $derived(page.status);
const message = $derived(page.error?.message ?? 'This session may no longer exist.');
</script>

<div class="se-err">
  <EmptyState
    title="Couldn't load sessions"
    body={status === 404 ? 'Session not found.' : message}
    action="Back to Sessions"
    onAction={() => goto('/sessions')}
  />
  {#if status !== 404}
    <details class="se-err__details">
      <summary class="se-err__summary">Technical details</summary>
      <pre class="se-err__pre">{status} — {message}</pre>
    </details>
  {/if}
</div>

<style>
  .se-err {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100%;
    gap: var(--space-4);
  }

  .se-err__details {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    max-width: 480px;
    width: 100%;
  }

  .se-err__summary {
    cursor: pointer;
    user-select: none;
    color: var(--fg-subtle);
    padding: var(--space-1);
  }

  .se-err__pre {
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
