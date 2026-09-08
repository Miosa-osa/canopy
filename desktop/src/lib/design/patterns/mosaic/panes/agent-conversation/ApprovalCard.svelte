<script lang="ts">
/**
 * ApprovalCard — inline approval card for governance blocks.
 *
 * Rendered by Block.svelte when block.kind === 'approval' (via the existing
 * ApprovalBlock). This component provides a standalone card variant with an
 * amber warning border, tool-params preview, and Approve/Reject buttons that
 * call the existing governance mutation endpoints.
 *
 * After a decision the card collapses to a single-line status line.
 * Wires to POST /governance/approvals/:id/approve|reject via the existing
 * approveApprovalMutation / rejectApprovalMutation factories.
 *
 * CSS prefix: apc-
 */

import { type CreateMutationOptions, createMutation, useQueryClient } from '@tanstack/svelte-query';
import { Check, X } from 'lucide-svelte';
import { blocksKey } from '$lib/api/queries/blocks.js';
import { approveApprovalMutation, rejectApprovalMutation } from '$lib/api/queries/governance.js';
import type { Block } from '$lib/domain/blocks/types.js';
import type { Approval, DecisionBody } from '$lib/domain/governance/types.js';

interface Props {
  block: Block;
  onDecision?: (decision: 'approved' | 'rejected') => void;
}

let { block, onDecision }: Props = $props();

const queryClient = useQueryClient();

const approvalId = $derived(
  typeof block.metadata?.approval_id === 'string' ? (block.metadata.approval_id as string) : null
);

const actionDescription = $derived(
  typeof block.metadata?.summary === 'string'
    ? (block.metadata.summary as string)
    : (block.inputText ?? 'Action requires approval')
);

const toolName = $derived(
  typeof block.metadata?.tool_name === 'string'
    ? (block.metadata.tool_name as string)
    : typeof block.metadata?.toolName === 'string'
      ? (block.metadata.toolName as string)
      : null
);

/** Compact JSON preview of params — truncated to 120 chars. */
const paramsPreview = $derived.by(() => {
  const p = block.metadata?.params ?? block.metadata?.args;
  if (!p) return null;
  try {
    const s = JSON.stringify(p);
    return s.length > 120 ? `${s.slice(0, 120)}…` : s;
  } catch {
    return null;
  }
});

type DecisionInput = { id: string; body?: DecisionBody };

const approve = createMutation<Approval, Error, DecisionInput>({
  ...approveApprovalMutation(),
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: blocksKey(block.sessionId) });
    onDecision?.('approved');
  },
} as CreateMutationOptions<Approval, Error, DecisionInput>);

const reject = createMutation<Approval, Error, DecisionInput>({
  ...rejectApprovalMutation(),
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: blocksKey(block.sessionId) });
    onDecision?.('rejected');
  },
} as CreateMutationOptions<Approval, Error, DecisionInput>);

const isPending = $derived(block.status === 'pending_approval');
const isBusy = $derived($approve.isPending || $reject.isPending);

function handleApprove() {
  if (!approvalId) return;
  $approve.mutate({ id: approvalId });
}

function handleReject() {
  if (!approvalId) return;
  $reject.mutate({ id: approvalId });
}
</script>

