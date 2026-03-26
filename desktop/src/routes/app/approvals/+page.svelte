<!-- src/routes/app/approvals/+page.svelte -->
<script lang="ts">
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import { approvalsStore } from '$lib/stores/approvals.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';
  import type { ApprovalStatus } from '$api/types';

  // Fetch on mount and whenever the active workspace changes.
  $effect(() => {
    const wsId = workspaceStore.activeWorkspaceId ?? undefined;
    void approvalsStore.fetchApprovals(wsId);
  });

  // Per-item comment state for approve/reject flows.
  let commentMap = $state<Record<string, string>>({});
  let actionPending = $state<Record<string, boolean>>({});

  function getComment(id: string): string {
    return commentMap[id] ?? '';
  }

  function setComment(id: string, value: string) {
    commentMap = { ...commentMap, [id]: value };
  }

  async function handleApprove(id: string) {
    actionPending = { ...actionPending, [id]: true };
    await approvalsStore.approve(id, getComment(id) || undefined);
    actionPending = { ...actionPending, [id]: false };
  }

  async function handleReject(id: string) {
    actionPending = { ...actionPending, [id]: true };
    await approvalsStore.reject(id, getComment(id) || undefined);
    actionPending = { ...actionPending, [id]: false };
  }

  const STATUS_LABELS: Record<ApprovalStatus, string> = {
    pending:  'Pending',
    approved: 'Approved',
    rejected: 'Rejected',
    expired:  'Expired',
  };

  function formatDate(iso: string): string {
    try {
      return new Date(iso).toLocaleDateString(undefined, {
        month: 'short', day: 'numeric', year: 'numeric',
      });
    } catch {
      return iso;
    }
  }
</script>

<div class="ap-moved-banner" role="note">
  Approvals are now in your Inbox.
  <a class="ap-moved-link" href="/app/inbox?tab=approvals">Go to Inbox → Approvals</a>
</div>

<PageShell
  title="Approvals"
  badge={approvalsStore.pendingCount > 0 ? approvalsStore.pendingCount : undefined}
  subtitle="{approvalsStore.filteredApprovals.length} request{approvalsStore.filteredApprovals.length === 1 ? '' : 's'}"
