<script lang="ts">
  /**
   * AgentStatusBar — thin strip above the composer showing live agent state.
   *
   * Derives status from the latest block in the session:
   *   tool_call  + running          → "Running {tool}..."
   *   agent_message + running       → "Thinking..."
   *   approval  + pending_approval  → "Waiting for approval..."
   *   error     + failed            → "Error: {message}"
   *   anything else                 → idle (hidden)
   *
   * CSS prefix: asb-
   */

  import { createQuery } from '@tanstack/svelte-query';
  import { writable } from 'svelte/store';
  import type { CreateQueryOptions } from '@tanstack/svelte-query';
  import { Wrench, Shield, AlertCircle } from 'lucide-svelte';
  import { blocksListQuery } from '$lib/api/queries/blocks.js';
  import type { Block, BlockList } from '$lib/domain/blocks/types.js';

  interface Props {
    sessionId: string;
  }

  let { sessionId }: Props = $props();

  // ── Data — writable store pattern required by tanstack-svelte-query ────────

  const qOptsStore = writable<CreateQueryOptions<Block[]>>(
    blocksListQuery(sessionId, { limit: 20 }) as CreateQueryOptions<Block[]>
  );

  $effect(() => {
    qOptsStore.set(
      blocksListQuery(sessionId, { limit: 20 }) as CreateQueryOptions<Block[]>
    );
  });

  const blocksQuery = createQuery<Block[]>(qOptsStore);

  // ── Derived status ────────────────────────────────────────────────────────

  type StatusState =
    | { state: 'thinking' }
    | { state: 'tool_call'; tool: string }
    | { state: 'approval' }
    | { state: 'error'; message: string }
    | null;

  function toolNameFromBlock(block: Block): string {
    const meta = block.metadata as Record<string, unknown>;
    if (typeof meta?.toolName === 'string') return meta.toolName;
    if (typeof meta?.tool_name === 'string') return meta.tool_name;
    if (typeof meta?.name === 'string') return meta.name;
    return 'tool';
  }

  const status = $derived.by((): StatusState => {
    const blocks: Block[] = $blocksQuery.data ?? [];
    if (!blocks.length) return null;

    // Walk from the end to find the last relevant in-flight block
    for (let i = blocks.length - 1; i >= 0; i--) {
      const b = blocks[i];
      if (b.kind === 'tool_call' && b.status === 'running') {
        return { state: 'tool_call', tool: toolNameFromBlock(b) };
      }
      if (b.kind === 'agent_message' && b.status === 'running') {
        return { state: 'thinking' };
      }
      if (b.kind === 'approval' && b.status === 'pending_approval') {
        return { state: 'approval' };
      }
      if (b.kind === 'error' && (b.status === 'failed' || b.status === 'running')) {
        return { state: 'error', message: b.outputText ?? b.inputText ?? 'Unknown error' };
      }
      // A completed block terminates the walk — nothing in-flight
      if (b.status === 'completed' || b.status === 'cancelled') break;
    }
    return null;
  });
</script>

{#if status !== null}
  <div
    class="asb-bar"
    class:asb-approval={status.state === 'approval'}
    class:asb-error={status.state === 'error'}
    role="status"
    aria-live="polite"
    aria-label="Agent status"
  >
    {#if status.state === 'thinking'}
      <span class="asb-dot asb-pulse" aria-hidden="true"></span>
      <span class="asb-label">Thinking...</span>
    {:else if status.state === 'tool_call'}
      <span class="asb-spinner" aria-hidden="true">
        <Wrench size={12} />
      </span>
      <span class="asb-label">Running {status.tool}...</span>
    {:else if status.state === 'approval'}
      <Shield size={13} class="asb-icon" aria-hidden="true" />
      <span class="asb-label">Waiting for approval...</span>
    {:else if status.state === 'error'}
      <AlertCircle size={13} class="asb-icon asb-icon-err" aria-hidden="true" />
      <span class="asb-label asb-label-err">Error: {status.message}</span>
    {/if}
  </div>
{/if}

<style>
  .asb-bar {
    display: flex;
    align-items: center;
    gap: 6px;
    height: 28px;
    padding: 0 14px;
    flex-shrink: 0;
    background: color-mix(in oklch, var(--dbg2, oklch(0.18 0.01 240)) 80%, transparent);
    border-top: 1px solid var(--dbd, oklch(0.28 0.01 240));
    font-family: var(--font-sans, system-ui);
    font-size: 11px;
    color: var(--dt3, oklch(0.6 0.01 240));
    transition: background 0.2s ease;
  }

  /* Approval state — gentle amber highlight */
  .asb-bar.asb-approval {
    background: color-mix(in oklch, oklch(0.65 0.15 80) 8%, var(--dbg2, oklch(0.18 0.01 240)));
    animation: asb-highlight 2s ease-in-out infinite;
  }

  /* Error state */
  .asb-bar.asb-error {
    background: color-mix(in oklch, oklch(0.55 0.22 25) 10%, var(--dbg2, oklch(0.18 0.01 240)));
  }

  /* Pulsing dot for thinking */
  .asb-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: var(--dt2, oklch(0.7 0.05 240));
    flex-shrink: 0;
  }

  .asb-pulse {
    animation: asb-pulse 1.4s ease-in-out infinite;
  }

  /* Spinning wrench wrapper for tool_call */
  .asb-spinner {
    display: flex;
    align-items: center;
    color: var(--dt2, oklch(0.7 0.05 240));
    animation: asb-spin 1.2s linear infinite;
    flex-shrink: 0;
  }

  :global(.asb-icon) {
    color: var(--dt3, oklch(0.6 0.01 240));
    flex-shrink: 0;
  }

  :global(.asb-icon-err) {
    color: oklch(0.55 0.22 25);
  }

  .asb-label {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    flex: 1;
    min-width: 0;
  }

  .asb-label-err {
    color: oklch(0.55 0.22 25);
  }

  /* Animations */
  @keyframes asb-pulse {
    0%, 100% { opacity: 1; transform: scale(1); }
    50%       { opacity: 0.35; transform: scale(0.75); }
  }

  @keyframes asb-spin {
    to { transform: rotate(360deg); }
  }

  @keyframes asb-highlight {
    0%, 100% { opacity: 1; }
    50%       { opacity: 0.7; }
  }
</style>