<div class="apc-root" data-status={block.status}>
  {#if isPending}
    <div class="apc-header">
      <span class="apc-badge">Approval needed</span>
      {#if toolName}
        <code class="apc-tool">{toolName}</code>
      {/if}
    </div>

    <p class="apc-description">{actionDescription}</p>

    {#if paramsPreview}
      <pre class="apc-params">{paramsPreview}</pre>
    {/if}

    {#if !approvalId}
      <p class="apc-warn">Missing approval_id — cannot decide.</p>
    {:else}
      <div class="apc-actions">
        <button
          class="apc-btn apc-btn--approve"
          onclick={handleApprove}
          disabled={isBusy}
          aria-label="Approve action"
        >
          <Check size={13} aria-hidden="true" />
          Approve
        </button>
        <button
          class="apc-btn apc-btn--reject"
          onclick={handleReject}
          disabled={isBusy}
          aria-label="Reject action"
        >
          <X size={13} aria-hidden="true" />
          Reject
        </button>
      </div>
    {/if}
  {:else}
    <p class="apc-resolved">
      {block.status === 'completed' ? 'Approved' : 'Rejected'}
      {block.status === 'completed' ? '✓' : '✗'}
    </p>
  {/if}
</div>

<style>
  .apc-root {
    border: 1px solid color-mix(in oklch, oklch(0.75 0.16 80) 45%, var(--dbd, oklch(0.28 0.01 240)));
    border-radius: var(--radius-lg, 8px);
    padding: 10px 12px;
    background: color-mix(in oklch, oklch(0.75 0.16 80) 5%, var(--dbg2, oklch(0.18 0.01 240)));
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .apc-root[data-status='completed'] {
    border-color: color-mix(in oklch, oklch(0.65 0.18 145) 35%, var(--dbd, oklch(0.28 0.01 240)));
    background: color-mix(in oklch, oklch(0.65 0.18 145) 4%, var(--dbg2, oklch(0.18 0.01 240)));
  }

  .apc-root[data-status='failed'],
  .apc-root[data-status='cancelled'] {
    border-color: color-mix(in oklch, oklch(0.55 0.22 25) 30%, var(--dbd, oklch(0.28 0.01 240)));
    background: color-mix(in oklch, oklch(0.55 0.22 25) 4%, var(--dbg2, oklch(0.18 0.01 240)));
  }

  .apc-header {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .apc-badge {
    font-family: var(--font-sans, system-ui);
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: oklch(0.75 0.16 80);
  }

  .apc-tool {
    font-family: var(--font-mono, monospace);
    font-size: 11px;
    padding: 1px 6px;
    border-radius: 4px;
    background: color-mix(in oklch, var(--dt, oklch(0.9 0.01 240)) 8%, transparent);
    color: var(--dt2, oklch(0.7 0.05 240));
  }

  .apc-description {
    margin: 0;
    font-family: var(--font-sans, system-ui);
    font-size: 13px;
    line-height: 1.5;
    color: var(--dt, oklch(0.9 0.01 240));
  }

  .apc-params {
    margin: 0;
    padding: 6px 8px;
    border-radius: 4px;
    background: color-mix(in oklch, var(--dbg, oklch(0.13 0.01 240)) 60%, transparent);
    font-family: var(--font-mono, monospace);
    font-size: 11px;
    color: var(--dt3, oklch(0.6 0.01 240));
    white-space: pre-wrap;
    word-break: break-all;
    overflow: hidden;
  }

  .apc-actions {
    display: flex;
    gap: 6px;
    margin-top: 2px;
  }

  .apc-btn {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 4px 12px;
    border-radius: var(--radius-sm, 4px);
    border: 1px solid transparent;
    font-family: var(--font-sans, system-ui);
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: opacity 0.15s ease;
  }

  .apc-btn:disabled { opacity: 0.45; cursor: not-allowed; }
  .apc-btn:hover:not(:disabled) { opacity: 0.8; }

  .apc-btn--approve {
    background: oklch(0.65 0.18 145);
    color: oklch(0.1 0.01 240);
    border-color: oklch(0.65 0.18 145);
  }

  .apc-btn--reject {
    background: oklch(0.55 0.22 25);
    color: oklch(0.97 0.01 80);
    border-color: oklch(0.55 0.22 25);
  }

  .apc-warn {
    margin: 0;
    font-family: var(--font-sans, system-ui);
    font-size: 11px;
    color: oklch(0.55 0.22 25);
  }

  .apc-resolved {
    margin: 0;
    font-family: var(--font-sans, system-ui);
    font-size: 12px;
    font-weight: 500;
    color: var(--dt3, oklch(0.6 0.01 240));
  }
</style>
