/**
 * Notification domain types — mirrors the Elixir backend at /api/v1/notifications.
 * All fields are camelCase; the client.ts fetch wrapper unwraps {data: ...} envelopes.
 */

/** A single notification row. */
export interface Notification {
  id: string;
  userId: string | null;
  agentSlug: string | null;
  type: string;
  title: string;
  body: string;
  icon: string | null;
  linkPath: string | null;
  payload: Record<string, unknown>;
  readAt: string | null;
  deliveredChannels: string[];
  insertedAt: string;
  updatedAt: string;
}

/** Optional filters for GET /notifications. */
export interface NotificationFilters {
  unread?: boolean;
  limit?: number;
}

/** Shape returned by GET /notifications/unread_count. */
export interface UnreadCountResponse {
  count: number;
}
