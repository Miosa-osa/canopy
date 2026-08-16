<script lang="ts">
/**
 * WorkspaceDangerTab — Rename, archive, delete workspace.
 * CSS prefix: wdt-
 */
import { apiPatch } from '$lib/api/client.js';
import { toasts } from '$lib/stores/toasts.svelte.js';
import type { WorkspaceDetail } from '$lib/domain/workspaces/types.js';

interface Props {
  workspace: WorkspaceDetail;
  onDeleted: () => void;
  onRenamed: () => void;
  isDeleting: boolean;
  onDeleteRequest: () => void;
}

let { workspace, onDeleted, onRenamed, isDeleting, onDeleteRequest }: Props = $props();

let renameValue = $state('');
let renameError = $state('');
let confirmDeleteOpen = $state(false);

async function handleRename(): Promise<void> {
  renameError = '';
  const trimmed = renameValue.trim();
  if (!trimmed) { renameError = 'Name cannot be empty'; return; }
  if (trimmed === workspace.name) { renameError = 'No change'; return; }
  try {
    await apiPatch(`/workspaces/${workspace.slug}`, { name: trimmed });
    toasts.success('Workspace renamed');
    renameValue = '';
    onRenamed();
  } catch {
    toasts.error('Failed to rename workspace');
  }
}

async function handleArchive(): Promise<void> {
  try {
    await apiPatch(`/workspaces/${workspace.slug}`, { deleted_at: new Date().toISOString() });
    toasts.success('Workspace archived');
    onDeleted();
  } catch {
    toasts.error('Failed to archive workspace');
  }
}
</script>

<div class="wdt-panel">
  <!-- Rename -->
  <div class="wdt-section">
    <div class="wdt-info">
      <span class="wdt-label">Rename workspace</span>
      <span class="wdt-desc">Changes the display name. Slug ({workspace.slug}) is immutable.</span>
    </div>
    <div class="wdt-action">
      <input
        class="wdt-input"
        type="text"
        placeholder={workspace.name}
        bind:value={renameValue}
        aria-label="New workspace name"
      />
      {#if renameError}
        <span class="wdt-error">{renameError}</span>
      {/if}
      <button
        class="btn-pill btn-pill-secondary btn-pill-sm"
        onclick={handleRename}
        disabled={!renameValue.trim()}
        aria-label="Save new workspace name"
      >Rename</button>
    </div>
  </div>

  <!-- Archive -->
  <div class="wdt-section">
    <div class="wdt-info">
      <span class="wdt-label">Archive workspace</span>
      <span class="wdt-desc">Soft-deletes the workspace. It can be restored by support.</span>
    </div>
    <button
      class="btn-pill btn-pill-secondary btn-pill-sm"
      onclick={handleArchive}
      aria-label="Archive this workspace"
    >Archive</button>
  </div>

  <!-- Delete -->
  <div class="wdt-section wdt-section--red">
    <div class="wdt-info">
      <span class="wdt-label">Delete workspace</span>
      <span class="wdt-desc">Permanently removes the workspace record. Files on disk are NOT deleted.</span>
    </div>
    {#if !confirmDeleteOpen}
      <button
        class="btn-pill btn-pill-danger btn-pill-sm"
        onclick={() => { confirmDeleteOpen = true; }}
        aria-label="Begin delete workspace"
      >Delete</button>
    {:else}
      <div class="wdt-confirm">
        <span class="wdt-confirm-text">Sure? This is permanent.</span>
        <button
          class="btn-pill btn-pill-danger btn-pill-sm"
          onclick={onDeleteRequest}
          disabled={isDeleting}
          aria-label="Confirm delete workspace"
        >{isDeleting ? 'Deleting...' : 'Yes, delete'}</button>
        <button
          class="btn-pill btn-pill-secondary btn-pill-sm"
          onclick={() => { confirmDeleteOpen = false; }}
          aria-label="Cancel delete"
        >Cancel</button>
      </div>
    {/if}
  </div>
</div>

<style>
  .wdt-panel {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }

  .wdt-section {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: var(--space-6);
    padding: var(--space-4);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    flex-wrap: wrap;
  }

  .wdt-section--red {
    border-color: color-mix(in oklch, var(--signal-error) 30%, transparent);
    background: color-mix(in oklch, var(--signal-error) 4%, transparent);
  }

  .wdt-info {
    display: flex;
    flex-direction: column;
    gap: 4px;
    min-width: 0;
  }

  .wdt-label {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
  }

  .wdt-desc {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    line-height: 1.5;
    max-width: 440px;
  }

  .wdt-action {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-wrap: wrap;
    flex-shrink: 0;
  }

  .wdt-input {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: var(--space-1) var(--space-3);
    outline: none;
    min-width: 180px;
    transition: border-color 0.15s ease;
  }

  .wdt-input:focus { border-color: var(--cnp-accent); }

  .wdt-error {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--signal-error);
  }

  .wdt-confirm {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-wrap: wrap;
  }

  .wdt-confirm-text {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--signal-error);
    font-weight: 500;
  }
</style>
