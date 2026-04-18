<script lang="ts">
/**
 * Workspaces route error boundary.
 * Shown when /workspaces or /workspaces/[slug] load functions throw.
 */
import { page } from '$app/state';
import { goto } from '$app/navigation';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';

const status = $derived(page.status);
const message = $derived(page.error?.message ?? 'This workspace may no longer exist.');
</script>

<div class="we-err">
  <EmptyState
    title="Couldn't load workspaces"
    body={status === 404 ? 'Workspace not found. It may have been deleted or renamed.' : message}
    action="Browse Workspaces"
    onAction={() => goto('/workspaces')}
  />
  {#if status !== 404}
    <details class="we-err__details">
      <summary class="we-err__summary">Technical details</summary>
      <pre class="we-err__pre">{status} — {message}</pre>
    </details>
  {/if}
</div>

<style>
  .we-err {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100%;
    gap: var(--space-4);
  }

  .we-err__details {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    max-width: 480px;
    width: 100%;
  }

  .we-err__summary {
    cursor: pointer;
    user-select: none;
    color: var(--fg-subtle);
    padding: var(--space-1);
  }

  .we-err__pre {
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
