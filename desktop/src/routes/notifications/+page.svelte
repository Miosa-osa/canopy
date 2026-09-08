<script lang="ts">
/**
 * /notifications — Full notification list page.
 * CSS prefix: nf- (NotificationsFull)
 * LOC target: ≤ 300.
 *
 * Keyboard: j/k navigate · ↵ open/expand · d mark read · ⇧D delete · r refresh
 */
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { Bell } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import {
  deleteNotificationMutation,
  markAllReadMutation,
  markReadMutation,
  notificationsQuery,
  unreadCountQuery,
} from '$lib/api/queries/notifications.js';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import SkeletonList from '$lib/design/patterns/SkeletonList.svelte';
import type { Notification } from '$lib/domain/notifications/types.js';
import { toasts } from '$lib/stores/toasts.svelte.js';
import { useListKeyboard } from '$lib/utils/useListKeyboard.svelte.js';

const queryClient = useQueryClient();

// ── TanStack Query setup ──────────────────────────────────────────────────────

const listOptsStore = writable(
  untrack(() => notificationsQuery() as CreateQueryOptions<Notification[]>)
);
const listQ = createQuery<Notification[]>(listOptsStore);

const unreadCountOptsStore = writable(
  untrack(() => unreadCountQuery() as CreateQueryOptions<{ count: number }>)
);
const unreadCountQ = createQuery<{ count: number }>(unreadCountOptsStore);

const markReadMut = createMutation(
  writable(untrack(() => markReadMutation() as CreateMutationOptions<Notification, Error, string>))
);

const markAllReadMut = createMutation(
  writable(
    untrack(() => markAllReadMutation() as CreateMutationOptions<{ count: number }, Error, void>)
  )
);

const deleteNotifMut = createMutation(
  writable(
    untrack(() => deleteNotificationMutation() as CreateMutationOptions<void, Error, string>)
  )
);

// ── Filter state ──────────────────────────────────────────────────────────────

type StatusFilter = 'all' | 'unread' | 'read';
type DateFilter = 'today' | 'week' | 'month' | 'all';

let statusFilter = $state<StatusFilter>('all');
let typeFilter = $state<string>('all');
let dateFilter = $state<DateFilter>('all');

// ── Derived data ──────────────────────────────────────────────────────────────

const allNotifs = $derived(($listQ.data ?? []) as Notification[]);
const unreadCount = $derived(($unreadCountQ.data?.count ?? 0) as number);

// Derive distinct types from results for the type dropdown
const distinctTypes = $derived<string[]>([
  'all',
  ...Array.from(new Set(allNotifs.map((n) => n.type))).sort(),
]);

function matchesDate(n: Notification): boolean {
  if (dateFilter === 'all') return true;
  const now = Date.now();
  const ts = new Date(n.insertedAt).getTime();
  const diff = now - ts;
  if (dateFilter === 'today') return diff < 86_400_000;
  if (dateFilter === 'week') return diff < 7 * 86_400_000;
  if (dateFilter === 'month') return diff < 30 * 86_400_000;
  return true;
}

const filtered = $derived(
  allNotifs.filter((n) => {
    if (statusFilter === 'unread' && n.readAt !== null) return false;
    if (statusFilter === 'read' && n.readAt === null) return false;
    if (typeFilter !== 'all' && n.type !== typeFilter) return false;
    return matchesDate(n);
  })
);

// ── Expanded row state ────────────────────────────────────────────────────────

let expandedId = $state<string | null>(null);

// ── Relative time ─────────────────────────────────────────────────────────────

