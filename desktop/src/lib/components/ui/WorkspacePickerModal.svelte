<script lang="ts">
  import { X, FolderOpen } from 'lucide-svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';
  import { isTauri } from '$lib/utils/platform';

  interface Props {
    open: boolean;
    onClose: () => void;
  }

  let { open = $bindable(), onClose }: Props = $props();
  let selecting = $state(false);
  let error = $state<string | null>(null);

  async function selectDirectory() {
    if (!isTauri()) return;
    selecting = true;
    error = null;
    try {
      const { open: openDialog } = await import('@tauri-apps/plugin-dialog');
      const selected = await openDialog({ directory: true, multiple: false });
      if (selected && typeof selected === 'string') {
        // Try to read workspace name from SYSTEM.md
        let name = selected.split('/').pop() || 'Workspace';
        try {
          const { invoke } = await import('@tauri-apps/api/core');
          const systemMd = await invoke<string>('read_markdown_file', { path: selected + '/SYSTEM.md' });
          const nameMatch = systemMd?.match(/^name:\s*(.+)$/m);
          if (nameMatch) name = nameMatch[1].trim();
        } catch {
          // No SYSTEM.md or read failed — use directory name
        }

        const ws = {
          id: crypto.randomUUID(),
          path: selected,
          name,
          addedAt: new Date().toISOString(),
        };
        workspaceStore.addWorkspace(ws);
        await workspaceStore.setActiveWorkspace(ws.id);
        onClose();
      }
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    }
    selecting = false;
  }
</script>

{#if open}
  <div class="wpm-overlay" role="dialog" aria-modal="true" aria-label="Add workspace">
    <div class="wpm-modal">
      <div class="wpm-header">
        <h2>Add Workspace</h2>
        <button class="wpm-close" onclick={onClose} aria-label="Close">
          <X size={18} />
        </button>
      </div>
      <div class="wpm-body">
        <p class="wpm-desc">Select a directory containing an OptimalOS workspace (with nodes/, rhythm/, topology.yaml).</p>
        {#if error}
          <p class="wpm-error">{error}</p>
        {/if}
        <button class="wpm-select-btn" onclick={selectDirectory} disabled={selecting}>
          <FolderOpen size={18} />
          {selecting ? 'Selecting…' : 'Choose Directory'}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .wpm-overlay {
    position: fixed;
    inset: 0;
    z-index: 1000;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(0, 0, 0, 0.6);
    backdrop-filter: blur(4px);
  }

  .wpm-modal {
    background: var(--bg-tertiary, #1e1e1e);
    border: 1px solid var(--border-default, rgba(255,255,255,0.08));
    border-radius: var(--radius-md, 12px);
    width: 420px;
    max-width: 90vw;
    box-shadow: 0 16px 48px rgba(0, 0, 0, 0.4);
  }

  .wpm-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 20px;
    border-bottom: 1px solid var(--border-default);
  }

  .wpm-header h2 {
    font-size: 16px;
    font-weight: 600;
    color: var(--text-primary, #fff);
    margin: 0;
  }

  .wpm-close {
    background: none;
    border: none;
    color: var(--text-tertiary, #666);
    cursor: pointer;
    padding: 4px;
    border-radius: var(--radius-xs, 4px);
    transition: color 100ms;
  }

  .wpm-close:hover { color: var(--text-primary, #fff); }

  .wpm-body {
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .wpm-desc {
    color: var(--text-secondary, #a0a0a0);
    font-size: 13px;
    line-height: 1.5;
    margin: 0;
  }

  .wpm-error {
    color: var(--accent-error, #ef4444);
    font-size: 13px;
    margin: 0;
  }

  .wpm-select-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    padding: 10px 16px;
    background: var(--accent-primary, #3b82f6);
    color: white;
    border: none;
    border-radius: var(--radius-sm, 8px);
    font-size: 14px;
    font-weight: 500;
    cursor: pointer;
    transition: opacity 150ms;
  }

  .wpm-select-btn:hover { opacity: 0.9; }
  .wpm-select-btn:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
