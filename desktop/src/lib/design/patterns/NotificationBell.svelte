<script lang="ts">
/**
 * NotificationBell — sidebar footer trigger + dropdown for in-app notifications.
 *
 * - Polls unread count every 60s via TanStack Query refetchInterval.
 * - Badge (red dot + number) hides when count is 0.
 * - Dropdown: header + scrollable list (max 10) + empty state.
 * - Click item: markRead + navigate if linkPath present.
 * - Keyboard: Escape closes; j/k navigate items.
 * - Click outside closes (document listener, cleaned up on destroy).
 * - CSS prefix: nb-
 * LOC target: ≤ 220.
 */

import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
} from '@tanstack/svelte-query';
import { Bell } from 'lucide-svelte';
import { onDestroy, untrack } from 'svelte';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import {
  markAllReadMutation,
  markReadMutation,
  notificationsQuery,
  unreadCountQuery,
} from '$lib/api/queries/notifications.js';
import type { Notification } from '$lib/domain/notifications/types.js';

// ── TanStack Query setup (writable+untrack bridge — same pattern as WorkspaceSwitcher) ──

const unreadCountOpts = writable(
  untrack(() => unreadCountQuery() as CreateQueryOptions<{ count: number }>)
);
const unreadCountQ = createQuery<{ count: number }>(unreadCountOpts);

const notifListOpts = writable(
  untrack(() => notificationsQuery({ limit: 10 }) as CreateQueryOptions<Notification[]>)
);
const notifListQ = createQuery<Notification[]>(notifListOpts);

const markReadMut = createMutation(
  writable(untrack(() => markReadMutation() as CreateMutationOptions<Notification, Error, string>))
);

const markAllReadMut = createMutation(
  writable(
    untrack(() => markAllReadMutation() as CreateMutationOptions<{ count: number }, Error, void>)
  )
);

// ── Derived state ─────────────────────────────────────────────────────────────

const unreadCount = $derived(($unreadCountQ.data?.count ?? 0) as number);
const notifications = $derived(($notifListQ.data ?? []) as Notification[]);

// ── Local state ───────────────────────────────────────────────────────────────

let isOpen = $state(false);
let activeIndex = $state(0);
let triggerEl = $state<HTMLButtonElement | null>(null);
let dropdownEl = $state<HTMLDivElement | null>(null);

// ── Relative time helper ──────────────────────────────────────────────────────

