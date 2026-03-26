<!-- src/routes/app/inbox/+page.svelte -->
<script lang="ts">
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import InboxFilters from '$lib/components/inbox/InboxFilters.svelte';
  import InboxFeed from '$lib/components/inbox/InboxFeed.svelte';
  import { inboxStore } from '$lib/stores/inbox.svelte';
  import { approvalsStore } from '$lib/stores/approvals.svelte';
  import { notificationsStore } from '$lib/stores/notifications.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';
  import type { ApprovalStatus, NotificationCategory } from '$api/types';

  // ── Tab state — driven by ?tab= query param ──────────────────────────────
  type InboxTab = 'all' | 'messages' | 'approvals' | 'notifications';

  let activeTab = $derived.by<InboxTab>(() => {
    const t = $page.url.searchParams.get('tab');
    if (t === 'messages' || t === 'approvals' || t === 'notifications') return t;
    return 'all';
  });

  function setTab(tab: InboxTab) {
    const url = new URL($page.url);
    if (tab === 'all') {
      url.searchParams.delete('tab');
    } else {
      url.searchParams.set('tab', tab);
    }
    void goto(url.toString(), { replaceState: true, keepFocus: true });
  }

  // ── Fetch all stores on mount / workspace change ─────────────────────────
  $effect(() => {
    const wsId = workspaceStore.activeWorkspaceId ?? undefined;
    void inboxStore.fetchItems(wsId);
    void approvalsStore.fetchApprovals(wsId);
    void notificationsStore.fetchNotifications();
    void notificationsStore.fetchBadges();
    notificationsStore.startPolling();
    return () => notificationsStore.stopPolling();
  });

  // ── Combined badge ───────────────────────────────────────────────────────
  let totalBadge = $derived(
    inboxStore.unreadCount + approvalsStore.pendingCount + notificationsStore.unreadCount > 0
      ? inboxStore.unreadCount + approvalsStore.pendingCount + notificationsStore.unreadCount
      : undefined,
  );

  // ── Approval interaction state ───────────────────────────────────────────
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

  // ── Notification helpers ─────────────────────────────────────────────────
  function formatRelativeTime(iso: string): string {
    const diff = Date.now() - new Date(iso).getTime();
    if (diff < 60_000) return 'just now';
    if (diff < 3_600_000) return `${Math.floor(diff / 60_000)}m ago`;
    if (diff < 86_400_000) return `${Math.floor(diff / 3_600_000)}h ago`;
    return `${Math.floor(diff / 86_400_000)}d ago`;
  }

  const CATEGORY_LABELS: Record<NotificationCategory, string> = {
    task:     'Task',
    approval: 'Approval',
    alert:    'Alert',
    mention:  'Mention',
    system:   'System',
    budget:   'Budget',
    workflow: 'Workflow',
  };

  // ntf = active (not dismissed) notifications, sorted by recency
  let ntfVisible = $derived(
    notificationsStore.notifications
      .filter((n) => !n.dismissed_at)
      .sort((a, b) => {
        const unreadDiff = (a.read_at ? 1 : 0) - (b.read_at ? 1 : 0);
        if (unreadDiff !== 0) return unreadDiff;
        return new Date(b.inserted_at).getTime() - new Date(a.inserted_at).getTime();
      }),
  );

  // ── Tab definitions ──────────────────────────────────────────────────────
  const TABS: { id: InboxTab; label: string }[] = [
    { id: 'all',           label: 'All' },
    { id: 'messages',      label: 'Messages' },
    { id: 'approvals',     label: 'Approvals' },
    { id: 'notifications', label: 'Notifications' },
  ];
</script>

