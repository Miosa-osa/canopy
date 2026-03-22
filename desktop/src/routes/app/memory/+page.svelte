<script lang="ts">
  import { onMount } from 'svelte';
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import MemoryBrowser from '$lib/components/memory/MemoryBrowser.svelte';
  import { memoryStore } from '$lib/stores/memory.svelte';

  onMount(() => { memoryStore.fetch(); });
</script>

<PageShell
  title="Memory"
  badge={memoryStore.totalCount > 0 ? memoryStore.totalCount : undefined}
>
  {#snippet actions()}
    <button
      class="mem-refresh-btn"
      onclick={() => void memoryStore.fetch()}
      disabled={memoryStore.loading}
      aria-label="Refresh memory entries"
    >
      <svg
        width="13"
        height="13"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        class:mem-spinning={memoryStore.loading}
        aria-hidden="true"
      >
        <polyline points="23 4 23 10 17 10" />
        <polyline points="1 20 1 14 7 14" />
        <path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15" />
      </svg>
      Refresh
    </button>
  {/snippet}

  <div class="mem-content">
    <MemoryBrowser />
  </div>
</PageShell>

<style>
  .mem-content {
    height: 100%;
    /* Pull the browser flush with the shell content area edges */
    margin: -20px -24px;
  }

  .mem-refresh-btn {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    height: 28px;
    padding: 0 10px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-xs);
    color: var(--text-secondary);
    font-family: var(--font-sans);
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    transition: all 100ms ease;
  }

  .mem-refresh-btn:hover:not(:disabled) {
    border-color: var(--border-hover);
    color: var(--text-primary);
  }

  .mem-refresh-btn:disabled {
    opacity: 0.5;
    cursor: default;
  }

  .mem-spinning {
    animation: mem-spin 600ms linear infinite;
  }

  @keyframes mem-spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
</style>