function relativeTime(iso: string): string {
  const diff = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (diff < 60) return 'just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

// ── Interaction handlers ──────────────────────────────────────────────────────

async function handleRowClick(n: Notification): Promise<void> {
  if (n.linkPath) {
    if (!n.readAt) await markRead(n.id);
    void goto(n.linkPath);
    return;
  }
  expandedId = expandedId === n.id ? null : n.id;
  if (!n.readAt) await markRead(n.id);
}

async function markRead(id: string): Promise<void> {
  await $markReadMut.mutateAsync(id);
  queryClient.invalidateQueries({ queryKey: ['notifications'] });
}

async function toggleRead(n: Notification): Promise<void> {
  if (!n.readAt) {
    await markRead(n.id);
  }
  // No unread mutation exposed in queries — mark read only direction
}

async function handleDelete(id: string): Promise<void> {
  await $deleteNotifMut.mutateAsync(id);
  queryClient.invalidateQueries({ queryKey: ['notifications'] });
  toasts.success('Notification deleted');
  if (expandedId === id) expandedId = null;
}

async function handleMarkAllRead(): Promise<void> {
  await $markAllReadMut.mutateAsync();
  queryClient.invalidateQueries({ queryKey: ['notifications'] });
  toasts.success('All notifications marked as read');
}

// ── Keyboard navigation ───────────────────────────────────────────────────────

const kb = useListKeyboard<Notification>({
  items: () => filtered,
  onSelect: (item) => void handleRowClick(item),
  onRefresh: () => {
    queryClient.invalidateQueries({ queryKey: ['notifications'] });
  },
});

function handlePageKeydown(e: KeyboardEvent): void {
  // d — mark focused item read
  if (e.key === 'd' && !e.shiftKey && kb.selectedIndex >= 0) {
    e.preventDefault();
    const item = filtered[kb.selectedIndex];
    if (item) void toggleRead(item);
    return;
  }
  // ⇧D — delete focused item
  if (e.key === 'D' && e.shiftKey && kb.selectedIndex >= 0) {
    e.preventDefault();
    const item = filtered[kb.selectedIndex];
    if (item) void handleDelete(item.id);
    return;
  }
  kb.handleKeydown(e);
}
</script>

<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="nf-page"
  role="main"
  tabindex="-1"
  onkeydown={handlePageKeydown}
  aria-label="Notifications"
>
  <!-- Header -->
  <header class="nf-header">
    <div class="nf-header__left">
      <h1 class="nf-title">Notifications</h1>
      {#if unreadCount > 0}
        <span class="nf-unread-chip" aria-label="{unreadCount} unread">
          {unreadCount}
        </span>
      {/if}
    </div>
    {#if unreadCount > 0}
      <button
        class="btn-compact btn-compact-ghost nf-mark-all-btn"
        onclick={handleMarkAllRead}
        aria-label="Mark all notifications as read"
        aria-busy={$markAllReadMut.isPending}
        disabled={$markAllReadMut.isPending}
      >
        Mark all read
      </button>
    {/if}
  </header>

  <!-- Filter row -->
  <div class="nf-filters" role="search" aria-label="Filter notifications">
    <!-- Status pills -->
    <div class="nf-chips" role="group" aria-label="Status filter">
      {#each (['all', 'unread', 'read'] as StatusFilter[]) as s (s)}
        <button
          class="nf-chip"
          class:nf-chip--active={statusFilter === s}
          onclick={() => (statusFilter = s)}
          aria-pressed={statusFilter === s}
        >
          {s === 'all' ? 'All' : s === 'unread' ? 'Unread' : 'Read'}
        </button>
      {/each}
    </div>

    <!-- Type dropdown -->
    <select
      class="nf-type-select"
      bind:value={typeFilter}
      aria-label="Filter by type"
    >
      {#each distinctTypes as t (t)}
        <option value={t}>{t === 'all' ? 'All types' : t}</option>
      {/each}
    </select>

    <!-- Date chips -->
    <div class="nf-chips" role="group" aria-label="Date filter">
      {#each (['today', 'week', 'month', 'all'] as DateFilter[]) as d (d)}
        <button
          class="nf-chip nf-chip--date"
          class:nf-chip--active={dateFilter === d}
          onclick={() => (dateFilter = d)}
          aria-pressed={dateFilter === d}
        >
          {d === 'today' ? 'Today' : d === 'week' ? 'This week' : d === 'month' ? 'This month' : 'All'}
        </button>
      {/each}
    </div>
  </div>

  <!-- Body -->
  {#if $listQ.isError}
    <EmptyState
      title="Couldn't load notifications"
      body={($listQ.error as Error).message || 'Check your connection and try again.'}
      action="Retry"
      onAction={() => $listQ.refetch()}
    />
  {:else if $listQ.isLoading}
    <div class="nf-skeleton-wrap">
      <SkeletonList count={8} height="3rem" gap="0.25rem" />
    </div>
  {:else if filtered.length === 0}
    <EmptyState
      icon={Bell as never}
      title={statusFilter === 'unread' ? 'All caught up' : 'No notifications'}
      body={statusFilter === 'unread'
        ? 'No unread notifications.'
        : 'Notifications will appear here as activity happens.'}
    />
  {:else}
    <div class="nf-list" role="list" aria-label="Notification list">
      {#each filtered as notif, i (notif.id)}
        <div
          class="nf-row"
          class:nf-row--unread={!notif.readAt}
          class:nf-row--focused={kb.selectedIndex === i}
          class:nf-row--expanded={expandedId === notif.id}
          role="listitem"
        >
          <!-- Main row button -->
          <button
            class="nf-row__btn"
            onclick={() => void handleRowClick(notif)}
            onmouseenter={() => { /* hover does not move kb focus */ }}
            aria-label="{notif.title}{!notif.readAt ? ' (unread)' : ''}"
            aria-expanded={expandedId === notif.id}
          >
            <!-- Left: icon -->
            <span class="nf-row__icon" aria-hidden="true">
              {#if notif.icon}
                {notif.icon}
              {:else}
                <Bell size={13} />
              {/if}
            </span>

            <!-- Middle: type badge + title + body -->
            <div class="nf-row__content">
              <div class="nf-row__top">
                <span class="nf-row__type">{notif.type}</span>
                <span class="nf-row__title">{notif.title}</span>
              </div>
              <p class="nf-row__body">{notif.body}</p>
            </div>

            <!-- Right: time + unread dot -->
            <div class="nf-row__meta">
              <time class="nf-row__time" datetime={notif.insertedAt} title={notif.insertedAt}>
                {relativeTime(notif.insertedAt)}
              </time>
              {#if !notif.readAt}
                <span class="nf-row__dot" aria-hidden="true"></span>
              {/if}
            </div>
          </button>

          <!-- Row action menu -->
          <div class="nf-row__actions" aria-label="Row actions">
            <button
              class="nf-action-btn"
              onclick={() => void toggleRead(notif)}
              aria-label="{notif.readAt ? 'Mark as unread' : 'Mark as read'}"
              title="{notif.readAt ? 'Mark unread' : 'Mark read'}"
              disabled={$markReadMut.isPending}
            >
              {notif.readAt ? '○' : '●'}
            </button>
            <button
              class="nf-action-btn nf-action-btn--delete"
              onclick={() => void handleDelete(notif.id)}
              aria-label="Delete notification"
              title="Delete"
              disabled={$deleteNotifMut.isPending}
            >
              ×
            </button>
          </div>

          <!-- Expanded inline body -->
          {#if expandedId === notif.id}
            <div class="nf-expand" role="region" aria-label="Notification details">
              <p class="nf-expand__body">{notif.body}</p>
              {#if Object.keys(notif.payload).length > 0}
                <pre class="nf-expand__payload">{JSON.stringify(notif.payload, null, 2)}</pre>
              {/if}
            </div>
          {/if}
        </div>
      {/each}
    </div>
  {/if}

  <!-- Keyboard hint strip -->
  <footer class="nf-shortcuts" aria-label="Keyboard shortcuts">
    <span class="nf-kbd">j/k</span> navigate
    <span class="nf-kbd">↵</span> open
    <span class="nf-kbd">d</span> mark read
    <span class="nf-kbd">⇧D</span> delete
    <span class="nf-kbd">r</span> refresh
  </footer>
</div>

<style>
  .nf-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-6);
    overflow-y: auto;
    height: 100%;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
    outline: none;
  }

  /* Header */
  .nf-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
  }

  .nf-header__left {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .nf-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    letter-spacing: var(--tracking-2xl);
    line-height: var(--lh-2xl);
  }

  .nf-unread-chip {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 20px;
    height: 20px;
    padding: 0 5px;
    border-radius: 9999px;
    background: var(--cnp-accent);
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 700;
    color: var(--bg);
    line-height: 1;
  }

  .nf-mark-all-btn {
    font-size: 11px;
    color: var(--fg-muted);
  }

  /* Filter row */
  .nf-filters {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    flex-wrap: wrap;
  }

  .nf-chips {
    display: flex;
    gap: var(--space-1);
  }

  .nf-chip {
    padding: 3px 10px;
    border-radius: 9999px;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    background: transparent;
    border: 1px solid var(--border);
    cursor: pointer;
    transition: background 0.1s ease, color 0.1s ease, border-color 0.1s ease;
    white-space: nowrap;
  }

  .nf-chip:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg);
  }

  .nf-chip--active {
    background: color-mix(in oklch, var(--cnp-accent) 15%, transparent);
    color: var(--fg);
    border-color: var(--cnp-accent);
  }

  .nf-chip:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .nf-type-select {
    padding: 3px 8px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: var(--bg-inset);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    outline: none;
    cursor: pointer;
    transition: border-color 0.1s ease;
    max-width: 140px;
  }

  .nf-type-select:focus {
    border-color: color-mix(in oklch, var(--fg) 40%, transparent);
    color: var(--fg);
  }

  /* Skeleton */
  .nf-skeleton-wrap {
    flex: 1;
    padding-top: var(--space-2);
  }

  /* List */
  .nf-list {
    display: flex;
    flex-direction: column;
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    overflow: hidden;
  }

  /* Row */
  .nf-row {
    border-bottom: 1px solid var(--border);
    transition: background 0.1s ease;
    position: relative;
  }

  .nf-row:last-child {
    border-bottom: none;
  }

  .nf-row--focused {
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }

  .nf-row__btn {
    display: flex;
    align-items: flex-start;
    gap: var(--space-3);
    width: 100%;
    padding: var(--space-3) var(--space-3);
    background: transparent;
    border: none;
    cursor: pointer;
    text-align: left;
    /* leave right space for action buttons */
    padding-right: 4.5rem;
    transition: background 0.1s ease;
  }

  .nf-row__btn:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }

  .nf-row__btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: -2px;
  }

  .nf-row__icon {
    flex-shrink: 0;
    width: 20px;
    height: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 14px;
    margin-top: 1px;
    color: var(--fg-subtle);
  }

  .nf-row__content {
    flex: 1;
    min-width: 0;
  }

  .nf-row__top {
    display: flex;
    align-items: baseline;
    gap: var(--space-2);
  }

  .nf-row__type {
    font-family: var(--font-mono);
    font-size: 10px;
    font-weight: 500;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    flex-shrink: 0;
    white-space: nowrap;
  }

  .nf-row__title {
    font-family: var(--font-sans);
    font-size: 13px;
    font-weight: 500;
    color: var(--fg);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex: 1;
  }

  .nf-row--unread .nf-row__title {
    font-weight: 600;
  }

  .nf-row__body {
    margin: 2px 0 0;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .nf-row__meta {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 4px;
    flex-shrink: 0;
  }

  .nf-row__time {
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--fg-subtle);
    white-space: nowrap;
  }

  .nf-row__dot {
    width: 6px;
    height: 6px;
    border-radius: 9999px;
    background: var(--cnp-accent);
    flex-shrink: 0;
  }

  /* Row action buttons (revealed on hover/focus-within) */
  .nf-row__actions {
    position: absolute;
    right: var(--space-2);
    top: 50%;
    transform: translateY(-50%);
    display: flex;
    gap: 2px;
    opacity: 0;
    transition: opacity 0.1s ease;
  }

  .nf-row:hover .nf-row__actions,
  .nf-row--focused .nf-row__actions,
  .nf-row:focus-within .nf-row__actions {
    opacity: 1;
  }

  .nf-action-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 22px;
    height: 22px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: var(--bg);
    font-family: var(--font-mono);
    font-size: 12px;
    color: var(--fg-muted);
    cursor: pointer;
    transition: background 0.1s ease, color 0.1s ease;
    line-height: 1;
    padding: 0;
  }

  .nf-action-btn:hover {
    background: color-mix(in oklch, var(--fg) 10%, transparent);
    color: var(--fg);
  }

  .nf-action-btn--delete:hover {
    background: color-mix(in oklch, var(--signal-error, #e54d4d) 15%, transparent);
    color: var(--signal-error, #e54d4d);
    border-color: color-mix(in oklch, var(--signal-error, #e54d4d) 40%, transparent);
  }

  .nf-action-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  .nf-action-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  /* Expanded section */
  .nf-expand {
    padding: var(--space-3) var(--space-3) var(--space-3) calc(var(--space-3) + 20px + var(--space-3));
    border-top: 1px solid var(--border);
    background: color-mix(in oklch, var(--fg) 2%, transparent);
  }

  .nf-expand__body {
    margin: 0;
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--fg);
    line-height: 1.6;
  }

  .nf-expand__payload {
    margin: var(--space-3) 0 0;
    padding: var(--space-2) var(--space-3);
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: var(--bg-inset);
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-muted);
    overflow-x: auto;
    white-space: pre;
    line-height: 1.5;
  }

  /* Keyboard shortcut footer */
  .nf-shortcuts {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    padding-top: var(--space-2);
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
    flex-wrap: wrap;
    margin-top: auto;
  }

  .nf-kbd {
    display: inline-flex;
    align-items: center;
    padding: 1px 5px;
    border-radius: 3px;
    border: 1px solid var(--border);
    background: var(--bg-inset);
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-muted);
    line-height: 1.4;
  }
</style>