function relativeTime(iso: string): string {
  const diff = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (diff < 60) return 'just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

// ── Click-outside handler ─────────────────────────────────────────────────────

function handleDocClick(e: MouseEvent): void {
  if (!isOpen) return;
  const target = e.target as Node;
  if (triggerEl && !triggerEl.contains(target) && dropdownEl && !dropdownEl.contains(target)) {
    isOpen = false;
  }
}

if (typeof document !== 'undefined') {
  document.addEventListener('click', handleDocClick, true);
}

onDestroy(() => {
  if (typeof document !== 'undefined') {
    document.removeEventListener('click', handleDocClick, true);
  }
});

// ── Interaction handlers ──────────────────────────────────────────────────────

function toggle(): void {
  isOpen = !isOpen;
  if (isOpen) activeIndex = 0;
}

function close(): void {
  isOpen = false;
}

async function handleItemClick(notif: Notification): Promise<void> {
  if (!notif.readAt) {
    await $markReadMut.mutateAsync(notif.id);
  }
  close();
  if (notif.linkPath) {
    void goto(notif.linkPath);
  }
}

async function handleMarkAllRead(): Promise<void> {
  await $markAllReadMut.mutateAsync();
}

function handleDropdownKeydown(e: KeyboardEvent): void {
  if (e.key === 'Escape') {
    e.preventDefault();
    close();
    triggerEl?.focus();
    return;
  }
  if (e.key === 'j' || e.key === 'ArrowDown') {
    e.preventDefault();
    activeIndex = Math.min(activeIndex + 1, notifications.length - 1);
    return;
  }
  if (e.key === 'k' || e.key === 'ArrowUp') {
    e.preventDefault();
    activeIndex = Math.max(activeIndex - 1, 0);
    return;
  }
  if (e.key === 'Enter' && notifications[activeIndex]) {
    e.preventDefault();
    void handleItemClick(notifications[activeIndex]);
  }
}
</script>

<!-- Trigger -->
<div class="nb-wrap">
  <button
    bind:this={triggerEl}
    class="nb-trigger btn-compact btn-compact-ghost btn-compact-icon"
    aria-label="Notifications{unreadCount > 0 ? ` (${unreadCount} unread)` : ''}"
    aria-haspopup="true"
    aria-expanded={isOpen}
    onclick={toggle}
    title="Notifications"
  >
    <Bell size={14} aria-hidden="true" />
    {#if unreadCount > 0}
      <span class="nb-badge" aria-hidden="true">
        {unreadCount > 99 ? "99+" : unreadCount}
      </span>
    {/if}
  </button>

  <!-- Dropdown -->
  {#if isOpen}
    <div
      bind:this={dropdownEl}
      class="nb-dropdown glass-panel"
      role="dialog"
      aria-label="Notifications panel"
      tabindex="-1"
      onkeydown={handleDropdownKeydown}
    >
      <!-- Header -->
      <div class="nb-header">
        <span class="nb-header__title">Notifications</span>
        {#if unreadCount > 0}
          <button
            class="nb-mark-all btn-compact btn-compact-ghost"
            onclick={handleMarkAllRead}
            aria-label="Mark all notifications as read"
          >
            Mark all read
          </button>
        {/if}
      </div>

      <!-- List -->
      <div class="nb-list" role="list" aria-label="Recent notifications">
        {#if $notifListQ.isLoading}
          <div class="nb-empty">Loading…</div>
        {:else if notifications.length === 0}
          <div class="nb-empty">
            <span class="nb-empty__icon" aria-hidden="true">🔔</span>
            <p class="nb-empty__text">No notifications yet</p>
          </div>
        {:else}
          {#each notifications as notif, i (notif.id)}
            <button
              class="nb-item"
              class:nb-item--unread={!notif.readAt}
              class:nb-item--focused={i === activeIndex}
              aria-label="{notif.title}{!notif.readAt ? ' (unread)' : ''}"
              onclick={() => handleItemClick(notif)}
              onmouseenter={() => { activeIndex = i; }}
            >
              {#if notif.icon}
                <span class="nb-item__icon" aria-hidden="true">{notif.icon}</span>
              {:else}
                <span class="nb-item__icon nb-item__icon--fallback" aria-hidden="true">
                  <Bell size={12} />
                </span>
              {/if}

              <div class="nb-item__content">
                <div class="nb-item__top">
                  <span class="nb-item__title">{notif.title}</span>
                  <time
                    class="nb-item__time"
                    datetime={notif.insertedAt}
                    title={notif.insertedAt}
                  >{relativeTime(notif.insertedAt)}</time>
                </div>
                <p class="nb-item__body">{notif.body}</p>
              </div>

              {#if !notif.readAt}
                <span class="nb-item__dot" aria-hidden="true"></span>
              {/if}
            </button>
          {/each}
        {/if}
      </div>

      <!-- Footer: View all link -->
      <div class="nb-footer">
        <a
          class="nb-footer__link"
          href="/notifications"
          onclick={close}
          aria-label="View all notifications"
        >
          View all
        </a>
      </div>
    </div>
  {/if}
</div>

<style>
  /* Wrapper — provides positioning context for the dropdown */
  .nb-wrap {
    position: relative;
  }

  /* Trigger button */
  .nb-trigger {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
  }

  /* Badge — red circle overlapping the bell top-right */
  .nb-badge {
    position: absolute;
    top: 2px;
    right: 2px;
    min-width: 14px;
    height: 14px;
    padding: 0 3px;
    border-radius: 9999px;
    background: var(--signal-error, #e54d4d);
    color: #fff;
    font-family: var(--font-sans);
    font-size: 9px;
    font-weight: 700;
    line-height: 14px;
    text-align: center;
    pointer-events: none;
    box-sizing: border-box;
  }

  /* Dropdown panel */
  .nb-dropdown {
    position: absolute;
    bottom: calc(100% + var(--space-2));
    right: 0;
    width: 320px;
    max-height: 480px;
    z-index: 50;
    display: flex;
    flex-direction: column;
    border-radius: var(--radius-lg);
    overflow: hidden;
    box-shadow:
      0 8px 32px color-mix(in oklch, var(--bg) 40%, transparent 60%),
      0 2px 8px color-mix(in oklch, var(--bg) 30%, transparent 70%);
  }

  /* Header */
  .nb-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-2) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .nb-header__title {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
  }

  .nb-mark-all {
    font-size: 11px;
    color: var(--fg-muted);
    padding: var(--space-1) var(--space-2);
  }

  /* Scrollable list */
  .nb-list {
    flex: 1;
    overflow-y: auto;
    max-height: 380px;
    padding: var(--space-1);
  }

  /* Empty state */
  .nb-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-6) var(--space-4);
    text-align: center;
  }

  .nb-empty__icon {
    font-size: 24px;
    opacity: 0.4;
  }

  .nb-empty__text {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    margin: 0;
  }

  /* Notification item */
  .nb-item {
    display: flex;
    align-items: flex-start;
    gap: var(--space-2);
    width: 100%;
    padding: var(--space-2) var(--space-2);
    background: transparent;
    border: none;
    border-radius: var(--radius-md);
    cursor: pointer;
    text-align: left;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
    position: relative;
  }

  .nb-item:hover,
  .nb-item--focused {
    background: color-mix(in oklch, var(--fg) 5%, transparent 95%);
  }

  .nb-item__icon {
    flex-shrink: 0;
    width: 20px;
    height: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 14px;
    margin-top: 1px;
  }

  .nb-item__icon--fallback {
    color: var(--fg-subtle);
  }

  .nb-item__content {
    flex: 1;
    min-width: 0;
  }

  .nb-item__top {
    display: flex;
    align-items: baseline;
    gap: var(--space-2);
    justify-content: space-between;
  }

  .nb-item__title {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex: 1;
  }

  .nb-item--unread .nb-item__title {
    font-weight: 600;
  }

  .nb-item__time {
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--fg-subtle);
    flex-shrink: 0;
    white-space: nowrap;
  }

  .nb-item__body {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    margin: 2px 0 0;
    overflow: hidden;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    -webkit-box-orient: vertical;
    line-height: 1.4;
  }

  /* Footer — View all link */
  .nb-footer {
    border-top: 1px solid var(--border);
    flex-shrink: 0;
  }

  .nb-footer__link {
    display: block;
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    text-align: center;
    text-decoration: none;
    transition: color 0.1s ease, background 0.1s ease;
  }

  .nb-footer__link:hover {
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }

  .nb-footer__link:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: -2px;
  }

  /* Unread dot — right edge */
  .nb-item__dot {
    flex-shrink: 0;
    width: 6px;
    height: 6px;
    border-radius: 9999px;
    background: var(--signal-error, #e54d4d);
    margin-top: 5px;
    align-self: flex-start;
  }
</style>
