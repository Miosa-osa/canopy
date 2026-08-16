<script lang="ts">
  /**
   * ApprovalBlock — kind='approval' renderer.
   *
   * Inline Approve / Edit / Deny buttons that wire to the **existing**
   * /api/v1/governance/approvals endpoints via the existing Governance
   * query factories (no new endpoints invented). Reads the approval id
   * from `block.metadata.approval_id`.
   *
   * Thin component — uses TanStack mutations from the existing governance
   * queries module. On success, invalidates the blocks query for this
   * session so the parent stream refetches.
   *
   * CSS prefix: aprv-
   */

  import { Check, Pencil, X } from 'lucide-svelte';
  import {
    type CreateMutationOptions,
    createMutation,
    useQueryClient,
  } from '@tanstack/svelte-query';

  import { Button } from '$lib/design/foundation/index.js';
  import {
    approveApprovalMutation,
    rejectApprovalMutation,
  } from '$lib/api/queries/governance.js';
  import { blocksKey } from '$lib/api/queries/blocks.js';
  import type { Approval, DecisionBody } from '$lib/domain/governance/types.js';
  import type { Block } from '$lib/domain/blocks/types.js';

  interface Props {
    block: Block;
    /** Optional callback fired after a successful decision lands. */
    onDecision?: (decision: 'approved' | 'rejected') => void;
    /** Optional handler for the "Edit" action — usually opens an editor. */
    onEdit?: (block: Block) => void;
  }

  let { block, onDecision, onEdit }: Props = $props();

  const queryClient = useQueryClient();

  const approvalId = $derived(
    typeof block.metadata?.approval_id === 'string'
      ? (block.metadata.approval_id as string)
      : null,
  );

  const summary = $derived(
    typeof block.metadata?.summary === 'string'
      ? (block.metadata.summary as string)
      : (block.inputText ?? 'Approval requested'),
  );

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

<div class="aprv-root" data-status={block.status}>
  <p class="aprv-summary">{summary}</p>

  {#if !approvalId}
    <p class="aprv-warn">No approval_id in metadata — cannot decide.</p>
  {:else if isPending}
    <div class="aprv-actions">
      <Button
        variant="success"
        disabled={isBusy}
        onclick={handleApprove}
        aria-label="Approve request"
      >
        {#snippet prefix()}<Check size={14} aria-hidden="true" />{/snippet}
        Approve
      </Button>
      {#if onEdit}
        <Button
          variant="secondary"
          disabled={isBusy}
          onclick={() => onEdit?.(block)}
          aria-label="Edit request"
        >
          {#snippet prefix()}<Pencil size={14} aria-hidden="true" />{/snippet}
          Edit
        </Button>
      {/if}
      <Button
        variant="error"
        disabled={isBusy}
        onclick={handleReject}
        aria-label="Deny request"
      >
        {#snippet prefix()}<X size={14} aria-hidden="true" />{/snippet}
        Deny
      </Button>
    </div>
  {:else}
    <p class="aprv-resolved">Resolved · {block.status}</p>
  {/if}
</div>

<style>
  .aprv-root {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .aprv-summary {
    margin: 0;
    font-family: var(--font-sans);
    font-size: 14px;
    line-height: 1.55;
    color: var(--fg);
  }

  .aprv-actions {
    display: flex;
    gap: var(--space-2);
    flex-wrap: wrap;
  }

  .aprv-warn {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--signal-error, oklch(0.55 0.22 25));
  }

  .aprv-resolved {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    font-style: italic;
  }
</style>
