/**
 * NotificationBell — pure-logic unit tests.
 *
 * The component uses Svelte 5 runes + TanStack Query + DOM APIs.
 * These tests exercise the pure helper logic that runs in Node:
 * - relative time formatting
 * - unread dot derivation
 * - badge display logic
 * - keyboard index clamping
 * - Notification fixture shape integrity
 */
import { describe, expect, it } from "vitest";
import type { Notification } from "$lib/domain/notifications/types.js";

// ── Helpers mirrored from NotificationBell.svelte ────────────────────────────

function relativeTime(iso: string): string {
  const diff = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (diff < 60) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

function isUnread(notif: Pick<Notification, "readAt">): boolean {
  return notif.readAt === null;
}

/** Returns true when the badge should be visible. */
function showBadge(count: number): boolean {
  return count > 0;
}

/** Formats badge label — caps at 99+. */
function badgeLabel(count: number): string {
  return count > 99 ? "99+" : String(count);
}

/** Keyboard index clamp — j/↓ and k/↑ navigation. */
function clampIndex(
  current: number,
  direction: "up" | "down",
  listLength: number,
): number {
  if (direction === "down") return Math.min(current + 1, listLength - 1);
  return Math.max(current - 1, 0);
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

function makeNotification(overrides: Partial<Notification> = {}): Notification {
  return {
    id: "notif-1",
    userId: "user-1",
    agentSlug: null,
    type: "task_assigned",
    title: "Task assigned to you",
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

// ── Tests: relativeTime() ─────────────────────────────────────────────────────

describe("relativeTime()", () => {
  it("returns 'just now' for timestamps within 60 seconds", () => {
    const now = new Date().toISOString();
    expect(relativeTime(now)).toBe("just now");
  });

  it("returns minutes ago for timestamps < 1 hour", () => {
    const fifteenMinsAgo = new Date(Date.now() - 15 * 60 * 1000).toISOString();
    expect(relativeTime(fifteenMinsAgo)).toBe("15m ago");
  });

  it("returns hours ago for timestamps < 1 day", () => {
    const threeHoursAgo = new Date(
      Date.now() - 3 * 60 * 60 * 1000,
    ).toISOString();
    expect(relativeTime(threeHoursAgo)).toBe("3h ago");
  });

  it("returns days ago for timestamps >= 1 day", () => {
    const twoDaysAgo = new Date(
      Date.now() - 2 * 24 * 60 * 60 * 1000,
    ).toISOString();
    expect(relativeTime(twoDaysAgo)).toBe("2d ago");
  });

  it("returns '1m ago' at exactly 60 seconds", () => {
    const exactlyOneMin = new Date(Date.now() - 60 * 1000).toISOString();
    expect(relativeTime(exactlyOneMin)).toBe("1m ago");
  });
});

// ── Tests: unread dot logic ───────────────────────────────────────────────────

describe("isUnread()", () => {
  it("returns true when readAt is null", () => {
    expect(isUnread({ readAt: null })).toBe(true);
  });

  it("returns false when readAt is an ISO string", () => {
    expect(isUnread({ readAt: new Date().toISOString() })).toBe(false);
  });
});

// ── Tests: badge display ──────────────────────────────────────────────────────

describe("showBadge()", () => {
  it("returns false when count is 0", () => {
    expect(showBadge(0)).toBe(false);
  });

  it("returns true when count is 1", () => {
    expect(showBadge(1)).toBe(true);
  });

  it("returns true for large counts", () => {
    expect(showBadge(999)).toBe(true);
  });
});

describe("badgeLabel()", () => {
  it("shows exact count for values ≤ 99", () => {
    expect(badgeLabel(1)).toBe("1");
    expect(badgeLabel(42)).toBe("42");
    expect(badgeLabel(99)).toBe("99");
  });

  it("caps at '99+' for counts > 99", () => {
    expect(badgeLabel(100)).toBe("99+");
    expect(badgeLabel(999)).toBe("99+");
  });
});

// ── Tests: keyboard navigation ────────────────────────────────────────────────

describe("clampIndex() — keyboard j/k navigation", () => {
  const listLength = 5;

  it("increments on ArrowDown (j)", () => {
    expect(clampIndex(0, "down", listLength)).toBe(1);
    expect(clampIndex(3, "down", listLength)).toBe(4);
  });

  it("clamps at last item on ArrowDown", () => {
    expect(clampIndex(4, "down", listLength)).toBe(4);
    expect(clampIndex(10, "down", listLength)).toBe(4);
  });

  it("decrements on ArrowUp (k)", () => {
    expect(clampIndex(3, "up", listLength)).toBe(2);
    expect(clampIndex(1, "up", listLength)).toBe(0);
  });

  it("clamps at 0 on ArrowUp", () => {
    expect(clampIndex(0, "up", listLength)).toBe(0);
    expect(clampIndex(-5, "up", listLength)).toBe(0);
  });
});

// ── Tests: Notification fixture integrity ────────────────────────────────────

describe("Notification fixture integrity", () => {
  it("all required fields are present", () => {
    const n = makeNotification();
    expect(typeof n.id).toBe("string");
    expect(typeof n.type).toBe("string");
    expect(typeof n.title).toBe("string");
    expect(typeof n.body).toBe("string");
    expect(Array.isArray(n.deliveredChannels)).toBe(true);
  });

  it("readAt null means unread", () => {
    const n = makeNotification({ readAt: null });
    expect(isUnread(n)).toBe(true);
  });

  it("readAt set means read", () => {
    const ts = new Date().toISOString();
    const n = makeNotification({ readAt: ts });
    expect(isUnread(n)).toBe(false);
  });

  it("linkPath can be null (no navigation on click)", () => {
    const n = makeNotification({ linkPath: null });
    expect(n.linkPath).toBeNull();
  });

  it("icon can be null (fallback icon renders)", () => {
    const n = makeNotification({ icon: null });
    expect(n.icon).toBeNull();
  });

  it("payload is an object", () => {
    const n = makeNotification();
    expect(typeof n.payload).toBe("object");
    expect(n.payload).not.toBeNull();
  });
});