>
  {#snippet actions()}
    <div class="ap-filter-group" role="group" aria-label="Filter by status">
      {#each (['all', 'pending', 'approved', 'rejected'] as const) as status (status)}
        <button
          class="ap-filter-btn"
          class:ap-filter-btn--active={approvalsStore.filterStatus === status}
          onclick={() => approvalsStore.setFilter(status)}
          type="button"
        >
          {status === 'all' ? 'All' : STATUS_LABELS[status]}
        </button>
      {/each}
    </div>
  {/snippet}

  {#if approvalsStore.loading && approvalsStore.approvals.length === 0}
    <div class="ap-state" role="status" aria-live="polite">
      <div class="ap-spinner" aria-hidden="true"></div>
      <span>Loading approvals…</span>
    </div>
  {:else if approvalsStore.error && approvalsStore.approvals.length === 0}
    <div class="ap-state ap-state--error" role="alert">
      <p>Failed to load approvals: {approvalsStore.error}</p>
      <button class="ap-retry-btn" onclick={() => void approvalsStore.fetchApprovals()}>
        Retry
      </button>
    </div>
  {:else if approvalsStore.filteredApprovals.length === 0}
    <div class="ap-state" role="status">
      <p class="ap-empty-msg">
        {approvalsStore.filterStatus === 'all'
          ? 'No approval requests.'
          : `No ${approvalsStore.filterStatus} approvals.`}
      </p>
    </div>
  {:else}
    <ul class="ap-list" aria-label="Approval requests">
      {#each approvalsStore.filteredApprovals as approval (approval.id)}
        {@const isPending = approval.status === 'pending'}
        {@const busy = actionPending[approval.id] ?? false}
        <li class="ap-item">
          <!-- Header row -->
          <div class="ap-item-header">
            <div class="ap-item-meta">
              <span
                class="ap-status-badge"
                class:ap-status-badge--pending={approval.status === 'pending'}
                class:ap-status-badge--approved={approval.status === 'approved'}
                class:ap-status-badge--rejected={approval.status === 'rejected'}
                class:ap-status-badge--expired={approval.status === 'expired'}
              >
                {STATUS_LABELS[approval.status]}
              </span>
              {#if approval.entity_type}
                <span class="ap-entity-tag">{approval.entity_type}</span>
              {/if}
            </div>
            <time class="ap-date" datetime={approval.created_at}>
              {formatDate(approval.created_at)}
            </time>
          </div>

          <!-- Title + description -->
          <h3 class="ap-title">{approval.title}</h3>
          {#if approval.description}
            <p class="ap-description">{approval.description}</p>
          {/if}

          <!-- Requester info -->
          <div class="ap-requester">
            Requested by <span class="ap-requester-name">{approval.requester_name}</span>
            {#if approval.expires_at}
              <span class="ap-expires">· expires {formatDate(approval.expires_at)}</span>
            {/if}
          </div>

          <!-- Reviewer comment if resolved -->
          {#if approval.comment && !isPending}
            <p class="ap-reviewer-comment">"{approval.comment}"</p>
          {/if}

          <!-- Action area — only for pending items -->
          {#if isPending}
            <div class="ap-actions">
              <input
                class="ap-comment-input"
                type="text"
                placeholder="Optional comment…"
                value={getComment(approval.id)}
                oninput={(e) => setComment(approval.id, (e.target as HTMLInputElement).value)}
                aria-label="Comment for approval decision"
                disabled={busy}
              />
              <div class="ap-action-btns">
                <button
                  class="ap-btn ap-btn--approve"
                  onclick={() => handleApprove(approval.id)}
                  disabled={busy}
                  aria-label="Approve {approval.title}"
                  type="button"
                >
                  {busy ? 'Working…' : 'Approve'}
                </button>
                <button
                  class="ap-btn ap-btn--reject"
                  onclick={() => handleReject(approval.id)}
                  disabled={busy}
                  aria-label="Reject {approval.title}"
                  type="button"
                >
                  Reject
                </button>
              </div>
            </div>
          {/if}
        </li>
      {/each}
    </ul>
  {/if}
</PageShell>

<style>
  /* ── Moved banner ───────────────────────────────────────────────────────── */
  .ap-moved-banner {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding: 9px 14px;
    margin-bottom: 12px;
    border-radius: 6px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    font-size: 12px;
    color: var(--text-secondary);
  }

  .ap-moved-link {
    font-size: 12px;
    font-weight: 500;
    color: var(--text-primary);
    text-decoration: none;
    border-bottom: 1px solid var(--border-hover);
    white-space: nowrap;
  }

  .ap-moved-link:hover {
    color: var(--text-primary);
    border-bottom-color: var(--text-primary);
  }

  /* ── Filter bar ─────────────────────────────────────────────────────────── */
  .ap-filter-group {
    display: flex;
    gap: 4px;
  }

  .ap-filter-btn {
    height: 26px;
    padding: 0 10px;
    border-radius: 5px;
    font-size: 12px;
    font-weight: 500;
    background: transparent;
    border: 1px solid var(--border-default);
    color: var(--text-secondary);
    cursor: pointer;
    transition: background 100ms ease, color 100ms ease, border-color 100ms ease;
  }

  .ap-filter-btn:hover {
    background: var(--bg-elevated);
    color: var(--text-primary);
  }

  .ap-filter-btn--active {
    background: var(--bg-elevated);
    border-color: var(--border-hover);
    color: var(--text-primary);
  }

  /* ── States (loading / error / empty) ──────────────────────────────────── */
  .ap-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    min-height: 220px;
    font-size: 13px;
    color: var(--text-secondary);
  }

  .ap-state--error { color: var(--accent-error); }

  .ap-spinner {
    width: 22px;
    height: 22px;
    border-radius: 50%;
    border: 2px solid var(--border-default);
    border-top-color: var(--text-secondary);
    animation: ap-spin 0.75s linear infinite;
  }

  @keyframes ap-spin { to { transform: rotate(360deg); } }

  .ap-empty-msg { margin: 0; }

  .ap-retry-btn {
    padding: 6px 14px;
    border-radius: 6px;
    font-size: 12px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    color: var(--text-secondary);
    cursor: pointer;
  }

  .ap-retry-btn:hover { border-color: var(--border-hover); color: var(--text-primary); }

  /* ── List ───────────────────────────────────────────────────────────────── */
  .ap-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  /* ── Item card ──────────────────────────────────────────────────────────── */
  .ap-item {
    padding: 16px;
    border-radius: 8px;
    background: var(--bg-surface);
    border: 1px solid var(--border-default);
    display: flex;
    flex-direction: column;
    gap: 8px;
    transition: border-color 120ms ease;
  }

  .ap-item:hover { border-color: var(--border-hover); }

  .ap-item-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
  }

  .ap-item-meta {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  /* ── Status badge ───────────────────────────────────────────────────────── */
  .ap-status-badge {
    font-size: 11px;
    font-weight: 500;
    padding: 2px 8px;
    border-radius: 10px;
    background: var(--bg-elevated);
    color: var(--text-secondary);
    border: 1px solid var(--border-default);
  }

  .ap-status-badge--pending {
    background: rgba(245, 158, 11, 0.1);
    color: #fbbf24;
    border-color: rgba(245, 158, 11, 0.25);
  }

  .ap-status-badge--approved {
    background: rgba(34, 197, 94, 0.1);
    color: #4ade80;
    border-color: rgba(34, 197, 94, 0.25);
  }

  .ap-status-badge--rejected {
    background: rgba(239, 68, 68, 0.1);
    color: #f87171;
    border-color: rgba(239, 68, 68, 0.25);
  }

  .ap-status-badge--expired {
    background: var(--bg-elevated);
    color: var(--text-tertiary);
    border-color: var(--border-default);
  }

  .ap-entity-tag {
    font-size: 10px;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    padding: 2px 6px;
    border-radius: 4px;
    background: var(--bg-elevated);
    color: var(--text-tertiary);
  }

  .ap-date {
    font-size: 11px;
    color: var(--text-tertiary);
    flex-shrink: 0;
  }

  /* ── Content ────────────────────────────────────────────────────────────── */
  .ap-title {
    margin: 0;
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
    line-height: 1.3;
  }

  .ap-description {
    margin: 0;
    font-size: 13px;
    color: var(--text-secondary);
    line-height: 1.5;
  }

  .ap-requester {
    font-size: 12px;
    color: var(--text-tertiary);
  }

  .ap-requester-name {
    color: var(--text-secondary);
    font-weight: 500;
  }

  .ap-expires { color: var(--accent-warning); }

  .ap-reviewer-comment {
    margin: 0;
    font-size: 12px;
    font-style: italic;
    color: var(--text-secondary);
    padding: 8px 10px;
    background: var(--bg-elevated);
    border-left: 2px solid var(--border-hover);
    border-radius: 0 4px 4px 0;
  }

  /* ── Action area ────────────────────────────────────────────────────────── */
  .ap-actions {
    display: flex;
    align-items: center;
    gap: 8px;
    padding-top: 4px;
    flex-wrap: wrap;
  }

  .ap-comment-input {
    flex: 1;
    min-width: 160px;
    height: 30px;
    padding: 0 10px;
    border-radius: 6px;
    font-size: 12px;
    background: var(--bg-tertiary);
    border: 1px solid var(--border-default);
    color: var(--text-primary);
    transition: border-color 100ms ease;
  }

  .ap-comment-input::placeholder { color: var(--text-muted); }

  .ap-comment-input:focus {
    outline: none;
    border-color: var(--border-focus);
  }

  .ap-comment-input:disabled { opacity: 0.5; cursor: not-allowed; }

  .ap-action-btns {
    display: flex;
    gap: 6px;
    flex-shrink: 0;
  }

  .ap-btn {
    height: 30px;
    padding: 0 14px;
    border-radius: 6px;
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    transition: background 100ms ease, opacity 100ms ease;
    border: none;
  }

  .ap-btn:disabled { opacity: 0.5; cursor: not-allowed; }

  .ap-btn--approve {
    background: rgba(34, 197, 94, 0.15);
    color: #4ade80;
    border: 1px solid rgba(34, 197, 94, 0.3);
  }

  .ap-btn--approve:hover:not(:disabled) {
    background: rgba(34, 197, 94, 0.25);
  }

  .ap-btn--reject {
    background: rgba(239, 68, 68, 0.12);
    color: #f87171;
    border: 1px solid rgba(239, 68, 68, 0.25);
  }

  .ap-btn--reject:hover:not(:disabled) {
    background: rgba(239, 68, 68, 0.22);
  }
</style>
