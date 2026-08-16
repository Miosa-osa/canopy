<script lang="ts">
/**
 * SetupScriptCard — workspace setup script editor.
 *
 * The setup_script field is persisted on the workspace record via the backend.
 * The "Detect" button calls POST /api/v1/workspaces/:slug/init/detect to
 * suggest a script based on lockfiles in the workspace root.
 *
 * CSS prefix: ssc-
 * LOC target: ≤ 220
 */
import { ApiError, apiPost } from '$lib/api/client.js';
import { toasts } from '$lib/stores/toasts.svelte.js';

interface DetectResult {
  detected: boolean;
  lockfile: string | null;
  suggested_script: string | null;
}

interface Props {
  workspaceSlug: string;
}

let { workspaceSlug }: Props = $props();

const LS_KEY = $derived(`canopy.workspace.${workspaceSlug}.setup_script`);
const LS_AUTORUN_KEY = $derived(`canopy.workspace.${workspaceSlug}.setup_autorun`);

// ── State ─────────────────────────────────────────────────────────────────────
let script = $state('');
let autoRun = $state(false);
let isRunning = $state(false);
let isDetecting = $state(false);
let isDirty = $state(false);

// Load from localStorage on mount
$effect(() => {
  const saved = localStorage.getItem(LS_KEY);
  if (saved !== null) script = saved;
  const ar = localStorage.getItem(LS_AUTORUN_KEY);
  if (ar !== null) autoRun = ar === 'true';
});

function handleScriptInput(e: Event): void {
  script = (e.target as HTMLTextAreaElement).value;
  isDirty = true;
}

function handleSave(): void {
  localStorage.setItem(LS_KEY, script);
  isDirty = false;
  toasts.success('Setup script saved locally');
}

function handleAutoRunToggle(): void {
  autoRun = !autoRun;
  localStorage.setItem(LS_AUTORUN_KEY, String(autoRun));
}

async function handleDetect(): Promise<void> {
  isDetecting = true;
  try {
    const result = await apiPost<DetectResult>(
      `/workspaces/${workspaceSlug}/init/detect`,
      {}
    );
    if (result.detected && result.suggested_script) {
      script = result.suggested_script;
      isDirty = true;
      toasts.success(`Detected: ${result.suggested_script} (from ${result.lockfile})`);
    } else {
      toasts.info('No known lockfile found in workspace root');
    }
  } catch {
    toasts.error('Detection failed');
  } finally {
    isDetecting = false;
  }
}

async function handleRun(): Promise<void> {
  if (!script.trim()) {
    toasts.warning('Script is empty');
    return;
  }
  isRunning = true;
  try {
    await apiPost(`/workspaces/${workspaceSlug}/setup`, { script });
    toasts.success('Setup script queued');
  } catch (err) {
    if (err instanceof ApiError && err.status === 404) {
      toasts.info('Run will be available when backend ships it');
    } else {
      toasts.error('Failed to run setup script');
    }
  } finally {
    isRunning = false;
  }
}
</script>

<div class="ssc-card glass-card">
  <!-- Banner: local draft -->
  <!-- Header row -->
  <div class="ssc-header">
    <div class="ssc-header-left">
      <span class="ssc-title">Setup Script</span>
      <span class="ssc-subtitle">Runs on workspace session spawn</span>
    </div>
    <div class="ssc-header-actions">
      <button
        class="btn-pill btn-pill-secondary btn-pill-sm"
        onclick={handleDetect}
        disabled={isDetecting}
        aria-label="Auto-detect setup script from lockfiles"
        title="Detect from lockfiles"
      >
        {isDetecting ? 'Detecting…' : 'Detect'}
      </button>
      <label class="ssc-autorun-label">
        <input
          type="checkbox"
          class="ssc-autorun-checkbox"
          checked={autoRun}
          onchange={handleAutoRunToggle}
          aria-label="Auto-run on session spawn"
        />
        <span>Auto-run</span>
      </label>
      <button
        class="btn-pill btn-pill-secondary btn-pill-sm"
        onclick={handleSave}
        disabled={!isDirty}
        aria-label="Save setup script"
      >
        Save
      </button>
      <button
        class="btn-pill btn-pill-primary btn-pill-sm"
        onclick={handleRun}
        disabled={isRunning || !script.trim()}
        aria-label="Run setup script"
      >
        {isRunning ? 'Running...' : 'Run setup'}
      </button>
    </div>
  </div>

  <!-- Script textarea -->
  <textarea
    class="ssc-textarea"
    value={script}
    oninput={handleScriptInput}
    placeholder="#!/bin/bash&#10;# Setup commands run when a session spawns in this workspace&#10;npm install&#10;cp .env.example .env"
    spellcheck={false}
    aria-label="Setup script"
    rows={12}
  ></textarea>
</div>

<style>
  .ssc-card {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-4);
  }

  .ssc-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: var(--space-4);
    flex-wrap: wrap;
  }

  .ssc-header-left {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .ssc-title {
    font-family: var(--font-sans);
    font-size: var(--text-base);
    font-weight: 600;
    color: var(--fg);
  }

  .ssc-subtitle {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  .ssc-header-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-wrap: wrap;
  }

  .ssc-autorun-label {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    cursor: pointer;
    user-select: none;
  }

  .ssc-autorun-checkbox {
    accent-color: var(--cnp-accent);
    width: 14px;
    height: 14px;
    cursor: pointer;
  }

  .ssc-textarea {
    width: 100%;
    box-sizing: border-box;
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    color: var(--fg);
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: var(--space-3);
    resize: vertical;
    outline: none;
    line-height: 1.6;
    tab-size: 2;
    transition: border-color 0.15s ease;
  }

  .ssc-textarea:focus {
    border-color: var(--cnp-accent);
  }

  .ssc-textarea::placeholder {
    color: var(--fg-subtle);
  }
</style>