<PageShell title="Inbox" badge={totalBadge}>
  {#snippet actions()}
    <nav class="ib-tab-bar" aria-label="Inbox sections">
      {#each TABS as tab (tab.id)}
        <button
          class="ib-tab"
          class:ib-tab--active={activeTab === tab.id}
          onclick={() => setTab(tab.id)}
          type="button"
          aria-current={activeTab === tab.id ? 'page' : undefined}
        >
          {tab.label}
          {#if tab.id === 'messages' && inboxStore.unreadCount > 0}
            <span class="ib-tab-badge" aria-label="{inboxStore.unreadCount} unread">
              {inboxStore.unreadCount}
            </span>
          {:else if tab.id === 'approvals' && approvalsStore.pendingCount > 0}
            <span class="ib-tab-badge ib-tab-badge--approval" aria-label="{approvalsStore.pendingCount} pending">
              {approvalsStore.pendingCount}
            </span>
          {:else if tab.id === 'notifications' && notificationsStore.unreadCount > 0}
            <span
              class="ib-tab-badge"
              class:ib-tab-badge--critical={notificationsStore.criticalCount > 0}
              aria-label="{notificationsStore.unreadCount} unread notifications"
            >
              {notificationsStore.unreadCount}
            </span>
          {/if}
        </button>
      {/each}
    </nav>
  {/snippet}

  <div class="ib-content">
    <!-- ── Messages view ───────────────────────────────────────────────── -->
    {#if activeTab === 'messages'}
      <InboxFilters />
      <InboxFeed />

    <!-- ── Approvals view ─────────────────────────────────────────────── -->
    {:else if activeTab === 'approvals'}
      {#if approvalsStore.loading && approvalsStore.approvals.length === 0}
        <div class="ib-approval-state" role="status" aria-live="polite">
          <div class="ib-approval-spinner" aria-hidden="true"></div>
          <span>Loading approvals…</span>
        </div>
      {:else if approvalsStore.error && approvalsStore.approvals.length === 0}
        <div class="ib-approval-state ib-approval-state--error" role="alert">
          <p>Failed to load approvals: {approvalsStore.error}</p>
          <button
            class="ib-approval-retry"
            onclick={() => void approvalsStore.fetchApprovals()}
          >
            Retry
          </button>
        </div>
      {:else if approvalsStore.filteredApprovals.length === 0}
        <div class="ib-approval-state" role="status">
          <p class="ib-approval-empty">No approval requests.</p>
        </div>
      {:else}
        <ul class="ib-approval-list" aria-label="Approval requests">
          {#each approvalsStore.filteredApprovals as approval (approval.id)}
            {@const isPending = approval.status === 'pending'}
            {@const busy = actionPending[approval.id] ?? false}
            <li class="ib-approval-item">
              <div class="ib-approval-header">
                <div class="ib-approval-meta">
                  <span
                    class="ib-approval-badge"
                    class:ib-approval-badge--pending={approval.status === 'pending'}
                    class:ib-approval-badge--approved={approval.status === 'approved'}
                    class:ib-approval-badge--rejected={approval.status === 'rejected'}
                    class:ib-approval-badge--expired={approval.status === 'expired'}
                  >
                    {STATUS_LABELS[approval.status]}
                  </span>
                  {#if approval.entity_type}
                    <span class="ib-approval-entity">{approval.entity_type}</span>
                  {/if}
                </div>
                <time class="ib-approval-date" datetime={approval.created_at}>
                  {formatDate(approval.created_at)}
                </time>
              </div>

              <h3 class="ib-approval-title">{approval.title}</h3>
              {#if approval.description}
                <p class="ib-approval-desc">{approval.description}</p>
              {/if}

              <div class="ib-approval-requester">
                Requested by <span class="ib-approval-requester-name">{approval.requester_name}</span>
                {#if approval.expires_at}
                  <span class="ib-approval-expires">· expires {formatDate(approval.expires_at)}</span>
                {/if}
              </div>

              {#if approval.comment && !isPending}
                <p class="ib-approval-reviewer-comment">"{approval.comment}"</p>
              {/if}

              {#if isPending}
                <div class="ib-approval-actions">
                  <input
                    class="ib-approval-comment"
                    type="text"
                    placeholder="Optional comment…"
                    value={getComment(approval.id)}
                    oninput={(e) => setComment(approval.id, (e.target as HTMLInputElement).value)}
                    aria-label="Comment for approval decision"
                    disabled={busy}
                  />
                  <div class="ib-approval-btns">
                    <button
                      class="ib-approval-btn ib-approval-btn--approve"
                      onclick={() => handleApprove(approval.id)}
                      disabled={busy}
                      aria-label="Approve {approval.title}"
                      type="button"
                    >
                      {busy ? 'Working…' : 'Approve'}
                    </button>
                    <button
                      class="ib-approval-btn ib-approval-btn--reject"
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

    <!-- ── Notifications view ─────────────────────────────────────────── -->
    {:else if activeTab === 'notifications'}
      {#if notificationsStore.loading && notificationsStore.notifications.length === 0}
        <div class="ib-approval-state" role="status" aria-live="polite">
          <div class="ib-approval-spinner" aria-hidden="true"></div>
          <span>Loading notifications…</span>
        </div>
      {:else if notificationsStore.error && notificationsStore.notifications.length === 0}
        <div class="ib-approval-state ib-approval-state--error" role="alert">
          <p>Failed to load notifications: {notificationsStore.error}</p>
          <button
            class="ib-approval-retry"
            onclick={() => void notificationsStore.fetchNotifications()}
          >
            Retry
          </button>
        </div>
      {:else if ntfVisible.length === 0}
        <div class="ib-approval-state" role="status">
          <p class="ib-approval-empty">No notifications.</p>
        </div>
      {:else}
        <div class="ntf-toolbar">
          <span class="ntf-toolbar-count">
            {ntfVisible.filter((n) => !n.read_at).length} unread
          </span>
          {#if ntfVisible.some((n) => !n.read_at)}
            <button
              class="ntf-toolbar-btn"
              type="button"
              onclick={() => void notificationsStore.markAllRead()}
            >
              Mark all read
            </button>
          {/if}
        </div>

        <ul class="ntf-list" aria-label="Notifications">
          {#each ntfVisible as ntf (ntf.id)}
            <li
              class="ntf-item"
              class:ntf-item--unread={!ntf.read_at}
              class:ntf-item--critical={ntf.severity === 'critical'}
            >
              <!-- Severity dot + category badge row -->
              <div class="ntf-meta-row">
                <span
                  class="ntf-severity-dot"
                  class:ntf-severity-dot--info={ntf.severity === 'info'}
                  class:ntf-severity-dot--warning={ntf.severity === 'warning'}
                  class:ntf-severity-dot--error={ntf.severity === 'error'}
                  class:ntf-severity-dot--critical={ntf.severity === 'critical'}
                  aria-label="Severity: {ntf.severity}"
                  title={ntf.severity}
                ></span>
                <span class="ntf-category-badge ntf-category-badge--{ntf.category}">
                  {CATEGORY_LABELS[ntf.category]}
                </span>
                <time class="ntf-time" datetime={ntf.inserted_at} title={ntf.inserted_at}>
                  {formatRelativeTime(ntf.inserted_at)}
                </time>
              </div>

              <!-- Title + body -->
              <h3 class="ntf-title">{ntf.title}</h3>
              {#if ntf.body}
                <p class="ntf-body">{ntf.body}</p>
              {/if}

              <!-- Action row -->
              <div class="ntf-actions">
                {#if ntf.action_url && ntf.action_label}
                  <a
                    class="ntf-action-link"
                    href={ntf.action_url}
                    aria-label="{ntf.action_label} — {ntf.title}"
                  >
                    {ntf.action_label}
                  </a>
                {/if}
                {#if !ntf.read_at}
                  <button
                    class="ntf-btn ntf-btn--read"
                    type="button"
                    onclick={() => void notificationsStore.markRead(ntf.id)}
                    aria-label="Mark as read: {ntf.title}"
                  >
                    Mark read
                  </button>
                {/if}
                <button
                  class="ntf-btn ntf-btn--dismiss"
                  type="button"
                  onclick={() => void notificationsStore.dismiss(ntf.id)}
                  aria-label="Dismiss: {ntf.title}"
                >
                  Dismiss
                </button>
              </div>
            </li>
          {/each}
        </ul>
      {/if}

    <!-- ── All view — messages + approvals interleaved ────────────────── -->
    {:else}
      <!-- Approvals summary row (only when pending items exist) -->
      {#if approvalsStore.pendingCount > 0}
        <div class="ib-all-approvals-banner">
          <span class="ib-all-approvals-label">
            <span class="ib-all-approvals-dot" aria-hidden="true"></span>
            {approvalsStore.pendingCount} pending approval{approvalsStore.pendingCount === 1 ? '' : 's'}
          </span>
          <button
            class="ib-all-approvals-link"
            type="button"
            onclick={() => setTab('approvals')}
          >
            Review
          </button>
        </div>
      {/if}
      <InboxFilters />
      <InboxFeed />
    {/if}
  </div>
</PageShell>

<style>
  /* ── Tab bar ─────────────────────────────────────────────────────────────── */
  .ib-tab-bar {
    display: flex;
    gap: 2px;
  }

  .ib-tab {
    display: flex;
    align-items: center;
    gap: 5px;
    height: 26px;
    padding: 0 10px;
    border-radius: 5px;
    font-size: 12px;
    font-weight: 500;
    background: transparent;
    border: 1px solid transparent;
    color: var(--text-secondary);
    cursor: pointer;
    transition: background 100ms ease, color 100ms ease, border-color 100ms ease;
  }

  .ib-tab:hover {
    background: var(--bg-elevated);
    color: var(--text-primary);
    border-color: var(--border-default);
  }

  .ib-tab--active {
    background: var(--bg-elevated);
    border-color: var(--border-hover);
    color: var(--text-primary);
  }

  .ib-tab-badge {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 16px;
    height: 16px;
    padding: 0 4px;
    border-radius: 8px;
    font-size: 10px;
    font-weight: 600;
    background: var(--bg-tertiary);
    color: var(--text-secondary);
  }

  .ib-tab-badge--approval {
    background: rgba(245, 158, 11, 0.15);
    color: #fbbf24;
  }

  /* ── Page content container ─────────────────────────────────────────────── */
  .ib-content {
    height: 100%;
    display: flex;
    flex-direction: column;
    min-height: 0;
  }

  /* ── All-tab approvals banner ───────────────────────────────────────────── */
  .ib-all-approvals-banner {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 8px 12px;
    margin-bottom: 8px;
    border-radius: 6px;
    background: rgba(245, 158, 11, 0.07);
    border: 1px solid rgba(245, 158, 11, 0.2);
    flex-shrink: 0;
  }

  .ib-all-approvals-label {
    display: flex;
    align-items: center;
    gap: 7px;
    font-size: 12px;
    color: #fbbf24;
    font-weight: 500;
  }

  .ib-all-approvals-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #fbbf24;
    flex-shrink: 0;
  }

  .ib-all-approvals-link {
    font-size: 11px;
    font-weight: 500;
    color: #fbbf24;
    background: transparent;
    border: 1px solid rgba(245, 158, 11, 0.3);
    border-radius: 4px;
    padding: 2px 8px;
    cursor: pointer;
    transition: background 100ms ease;
  }

  .ib-all-approvals-link:hover {
    background: rgba(245, 158, 11, 0.12);
  }

  /* ── Approval states ────────────────────────────────────────────────────── */
  .ib-approval-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    min-height: 220px;
    font-size: 13px;
    color: var(--text-secondary);
  }

  .ib-approval-state--error { color: var(--accent-error, #f87171); }

  .ib-approval-spinner {
    width: 22px;
    height: 22px;
    border-radius: 50%;
    border: 2px solid var(--border-default);
    border-top-color: var(--text-secondary);
    animation: ib-spin 0.75s linear infinite;
  }

  @keyframes ib-spin { to { transform: rotate(360deg); } }

  .ib-approval-empty { margin: 0; }

  .ib-approval-retry {
    padding: 6px 14px;
    border-radius: 6px;
    font-size: 12px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    color: var(--text-secondary);
    cursor: pointer;
  }

  .ib-approval-retry:hover {
    border-color: var(--border-hover);
    color: var(--text-primary);
  }

  /* ── Approval list ──────────────────────────────────────────────────────── */
  .ib-approval-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 10px;
    overflow-y: auto;
    min-height: 0;
  }

  /* ── Approval item card ─────────────────────────────────────────────────── */
  .ib-approval-item {
    padding: 16px;
    border-radius: 8px;
    background: var(--bg-surface);
    border: 1px solid var(--border-default);
    display: flex;
    flex-direction: column;
    gap: 8px;
    transition: border-color 120ms ease;
  }

  .ib-approval-item:hover { border-color: var(--border-hover); }

  .ib-approval-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
  }

  .ib-approval-meta {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  /* ── Status badge ───────────────────────────────────────────────────────── */
  .ib-approval-badge {
    font-size: 11px;
    font-weight: 500;
    padding: 2px 8px;
    border-radius: 10px;
    background: var(--bg-elevated);
    color: var(--text-secondary);
    border: 1px solid var(--border-default);
  }

  .ib-approval-badge--pending {
    background: rgba(245, 158, 11, 0.1);
    color: #fbbf24;
    border-color: rgba(245, 158, 11, 0.25);
  }

  .ib-approval-badge--approved {
    background: rgba(34, 197, 94, 0.1);
    color: #4ade80;
    border-color: rgba(34, 197, 94, 0.25);
  }

  .ib-approval-badge--rejected {
    background: rgba(239, 68, 68, 0.1);
    color: #f87171;
    border-color: rgba(239, 68, 68, 0.25);
  }

  .ib-approval-badge--expired {
    background: var(--bg-elevated);
    color: var(--text-tertiary);
    border-color: var(--border-default);
  }

  .ib-approval-entity {
    font-size: 10px;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    padding: 2px 6px;
    border-radius: 4px;
    background: var(--bg-elevated);
    color: var(--text-tertiary);
  }

  .ib-approval-date {
    font-size: 11px;
    color: var(--text-tertiary);
    flex-shrink: 0;
  }

  /* ── Item content ───────────────────────────────────────────────────────── */
  .ib-approval-title {
    margin: 0;
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
    line-height: 1.3;
  }

  .ib-approval-desc {
    margin: 0;
    font-size: 13px;
    color: var(--text-secondary);
    line-height: 1.5;
  }

  .ib-approval-requester {
    font-size: 12px;
    color: var(--text-tertiary);
  }

  .ib-approval-requester-name {
    color: var(--text-secondary);
    font-weight: 500;
  }

  .ib-approval-expires { color: var(--accent-warning, #fbbf24); }

  .ib-approval-reviewer-comment {
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
  .ib-approval-actions {
    display: flex;
    align-items: center;
    gap: 8px;
    padding-top: 4px;
    flex-wrap: wrap;
  }

  .ib-approval-comment {
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

  .ib-approval-comment::placeholder { color: var(--text-muted); }

  .ib-approval-comment:focus {
    outline: none;
    border-color: var(--border-focus);
  }

  .ib-approval-comment:disabled { opacity: 0.5; cursor: not-allowed; }

  .ib-approval-btns {
    display: flex;
    gap: 6px;
    flex-shrink: 0;
  }

  .ib-approval-btn {
    height: 30px;
    padding: 0 14px;
    border-radius: 6px;
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    transition: background 100ms ease, opacity 100ms ease;
  }

  .ib-approval-btn:disabled { opacity: 0.5; cursor: not-allowed; }

  .ib-approval-btn--approve {
    background: rgba(34, 197, 94, 0.15);
    color: #4ade80;
    border: 1px solid rgba(34, 197, 94, 0.3);
  }

  .ib-approval-btn--approve:hover:not(:disabled) {
    background: rgba(34, 197, 94, 0.25);
  }

  .ib-approval-btn--reject {
    background: rgba(239, 68, 68, 0.12);
    color: #f87171;
    border: 1px solid rgba(239, 68, 68, 0.25);
  }

  .ib-approval-btn--reject:hover:not(:disabled) {
    background: rgba(239, 68, 68, 0.22);
  }

  /* ── Notification tab badge variant ─────────────────────────────────────── */
  .ib-tab-badge--critical {
    background: rgba(168, 85, 247, 0.15);
    color: #c084fc;
  }

  /* ── Notification toolbar ────────────────────────────────────────────────── */
  .ntf-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 4px 0 10px;
    flex-shrink: 0;
  }

  .ntf-toolbar-count {
    font-size: 12px;
    color: var(--text-tertiary);
  }

  .ntf-toolbar-btn {
    font-size: 11px;
    font-weight: 500;
    color: var(--text-secondary);
    background: transparent;
    border: 1px solid var(--border-default);
    border-radius: 4px;
    padding: 2px 8px;
    cursor: pointer;
    transition: background 100ms ease, color 100ms ease;
  }

  .ntf-toolbar-btn:hover {
    background: var(--bg-elevated);
    color: var(--text-primary);
  }

  /* ── Notification list ───────────────────────────────────────────────────── */
  .ntf-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 8px;
    overflow-y: auto;
    min-height: 0;
  }

  /* ── Notification item ───────────────────────────────────────────────────── */
  .ntf-item {
    padding: 14px 16px;
    border-radius: 8px;
    background: var(--bg-surface);
    border: 1px solid var(--border-default);
    display: flex;
    flex-direction: column;
    gap: 6px;
    transition: border-color 120ms ease;
  }

  .ntf-item:hover { border-color: var(--border-hover); }

  .ntf-item--unread {
    border-left: 3px solid var(--border-focus, rgba(99, 102, 241, 0.5));
    padding-left: 13px;
  }

  .ntf-item--critical.ntf-item--unread {
    border-left-color: rgba(168, 85, 247, 0.6);
  }

  /* ── Meta row: dot + category + time ───────────────────────────────────── */
  .ntf-meta-row {
    display: flex;
    align-items: center;
    gap: 7px;
  }

  .ntf-severity-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    flex-shrink: 0;
    background: var(--text-muted);
  }

  .ntf-severity-dot--info    { background: #60a5fa; }
  .ntf-severity-dot--warning { background: #fbbf24; }
  .ntf-severity-dot--error   { background: #f87171; }
  .ntf-severity-dot--critical{ background: #c084fc; }

  .ntf-category-badge {
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    padding: 1px 6px;
    border-radius: 4px;
    background: var(--bg-elevated);
    color: var(--text-tertiary);
    border: 1px solid var(--border-default);
  }

  .ntf-category-badge--alert    { background: rgba(239, 68, 68, 0.08);   color: #f87171;  border-color: rgba(239, 68, 68, 0.2); }
  .ntf-category-badge--budget   { background: rgba(245, 158, 11, 0.08);  color: #fbbf24;  border-color: rgba(245, 158, 11, 0.2); }
  .ntf-category-badge--approval { background: rgba(245, 158, 11, 0.08);  color: #fbbf24;  border-color: rgba(245, 158, 11, 0.2); }
  .ntf-category-badge--workflow { background: rgba(99, 102, 241, 0.08);  color: #818cf8;  border-color: rgba(99, 102, 241, 0.2); }
  .ntf-category-badge--task     { background: rgba(34, 197, 94, 0.08);   color: #4ade80;  border-color: rgba(34, 197, 94, 0.2); }
  .ntf-category-badge--mention  { background: rgba(56, 189, 248, 0.08);  color: #38bdf8;  border-color: rgba(56, 189, 248, 0.2); }
  .ntf-category-badge--system   { background: var(--bg-elevated);        color: var(--text-tertiary); }

  .ntf-time {
    font-size: 11px;
    color: var(--text-tertiary);
    margin-left: auto;
    flex-shrink: 0;
  }

  /* ── Notification content ────────────────────────────────────────────────── */
  .ntf-title {
    margin: 0;
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary);
    line-height: 1.35;
  }

  .ntf-body {
    margin: 0;
    font-size: 12px;
    color: var(--text-secondary);
    line-height: 1.5;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  /* ── Notification actions ────────────────────────────────────────────────── */
  .ntf-actions {
    display: flex;
    align-items: center;
    gap: 6px;
    padding-top: 2px;
    flex-wrap: wrap;
  }

  .ntf-action-link {
    font-size: 11px;
    font-weight: 500;
    color: var(--accent-primary, #6366f1);
    text-decoration: none;
    border: 1px solid rgba(99, 102, 241, 0.3);
    border-radius: 4px;
    padding: 2px 8px;
    transition: background 100ms ease;
  }

  .ntf-action-link:hover {
    background: rgba(99, 102, 241, 0.08);
  }

  .ntf-btn {
    font-size: 11px;
    font-weight: 500;
    padding: 2px 8px;
    border-radius: 4px;
    cursor: pointer;
    transition: background 100ms ease, color 100ms ease;
  }

  .ntf-btn--read {
    background: transparent;
    color: var(--text-tertiary);
    border: 1px solid var(--border-default);
  }

  .ntf-btn--read:hover {
    background: var(--bg-elevated);
    color: var(--text-secondary);
  }

  .ntf-btn--dismiss {
    background: transparent;
    color: var(--text-muted);
    border: 1px solid transparent;
  }

  .ntf-btn--dismiss:hover {
    background: var(--bg-elevated);
    color: var(--text-tertiary);
    border-color: var(--border-default);
  }
</style>
