<script lang="ts">
/**
 * WorkspaceSessionsTab — sessions list for workspace detail.
 * CSS prefix: wss-
 */
import { FolderOpen } from 'lucide-svelte';
import { goto } from '$app/navigation';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';

interface Props {
  workspaceSlug: string;
  sessions: Record<string, unknown>[];
  isLoading: boolean;
}

let { workspaceSlug, sessions, isLoading }: Props = $props();

function getField(s: Record<string, unknown>, ...keys: string[]): string {
  for (const k of keys) {
    if (s[k] !== undefined && s[k] !== null) return String(s[k]);
  }
  return '—';
}

function formatDate(iso: string | null): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}
</script>

<div class="wss-panel">
  <div class="wss-header">
    <h2 class="wss-title">Sessions</h2>
    <button
      class="btn-pill btn-pill-primary btn-pill-sm"
      onclick={() => goto(`/sessions?workspace=${workspaceSlug}`)}
      aria-label="New session in this workspace"
    >New session</button>
  </div>

  {#if isLoading}
    <div class="wss-skeleton">
      {#each Array(3) as _, i (i)}
        <div class="wss-sk-row glass-card"></div>
      {/each}
    </div>
  {:else if sessions.length === 0}
    <EmptyState
      icon={FolderOpen as never}
      title="No sessions yet"
      body="Create a new session in this workspace to get started."
    />
  {:else}
    <ul class="wss-list" aria-label="Workspace sessions">
      {#each sessions as s (getField(s, 'id'))}
        <li class="wss-row glass-card">
          <span class="wss-runtime">{getField(s, 'runtime_type', 'runtimeType')}</span>
          <span class="wss-status wss-status-{getField(s, 'status')}">{getField(s, 'status')}</span>
          <span class="wss-date">{formatDate((s['inserted_at'] ?? s['insertedAt'] ?? null) as string | null)}</span>
          <a
            class="wss-link"
            href="/sessions/{getField(s, 'id')}"
            aria-label="Open session {getField(s, 'id')}"
          >Open &rarr;</a>
        </li>
      {/each}
    </ul>
  {/if}
</div>

<style>
  .wss-panel {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }

  .wss-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
  }

  .wss-title {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    margin: 0;
  }

  .wss-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .wss-row {
    display: flex;
    align-items: center;
    gap: var(--space-4);
    padding: var(--space-3) var(--space-4);
    flex-wrap: wrap;
  }

  .wss-runtime {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    flex: 1;
    min-width: 100px;
  }

  .wss-status {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    padding: 2px 8px;
    border-radius: 9999px;
    background: var(--bg-subtle);
    color: var(--fg-muted);
  }

  .wss-status-running  { background: color-mix(in oklch, var(--cnp-accent) 15%, transparent); color: var(--cnp-accent); }
  .wss-status-completed { background: color-mix(in oklch, var(--signal-success) 15%, transparent); color: var(--signal-success); }
  .wss-status-error    { background: color-mix(in oklch, var(--signal-error) 15%, transparent); color: var(--signal-error); }

  .wss-date {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    flex-shrink: 0;
  }

  .wss-link {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg-muted);
    text-decoration: none;
    flex-shrink: 0;
    transition: color 0.12s ease;
  }

  .wss-link:hover { color: var(--cnp-accent); }

  .wss-skeleton {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .wss-sk-row {
    height: 48px;
    animation: wss-pulse 1.5s ease-in-out infinite;
  }

  @keyframes wss-pulse {
    0%, 100% { opacity: 0.3; }
    50% { opacity: 0.65; }
  }
</style>
