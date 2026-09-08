<script lang="ts">
/**
 * ReviewDetailModal — full preview + approve/reject/request-changes actions.
 * CSS prefix: rdm- (ReviewDetailModal)
 * LOC target: ≤ 200.
 */
import type {
  ApproveReviewBody,
  RejectReviewBody,
  RequestChangesBody,
  Review,
} from '$lib/domain/reviews/types.js';

interface Props {
  review: Review;
  isPending?: boolean;
  onApprove: (body: ApproveReviewBody) => void;
  onReject: (body: RejectReviewBody) => void;
  onRequestChanges: (body: RequestChangesBody) => void;
  onResubmit?: () => void;
  onClose: () => void;
}

let {
  review,
  isPending = false,
  onApprove,
  onReject,
  onRequestChanges,
  onResubmit,
  onClose,
}: Props = $props();

let feedback = $state('');
const isPending_ = $derived(isPending);
const isDecided = $derived(review.status !== 'pending');
const isChangesRequested = $derived(review.status === 'changes_requested');
const rawRecord = $derived(JSON.stringify(review, null, 2));

function handleKeydown(e: KeyboardEvent): void {
  if (e.key === 'Escape') onClose();
}

function handleBackdropClick(e: MouseEvent): void {
  if ((e.target as HTMLElement).classList.contains('rdm-backdrop')) onClose();
}

function handleApprove(): void {
  onApprove({});
}

function handleReject(): void {
  onReject({ feedback: feedback.trim() || undefined });
}

function handleRequestChanges(): void {
  onRequestChanges({ feedback: feedback.trim() || undefined });
}

function statusClass(status: string): string {
  if (status === 'pending') return 'rdm-pill rdm-pill--pending';
  if (status === 'approved') return 'rdm-pill rdm-pill--approved';
  if (status === 'rejected') return 'rdm-pill rdm-pill--rejected';
  if (status === 'changes_requested') return 'rdm-pill rdm-pill--changes';
  return 'rdm-pill rdm-pill--expired';
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleString();
}

function creationPath(r: Review): string {
  if (r.kind === 'artifact') {
    return 'POST /api/v1/reviews or Canopy.Reviews.request_artifact/1';
  }
  if (r.kind === 'tool_call') {
    return 'Agent tool dispatch or Canopy.Reviews.request_tool_call/4';
  }
  return 'Canopy.Reviews.request_hire_agent/5 from canopy.spawn_session';
}

function decisionPath(status: string): string {
  if (status === 'approved') return 'POST /api/v1/reviews/:id/approve';
  if (status === 'rejected') return 'POST /api/v1/reviews/:id/reject';
  if (status === 'changes_requested') return 'POST /api/v1/reviews/:id/request_changes';
  if (status === 'pending') return 'Waiting for approve, reject, or request_changes';
  return 'Expired';
}
</script>

