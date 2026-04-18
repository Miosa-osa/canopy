/**
 * Tests for notifications query factories.
 * Pure-logic tests: query key shapes, staleTime, refetchInterval, mutation key shapes.
 * No DOM required — runs in node environment.
 */
import { describe, expect, it } from "vitest";
import type { Notification } from "$lib/domain/notifications/types.js";
import {
  deleteNotificationMutation,
  markAllReadMutation,
  markReadMutation,
  notificationsQuery,
  unreadCountQuery,
} from "./notifications.js";

// ── Fixtures ──────────────────────────────────────────────────────────────────

function makeNotification(overrides: Partial<Notification> = {}): Notification {
  return {
    id: "notif-1",
    userId: "user-1",
    agentSlug: null,
    type: "task_assigned",
    title: "Task assigned",
    body: "Roberto assigned 'Fix login' to you.",
    icon: "📋",
    linkPath: "/tasks/T-123",
    payload: { taskId: "T-123" },
    readAt: null,
    deliveredChannels: ["in_app"],
    insertedAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    ...overrides,
  };
}

// ── unreadCountQuery() ────────────────────────────────────────────────────────

describe("unreadCountQuery()", () => {
  it('returns queryKey ["notifications", "unread_count"]', () => {
    const q = unreadCountQuery();
    expect(q.queryKey).toEqual(["notifications", "unread_count"]);
  });

  it("has staleTime 0 (always revalidate on mount)", () => {
    expect(unreadCountQuery().staleTime).toBe(0);
  });

  it("has refetchInterval of 60_000ms", () => {
    expect(unreadCountQuery().refetchInterval).toBe(60_000);
  });

  it("has a queryFn function", () => {
    expect(typeof unreadCountQuery().queryFn).toBe("function");
  });
});

// ── notificationsQuery() ──────────────────────────────────────────────────────

describe("notificationsQuery()", () => {
  it('returns queryKey ["notifications", "list", {}] with no filters', () => {
    const q = notificationsQuery();
    expect(q.queryKey).toEqual(["notifications", "list", {}]);
  });

  it("includes filter object in queryKey", () => {
    const filters = { unread: true, limit: 10 };
    const q = notificationsQuery(filters);
    expect(q.queryKey).toEqual(["notifications", "list", filters]);
  });

  it("has staleTime of 30_000", () => {
    expect(notificationsQuery().staleTime).toBe(30_000);
  });

  it("has a queryFn function", () => {
    expect(typeof notificationsQuery().queryFn).toBe("function");
  });

  it("accepts unread filter", () => {
    const q = notificationsQuery({ unread: true });
    expect((q.queryKey[2] as { unread: boolean }).unread).toBe(true);
  });

  it("accepts limit filter", () => {
    const q = notificationsQuery({ limit: 5 });
    expect((q.queryKey[2] as { limit: number }).limit).toBe(5);
  });
});

// ── markReadMutation() ────────────────────────────────────────────────────────

describe("markReadMutation()", () => {
  it('returns mutationKey ["notifications", "mark_read"]', () => {
    expect(markReadMutation().mutationKey).toEqual([
      "notifications",
      "mark_read",
    ]);
  });

  it("has a mutationFn function", () => {
    expect(typeof markReadMutation().mutationFn).toBe("function");
  });
});

// ── markAllReadMutation() ─────────────────────────────────────────────────────

describe("markAllReadMutation()", () => {
  it('returns mutationKey ["notifications", "mark_all_read"]', () => {
    expect(markAllReadMutation().mutationKey).toEqual([
      "notifications",
      "mark_all_read",
    ]);
  });

  it("has a mutationFn function", () => {
    expect(typeof markAllReadMutation().mutationFn).toBe("function");
  });
});

// ── deleteNotificationMutation() ──────────────────────────────────────────────

describe("deleteNotificationMutation()", () => {
  it('returns mutationKey ["notifications", "delete"]', () => {
    expect(deleteNotificationMutation().mutationKey).toEqual([
      "notifications",
      "delete",
    ]);
  });

  it("has a mutationFn function", () => {
    expect(typeof deleteNotificationMutation().mutationFn).toBe("function");
  });
});

// ── Notification shape ────────────────────────────────────────────────────────

describe("Notification shape (fixture integrity)", () => {
  it("makeNotification returns a valid Notification", () => {
    const n = makeNotification();
    expect(typeof n.id).toBe("string");
    expect(typeof n.type).toBe("string");
    expect(typeof n.title).toBe("string");
    expect(typeof n.body).toBe("string");
    expect(Array.isArray(n.deliveredChannels)).toBe(true);
  });

  it("readAt is null for unread notifications", () => {
    expect(makeNotification().readAt).toBeNull();
  });

  it("readAt is a string for read notifications", () => {
    const n = makeNotification({ readAt: new Date().toISOString() });
    expect(typeof n.readAt).toBe("string");
  });

  it("linkPath can be null", () => {
    const n = makeNotification({ linkPath: null });
    expect(n.linkPath).toBeNull();
  });

  it("icon can be null", () => {
    const n = makeNotification({ icon: null });
    expect(n.icon).toBeNull();
  });
});
