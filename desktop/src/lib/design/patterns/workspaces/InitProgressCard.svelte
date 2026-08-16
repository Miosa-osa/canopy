<script lang="ts">
/**
 * InitProgressCard — live progress view for workspace init jobs.
 *
 * Opens an SSE connection to /workspaces/:slug/init/:jobId/stream.
 * Renders step name, progress bar, accumulated output, and cancel button.
 * Emits `onDone` when init succeeds, `onCancelled` on cancel, `onError` on failure.
 *
 * CSS prefix: ipc-
 * LOC target: ≤ 220
 */
import { onDestroy } from 'svelte';
import { API_BASE } from '$lib/api/client.js';
import { cancelInitJob } from '$lib/api/queries/workspaces.js';
import { toasts } from '$lib/stores/toasts.svelte.js';
import type { InitJob, InitJobStep } from '$lib/domain/workspaces/types.js';

interface Props {
  slug: string;
  jobId: string;
  initialJob?: InitJob | null;
  onDone?: () => void;
  onCancelled?: () => void;
  onError?: (error: string) => void;
}

let {
  slug,
  jobId,
  initialJob = null,
  onDone,
  onCancelled,
  onError,
}: Props = $props();

// ── State — seeded from initialJob prop (snapshot at mount time) ───────────────
let progressPct = $state(0);
let currentStep = $state<InitJobStep | null>(null);
let output = $state('');
let status = $state<'pending' | 'running' | 'succeeded' | 'failed' | 'cancelled'>('running');

// Seed from initialJob once on mount
$effect.pre(() => {
  if (initialJob) {
    progressPct = initialJob.progressPct;
    currentStep = initialJob.currentStep;
    output = initialJob.output;
    status = initialJob.status;
  }
});
let isCancelling = $state(false);

// ── SSE connection ────────────────────────────────────────────────────────────
let eventSource: EventSource | null = null;

function connect(): void {
  const url = `${API_BASE}/workspaces/${slug}/init/${jobId}/stream`;
  eventSource = new EventSource(url);

  eventSource.addEventListener('progress', (e) => {
    const data = JSON.parse(e.data) as {
      progress_pct?: number;
      current_step?: InitJobStep;
      output?: string;
      status?: string;
    };
    if (data.progress_pct !== undefined) progressPct = data.progress_pct;
    if (data.current_step !== undefined) currentStep = data.current_step;
    if (data.output !== undefined) output = data.output;
    if (data.status !== undefined) status = data.status as typeof status;
  });

  eventSource.addEventListener('step', (e) => {
    const data = JSON.parse(e.data) as { step: InitJobStep };
    currentStep = data.step;
  });

  eventSource.addEventListener('output', (e) => {
    const data = JSON.parse(e.data) as { text: string };
    output += data.text;
  });

  eventSource.addEventListener('done', () => {
    status = 'succeeded';
    progressPct = 100;
    disconnect();
    onDone?.();
  });

  eventSource.addEventListener('error', (e) => {
    const data = e instanceof MessageEvent ? (JSON.parse(e.data) as { error?: string }) : null;
    const msg = data?.error ?? 'Init failed';
    status = 'failed';
    disconnect();
    onError?.(msg);
  });

  eventSource.addEventListener('cancelled', () => {
    status = 'cancelled';
    disconnect();
    onCancelled?.();
  });

  // Native EventSource error (network/server down)
  eventSource.onerror = () => {
    if (status === 'running' || status === 'pending') {
      // Don't surface noise — SSE will auto-reconnect or we'll poll via parent
    }
  };
}

async function handleCancel(): Promise<void> {
  isCancelling = true;
  try {
    await cancelInitJob(slug, jobId);
    toasts.info('Init cancelled');
  } catch {
    toasts.error('Failed to cancel init');
  } finally {
    isCancelling = false;
  }
}

function disconnect(): void {
  eventSource?.close();
  eventSource = null;
}

// Connect on mount if job is still running/pending
$effect(() => {
  if (status === 'running' || status === 'pending') {
    connect();
  }
  return () => disconnect();
});

onDestroy(() => {
  disconnect();
});

// ── Derived ───────────────────────────────────────────────────────────────────
const stepLabel: Record<string, string> = {
  detect_base_branch: 'Detecting base branch',
  ensure_clone: 'Cloning repository',
  create_initial_worktree: 'Preparing worktree',
  run_setup_script: 'Running setup script',
  done: 'Done',
};

const displayStep = $derived(currentStep ? (stepLabel[currentStep] ?? currentStep) : 'Starting…');
const isTerminal = $derived(status === 'succeeded' || status === 'failed' || status === 'cancelled');
const outputLines = $derived(output.trim().split('\n').filter(Boolean));
</script>

{#if !isTerminal || status === 'failed'}
  <div class="ipc-card glass-panel" role="region" aria-label="Workspace initializing">
    <!-- Header -->
    <div class="ipc-header">
      <span class="ipc-title">
        {#if status === 'failed'}
          Init failed
        {:else}
          Initializing workspace…
        {/if}
      </span>
      <span class="ipc-step" aria-live="polite">{displayStep}</span>
    </div>

    <!-- Progress bar -->
    <div class="ipc-bar-track" role="progressbar" aria-valuenow={progressPct} aria-valuemin={0} aria-valuemax={100} aria-label="Init progress">
      <div class="ipc-bar-fill" style:width="{progressPct}%"></div>
    </div>
    <span class="ipc-pct" aria-hidden="true">{progressPct}%</span>

    <!-- Output log -->
    {#if outputLines.length > 0}
      <div class="ipc-output" aria-label="Init output">
        <pre class="ipc-pre">{outputLines.join('\n')}</pre>
      </div>
    {/if}

    <!-- Actions -->
    <div class="ipc-actions">
      {#if status !== 'failed'}
        <button
          class="btn-pill btn-pill-ghost btn-pill-sm"
          onclick={handleCancel}
          disabled={isCancelling || isTerminal}
          aria-label="Cancel workspace init"
        >
          {isCancelling ? 'Cancelling…' : 'Cancel'}
        </button>
      {:else}
        <button
          class="btn-pill btn-pill-primary btn-pill-sm"
          onclick={() => onError?.('')}
          aria-label="Retry workspace init"
        >
          Retry
        </button>
      {/if}
    </div>
  </div>
{/if}

<style>
  .ipc-card {
    padding: var(--space-4);
    border-radius: var(--radius-lg);
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    margin-bottom: var(--space-4);
  }

  .ipc-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-2);
  }

  .ipc-title {
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg-primary);
  }

  .ipc-step {
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  .ipc-bar-track {
    height: 6px;
    background: var(--surface-2);
    border-radius: 999px;
    overflow: hidden;
  }

  .ipc-bar-fill {
    height: 100%;
    background: var(--accent);
    border-radius: 999px;
    transition: width 0.3s ease;
  }

  .ipc-pct {
    font-size: var(--text-xs);
    color: var(--fg-muted);
    text-align: right;
  }

  .ipc-output {
    background: var(--surface-1);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-2) var(--space-3);
    max-height: 140px;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .ipc-pre {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-secondary);
    white-space: pre-wrap;
    word-break: break-all;
    margin: 0;
  }

  .ipc-actions {
    display: flex;
    gap: var(--space-2);
    justify-content: flex-end;
  }
</style>
