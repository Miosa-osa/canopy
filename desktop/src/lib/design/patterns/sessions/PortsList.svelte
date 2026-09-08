<script lang="ts">
/**
 * PortsList — forwarded ports panel for a session.
 * CSS prefix: pls-
 * Shows listening TCP/UDP ports detected via lsof for the session's pty process.
 * Renders in session detail right sidebar "Ports" tab.
 * LOC target: ≤ 140.
 */

import { createQuery } from '@tanstack/svelte-query';
import { Copy, ExternalLink } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { apiGet } from '$lib/api/client.js';
import { toasts } from '$lib/stores/toasts.svelte.js';

interface PortEntry {
  port: number;
  proto: string;
  state: string;
  pid: number;
}

interface Props {
  sessionId: string;
}

let { sessionId }: Props = $props();

const queryOptsStore = writable(
  untrack(() => ({
    queryKey: ['sessions', sessionId, 'ports'],
    queryFn: () =>
      apiGet<{ data: PortEntry[] }>(`/sessions/${sessionId}/ports`).then((r) => r.data ?? []),
    refetchInterval: 5_000,
    enabled: !!sessionId,
  }))
);

$effect(() => {
  queryOptsStore.set({
    queryKey: ['sessions', sessionId, 'ports'],
    queryFn: () =>
      apiGet<{ data: PortEntry[] }>(`/sessions/${sessionId}/ports`).then((r) => r.data ?? []),
    refetchInterval: 5_000,
    enabled: !!sessionId,
  });
});

const portsQuery = createQuery<PortEntry[]>(queryOptsStore);

function localUrl(port: number): string {
  return `http://localhost:${port}`;
}

async function copyUrl(port: number): Promise<void> {
  try {
    await navigator.clipboard.writeText(localUrl(port));
    toasts.success(`Copied localhost:${port}`);
  } catch {
    toasts.error('Clipboard unavailable');
  }
}

function openInBrowser(port: number): void {
  window.open(localUrl(port), '_blank', 'noopener,noreferrer');
}
</script>

<div class="pls-root" aria-label="Forwarded ports">
  {#if $portsQuery.isLoading}
    <p class="pls-hint">Scanning ports…</p>
  {:else if !$portsQuery.data?.length}
    <p class="pls-hint">No listening ports detected.</p>
  {:else}
    <ul class="pls-list" role="list">
      {#each ($portsQuery.data ?? []) as entry (entry.port + entry.proto)}
        <li class="pls-row">
          <span class="pls-proto pls-mono">{entry.proto}</span>
          <span class="pls-port pls-mono">{entry.port}</span>
          <span class="pls-state">{entry.state}</span>
          <div class="pls-actions">
            <button
              class="pls-btn"
              onclick={() => copyUrl(entry.port)}
              aria-label="Copy localhost:{entry.port} URL"
              title="Copy URL"
            >
              <Copy size={12} aria-hidden="true" />
            </button>
            <button
              class="pls-btn"
              onclick={() => openInBrowser(entry.port)}
              aria-label="Open port {entry.port} in browser"
              title="Open in browser"
            >
              <ExternalLink size={12} aria-hidden="true" />
            </button>
          </div>
        </li>
      {/each}
    </ul>
  {/if}
</div>

<style>
  .pls-root {
    padding: var(--space-3);
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .pls-hint {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    padding: var(--space-4) var(--space-2);
    text-align: center;
    margin: 0;
  }

  .pls-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .pls-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-2);
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: var(--bg-elevated);
  }

  .pls-mono {
    font-family: var(--font-mono);
  }

  .pls-proto {
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
    min-width: 28px;
    text-transform: uppercase;
  }

  .pls-port {
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
    min-width: 44px;
  }

  .pls-state {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    flex: 1;
  }

  .pls-actions {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    margin-left: auto;
  }

  .pls-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: var(--space-1);
    border: none;
    background: transparent;
    border-radius: var(--radius-sm);
    cursor: pointer;
    color: var(--fg-subtle);
    transition: background 0.1s ease, color 0.1s ease;
  }

  .pls-btn:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg);
  }
</style>
