<!-- src/routes/app/documents/+page.svelte -->
<script lang="ts">
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import DocumentTree from '$lib/components/documents/DocumentTree.svelte';
  import DocumentViewer from '$lib/components/documents/DocumentViewer.svelte';
  import { documentsStore } from '$lib/stores/documents.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';

  // Re-fetch whenever the active workspace changes (covers initial mount too).
  // Referencing activeWorkspaceId registers it as a reactive dependency so the
  // effect re-runs on every workspace switch.
  $effect(() => {
    void workspaceStore.activeWorkspaceId;
    documentsStore.fetchDocuments();
  });
</script>

<PageShell title="Documents" badge={documentsStore.documents.length > 0 ? documentsStore.documents.length : undefined}>
  <div class="dp-layout">
    <!-- Left: file tree -->
    <aside class="dp-sidebar" aria-label="Document tree navigation" role="navigation">
      {#if documentsStore.loading}
        <div class="dp-loading" role="status" aria-label="Loading documents">
          <div class="dp-spinner" aria-hidden="true"></div>
        </div>
      {:else if documentsStore.tree.length === 0}
        <div class="dp-empty-tree" role="status">
          <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.25" aria-hidden="true">
            <path d="M22 19a2 2 0 01-2 2H4a2 2 0 01-2-2V5a2 2 0 012-2h5l2 3h9a2 2 0 012 2z" />
          </svg>
          <p>No documents</p>
        </div>
      {:else}
        <DocumentTree nodes={documentsStore.tree} />
      {/if}
    </aside>

    <!-- Right: viewer -->
    <main class="dp-main" id="document-content" aria-label="Document content">
      {#if documentsStore.selected}
        <DocumentViewer document={documentsStore.selected} />
      {:else}
        <div class="dp-no-selection" role="status">
          <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.25" aria-hidden="true">
            <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8zM14 2v6h6M16 13H8M16 17H8M10 9H8" />
          </svg>
          <h3>No document selected</h3>
          <p>Select a file from the tree to view its contents.</p>
        </div>
      {/if}
    </main>
  </div>
</PageShell>

<style>
  .dp-layout {
    display: flex;
    height: 100%;
    gap: 0;
    overflow: hidden;
  }

  .dp-sidebar {
    width: 240px;
    min-width: 180px;
    flex-shrink: 0;
    border-right: 1px solid var(--border-default);
    overflow-y: auto;
    padding: 8px 6px;
    background: var(--bg-secondary);
  }

  .dp-sidebar::-webkit-scrollbar { width: 4px; }
  .dp-sidebar::-webkit-scrollbar-track { background: transparent; }
  .dp-sidebar::-webkit-scrollbar-thumb { background: var(--border-default); border-radius: 2px; }

  .dp-main {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    padding: 16px;
    display: flex;
    flex-direction: column;
  }

  .dp-loading {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 80px;
  }

  .dp-spinner {
    width: 20px;
    height: 20px;
    border: 2px solid var(--border-default);
    border-top-color: var(--accent-primary);
    border-radius: 50%;
    animation: dp-spin 0.7s linear infinite;
  }

  @keyframes dp-spin { to { transform: rotate(360deg); } }

  .dp-empty-tree {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 8px;
    height: 140px;
    color: var(--text-muted);
    text-align: center;
  }

  .dp-empty-tree p {
    font-size: 12px;
    margin: 0;
  }

  .dp-no-selection {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 10px;
    flex: 1;
    color: var(--text-tertiary);
    text-align: center;
    padding: 24px;
  }

  .dp-no-selection svg { color: var(--text-muted); margin-bottom: 4px; }

  .dp-no-selection h3 {
    font-size: 15px;
    font-weight: 500;
    color: var(--text-secondary);
    margin: 0;
  }

  .dp-no-selection p {
    font-size: 13px;
    color: var(--text-tertiary);
    margin: 0;
    max-width: 280px;
  }
</style>
