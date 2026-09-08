/**
 * TanStack Query factories for the /notifications resource.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 *
 * Polling strategy: unread count polls every 60s (staleTime: 0 + refetchInterval).
 * Full list uses staleTime: 30_000 — refreshed on demand or window focus.
 */

import { apiDelete, apiGet, apiPost } from '$lib/api/client.js';
import type {
  Notification,
  NotificationFilters,
  UnreadCountResponse,
} from '$lib/domain/notifications/types.js';

// ── Raw API calls ────────────────────────────────────────────────────────────

export function getUnreadCount(): Promise<UnreadCountResponse> {
  return apiGet<UnreadCountResponse>('/notifications/unread_count');
}

export function listNotifications(filters?: NotificationFilters): Promise<Notification[]> {
  const params = new URLSearchParams();
  if (filters?.unread === true) params.set('unread', 'true');
  if (filters?.limit !== undefined) params.set('limit', String(filters.limit));
  const qs = params.toString();
  return apiGet<Notification[]>(`/notifications${qs ? `?${qs}` : ''}`);
}

export function markNotificationRead(id: string): Promise<Notification> {
  return apiPost<Notification>(`/notifications/${id}/read`, {});
}

export function markAllNotificationsRead(): Promise<{ count: number }> {
  return apiPost<{ count: number }>('/notifications/read_all', {});
}

export function deleteNotification(id: string): Promise<void> {
  return apiDelete<void>(`/notifications/${id}`);
}

// ── TanStack Query option factories ─────────────────────────────────────────

/**
 * Query for unread count badge.
 * staleTime: 0 + refetchInterval: 60_000 means it always polls on mount
 * and re-polls every 60 seconds without requiring window focus.
 */
export function unreadCountQuery() {
  return {
    queryKey: ['notifications', 'unread_count'] as const,
    queryFn: () => getUnreadCount(),
    staleTime: 0,
    refetchInterval: 60_000,
  };
}

/**
 * Query for the recent notification list shown in the bell dropdown.
 * staleTime: 30_000 — fresh enough to avoid flicker on re-open.
 */
export function notificationsQuery(filters?: NotificationFilters) {
  return {
    queryKey: ['notifications', 'list', filters ?? {}] as const,
    queryFn: () => listNotifications(filters),
    staleTime: 30_000,
  };
}

/** Mutation to mark a single notification as read. */
export function markReadMutation() {
  return {
    mutationKey: ['notifications', 'mark_read'] as const,
    mutationFn: (id: string) => markNotificationRead(id),
  };
}

/** Mutation to mark all notifications as read. */
export function markAllReadMutation() {
  return {
    mutationKey: ['notifications', 'mark_all_read'] as const,
    mutationFn: () => markAllNotificationsRead(),
  };
}

/** Mutation to delete a notification. */
export function deleteNotificationMutation() {
  return {
    mutationKey: ['notifications', 'delete'] as const,
    mutationFn: (id: string) => deleteNotification(id),
  };
}