<svelte:window onkeydown={handleKeydown} />

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="rdm-backdrop" onclick={handleBackdropClick}>
  <div class="rdm-modal glass-panel" role="dialog" aria-modal="true" aria-label="Review detail">
    <header class="rdm-header">
      <div class="rdm-title-row">
        <span class={statusClass(review.status)}>{review.status.replace('_', ' ')}</span>
        <span class="rdm-kind-badge">{review.kind === 'tool_call' ? 'Tool call' : review.kind === 'hire_agent' ? 'Hire agent' : (review.artifactType ?? 'Artifact')}</span>
        {#if review.revisionCount > 0}
          <span class="rdm-revision-badge" title="Revision {review.revisionCount}">rev {review.revisionCount}</span>
        {/if}
        {#if review.agentId}
          <span class="rdm-agent">by {review.agentId}</span>
        {/if}
        <span class="rdm-time">{formatTime(review.requestedAt)}</span>
      </div>
      <button class="rdm-close btn-compact btn-compact-ghost" onclick={onClose} aria-label="Close modal">&times;</button>
    </header>

    <div class="rdm-body">
      <section class="rdm-section">
        <h3 class="rdm-section-label">Saved record</h3>
        <dl class="rdm-record-grid">
          <div>
            <dt>ID</dt>
            <dd class="rdm-mono">{review.id}</dd>
          </div>
          <div>
            <dt>Workspace</dt>
            <dd>{review.workspaceSlug ?? 'global'}</dd>
          </div>
          <div>
            <dt>Created by</dt>
            <dd>{creationPath(review)}</dd>
          </div>
          <div>
            <dt>Decision path</dt>
            <dd>{decisionPath(review.status)}</dd>
          </div>
          {#if review.sessionId}
            <div>
              <dt>Session</dt>
              <dd class="rdm-mono">{review.sessionId}</dd>
            </div>
          {/if}
          {#if review.reviewerId}
            <div>
              <dt>Reviewer</dt>
              <dd>{review.reviewerId}</dd>
            </div>
          {/if}
          {#if review.expiresAt}
            <div>
              <dt>Expires</dt>
              <dd>{formatTime(review.expiresAt)}</dd>
            </div>
          {/if}
        </dl>
      </section>

      <!-- Preview -->
      {#if review.kind === 'artifact' && review.artifactPreview}
        <section class="rdm-section">
          <h3 class="rdm-section-label">Artifact preview</h3>
          <pre class="rdm-preview">{review.artifactPreview}</pre>
        </section>
      {/if}

      {#if review.kind === 'tool_call'}
        <section class="rdm-section">
          <h3 class="rdm-section-label">Tool: <code class="rdm-code">{review.toolName}</code></h3>
          <pre class="rdm-preview rdm-code-block">{JSON.stringify(review.toolArgs ?? {}, null, 2)}</pre>
        </section>
      {/if}

      {#if review.kind === 'hire_agent'}
        <section class="rdm-section">
          <h3 class="rdm-section-label">Spawn request</h3>
          <div class="rdm-hire-grid">
            {#if review.toolArgs?.['child_agent_slug']}
              <span class="rdm-hire-label">Agent</span>
              <code class="rdm-code rdm-hire-value">{review.toolArgs['child_agent_slug']}</code>
            {/if}
            {#if review.sessionId}
              <span class="rdm-hire-label">Parent session</span>
              <code class="rdm-code rdm-hire-value">{review.sessionId.slice(0, 8)}…</code>
            {/if}
          </div>
          {#if review.toolArgs?.['initial_prompt']}
            <pre class="rdm-preview rdm-hire-prompt">{review.toolArgs['initial_prompt']}</pre>
          {/if}
        </section>
      {/if}

      <section class="rdm-section">
        <h3 class="rdm-section-label">Raw database payload</h3>
        <pre class="rdm-preview rdm-code-block">{rawRecord}</pre>
      </section>

      <!-- Decision feedback if already decided -->
      {#if isDecided && review.feedback}
        <section class="rdm-section">
          <h3 class="rdm-section-label">Reviewer feedback</h3>
          <p class="rdm-feedback-text">{review.feedback}</p>
        </section>
      {/if}

      <!-- Feedback textarea (only for pending) -->
      {#if !isDecided}
        <section class="rdm-section">
          <label class="rdm-section-label" for="rdm-feedback">Feedback (optional)</label>
          <textarea
            id="rdm-feedback"
            class="rdm-textarea"
            bind:value={feedback}
            placeholder="Explain your decision or request…"
            rows={3}
            disabled={isPending_}
          ></textarea>
        </section>
      {/if}
    </div>

    <footer class="rdm-footer">
      <button class="btn-pill btn-pill-secondary btn-pill-sm" onclick={onClose}>
        Close
      </button>
      {#if isChangesRequested && onResubmit}
        <button
          class="btn-pill btn-pill-secondary btn-pill-sm rdm-resubmit-btn"
          onclick={onResubmit}
          disabled={isPending_}
          aria-label="Resubmit for review"
        >
          Resubmit
        </button>
      {/if}
      {#if !isDecided}
        <button
          class="btn-pill btn-pill-secondary btn-pill-sm rdm-changes-btn"
          onclick={handleRequestChanges}
          disabled={isPending_}
          aria-label="Request changes"
        >
          Request changes
        </button>
        <button
          class="btn-pill btn-pill-secondary btn-pill-sm rdm-reject-btn"
          onclick={handleReject}
          disabled={isPending_}
          aria-label="Reject"
        >
          Reject
        </button>
        <button
          class="btn-pill btn-pill-primary btn-pill-sm"
          onclick={handleApprove}
          disabled={isPending_}
          aria-busy={isPending_}
          aria-label="Approve"
        >
          {isPending_ ? 'Working…' : 'Approve'}
        </button>
      {/if}
    </footer>
  </div>
</div>

<style>
  .rdm-backdrop {
    position: fixed;
    inset: 0;
    background: color-mix(in oklch, var(--bg) 40%, transparent);
    backdrop-filter: blur(4px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 900;
    padding: var(--space-4);
  }

  .rdm-modal {
    width: 100%;
    max-width: 600px;
    max-height: 80vh;
    display: flex;
    flex-direction: column;
    border-radius: var(--radius-xl, 16px);
    overflow: hidden;
    box-shadow: 0 24px 80px color-mix(in oklch, var(--bg) 0%, black 30%);
  }

  .rdm-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: var(--space-2);
    padding: var(--space-4) var(--space-5) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .rdm-title-row {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: var(--space-2);
    flex: 1;
  }

  .rdm-pill {
    padding: 2px 8px;
    border-radius: 9999px;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .rdm-pill--pending { background: color-mix(in oklch, oklch(0.85 0.18 55) 20%, transparent); color: oklch(0.65 0.18 55); }
  .rdm-pill--approved { background: color-mix(in oklch, oklch(0.75 0.18 145) 20%, transparent); color: oklch(0.55 0.18 145); }
  .rdm-pill--rejected { background: color-mix(in oklch, oklch(0.65 0.25 25) 20%, transparent); color: oklch(0.55 0.25 25); }
  .rdm-pill--changes { background: color-mix(in oklch, oklch(0.75 0.18 240) 20%, transparent); color: oklch(0.55 0.18 240); }
  .rdm-pill--expired { background: var(--bg-inset); color: var(--fg-muted); }

  .rdm-kind-badge {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    padding: 2px 6px;
    border-radius: var(--radius-sm);
  }

  .rdm-agent, .rdm-time {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  .rdm-close { color: var(--fg-muted); font-size: 18px; line-height: 1; }

  .rdm-body {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-4) var(--space-5);
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }

  .rdm-section { display: flex; flex-direction: column; gap: var(--space-2); }

  .rdm-section-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    margin: 0;
  }

  .rdm-preview {
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-3);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg);
    white-space: pre-wrap;
    word-break: break-word;
    margin: 0;
    max-height: 240px;
    overflow-y: auto;
  }

  .rdm-code { font-family: var(--font-mono); font-size: inherit; }
  .rdm-mono { font-family: var(--font-mono); }
  .rdm-code-block { color: var(--fg-muted); }

  .rdm-record-grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: var(--space-2);
    margin: 0;
    padding: var(--space-3);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    background: var(--bg-inset);
  }

  .rdm-record-grid div {
    display: grid;
    grid-template-columns: 96px minmax(0, 1fr);
    gap: var(--space-3);
    align-items: baseline;
  }

  .rdm-record-grid dt {
    color: var(--fg-subtle);
    font-size: var(--text-xs);
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .rdm-record-grid dd {
    min-width: 0;
    margin: 0;
    color: var(--fg-muted);
    font-size: var(--text-xs);
    overflow-wrap: anywhere;
  }

  .rdm-feedback-text {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
    padding: var(--space-2) var(--space-3);
    background: var(--bg-inset);
    border-radius: var(--radius-md);
    border: 1px solid var(--border);
  }

  .rdm-textarea {
    padding: 6px 10px;
    border-radius: var(--radius-md);
    border: 1px solid var(--border);
    background: var(--bg-inset);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    width: 100%;
    resize: vertical;
    transition: border-color 0.12s ease;
  }

  .rdm-textarea:focus { border-color: color-mix(in oklch, var(--fg) 40%, transparent); }

  .rdm-footer {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: var(--space-2);
    padding: var(--space-3) var(--space-5) var(--space-4);
    border-top: 1px solid var(--border);
    flex-shrink: 0;
  }

  .rdm-reject-btn { color: oklch(0.55 0.25 25); }
  .rdm-changes-btn { color: oklch(0.55 0.18 240); }
  .rdm-resubmit-btn { color: oklch(0.55 0.18 55); }

  .rdm-revision-badge {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    padding: 1px 5px;
    border-radius: var(--radius-sm);
  }

  /* hire_agent preview */
  .rdm-hire-grid {
    display: grid;
    grid-template-columns: max-content 1fr;
    gap: 4px var(--space-3);
    align-items: center;
    margin-bottom: var(--space-2);
  }

  .rdm-hire-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    white-space: nowrap;
  }

  .rdm-hire-value {
    font-size: var(--text-xs);
    color: var(--fg-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .rdm-hire-prompt {
    margin-top: var(--space-2);
  }
</style>
