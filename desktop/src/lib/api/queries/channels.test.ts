/**
 * Tests for channels query factories.
 * Verifies query key shapes, filter wiring, enabled flags, and mutation key shapes.
 */
import { describe, expect, it } from "vitest";
import {
  addMemberMutation,
  addReactionMutation,
  channelMessagesQuery,
  channelQuery,
  channelsQuery,
  createChannelMutation,
  deleteChannelMutation,
  deleteMessageMutation,
  editMessageMutation,
  markReadMutation,
  pinMessageMutation,
  removeMemberMutation,
  removeReactionMutation,
  sendMessageMutation,
  unpinMessageMutation,
  unreadCountQuery,
  updateChannelMutation,
} from "./channels.js";

// ---------------------------------------------------------------------------
// channelsQuery
// ---------------------------------------------------------------------------

describe("channelsQuery()", () => {
  it('returns query key ["channels", {}] with no filters', () => {
    const q = channelsQuery();
    expect(q.queryKey).toEqual(["channels", {}]);
  });

  it("includes filters in query key", () => {
    const q = channelsQuery({ workspaceSlug: "acme" });
    expect(q.queryKey).toEqual(["channels", { workspaceSlug: "acme" }]);
  });

  it("has staleTime of 30_000", () => {
    expect(channelsQuery().staleTime).toBe(30_000);
  });

  it("has a queryFn function", () => {
    expect(typeof channelsQuery().queryFn).toBe("function");
  });
});

// ---------------------------------------------------------------------------
// channelQuery
// ---------------------------------------------------------------------------

describe("channelQuery()", () => {
  it('returns query key ["channels", id]', () => {
    const q = channelQuery("channel-abc");
    expect(q.queryKey).toEqual(["channels", "channel-abc"]);
  });

  it("is disabled when id is empty", () => {
    expect(channelQuery("").enabled).toBe(false);
  });

  it("is enabled when id is non-empty", () => {
    expect(channelQuery("chan-1").enabled).toBe(true);
  });

  it("has staleTime of 30_000", () => {
    expect(channelQuery("x").staleTime).toBe(30_000);
  });
});

// ---------------------------------------------------------------------------
// createChannelMutation
// ---------------------------------------------------------------------------

describe("createChannelMutation()", () => {
  it('returns mutationKey ["channels", "create"]', () => {
    expect(createChannelMutation().mutationKey).toEqual(["channels", "create"]);
  });

  it("has a mutationFn function", () => {
    expect(typeof createChannelMutation().mutationFn).toBe("function");
  });
});

// ---------------------------------------------------------------------------
// updateChannelMutation
// ---------------------------------------------------------------------------

describe("updateChannelMutation()", () => {
  it('returns mutationKey ["channels", "update"]', () => {
    expect(updateChannelMutation().mutationKey).toEqual(["channels", "update"]);
  });

  it("has a mutationFn function", () => {
    expect(typeof updateChannelMutation().mutationFn).toBe("function");
  });
});

// ---------------------------------------------------------------------------
// deleteChannelMutation
// ---------------------------------------------------------------------------

describe("deleteChannelMutation()", () => {
  it('returns mutationKey ["channels", "delete"]', () => {
    expect(deleteChannelMutation().mutationKey).toEqual(["channels", "delete"]);
  });

  it("has a mutationFn function", () => {
    expect(typeof deleteChannelMutation().mutationFn).toBe("function");
  });
});

// ---------------------------------------------------------------------------
// addMemberMutation / removeMemberMutation
// ---------------------------------------------------------------------------

describe("addMemberMutation()", () => {
  it('returns mutationKey ["channels", "members", "add"]', () => {
    expect(addMemberMutation().mutationKey).toEqual([
      "channels",
      "members",
      "add",
    ]);
  });

  it("has a mutationFn function", () => {
    expect(typeof addMemberMutation().mutationFn).toBe("function");
  });
});

describe("removeMemberMutation()", () => {
  it('returns mutationKey ["channels", "members", "remove"]', () => {
    expect(removeMemberMutation().mutationKey).toEqual([
      "channels",
      "members",
      "remove",
    ]);
  });

  it("has a mutationFn function", () => {
    expect(typeof removeMemberMutation().mutationFn).toBe("function");
  });
});

// ---------------------------------------------------------------------------
// channelMessagesQuery
// ---------------------------------------------------------------------------

describe("channelMessagesQuery()", () => {
  it('returns query key ["channels", id, "messages", {}] with no opts', () => {
    const q = channelMessagesQuery("chan-1");
    expect(q.queryKey).toEqual(["channels", "chan-1", "messages", {}]);
  });

  it("includes opts in query key", () => {
    const q = channelMessagesQuery("chan-1", { limit: 50 });
    expect(q.queryKey).toEqual([
      "channels",
      "chan-1",
      "messages",
      { limit: 50 },
    ]);
  });

  it("is disabled when channelId is empty", () => {
    expect(channelMessagesQuery("").enabled).toBe(false);
  });

  it("has staleTime of 0 (always fresh)", () => {
    expect(channelMessagesQuery("chan-1").staleTime).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// sendMessageMutation / editMessageMutation / deleteMessageMutation
// ---------------------------------------------------------------------------

describe("sendMessageMutation()", () => {
  it("returns channel-scoped mutationKey", () => {
    expect(sendMessageMutation("chan-1").mutationKey).toEqual([
      "channels",
      "chan-1",
      "messages",
      "send",
    ]);
  });

  it("has a mutationFn function", () => {
    expect(typeof sendMessageMutation("chan-1").mutationFn).toBe("function");
  });
});

describe("editMessageMutation()", () => {
  it("returns channel-scoped mutationKey", () => {
    expect(editMessageMutation("chan-1").mutationKey).toEqual([
      "channels",
      "chan-1",
      "messages",
      "edit",
    ]);
  });

  it("has a mutationFn function", () => {
    expect(typeof editMessageMutation("chan-1").mutationFn).toBe("function");
  });
});

describe("deleteMessageMutation()", () => {
  it("returns channel-scoped mutationKey", () => {
    expect(deleteMessageMutation("chan-1").mutationKey).toEqual([
      "channels",
      "chan-1",
      "messages",
      "delete",
    ]);
  });

  it("has a mutationFn function", () => {
    expect(typeof deleteMessageMutation("chan-1").mutationFn).toBe("function");
  });
});

// ---------------------------------------------------------------------------
// addReactionMutation / removeReactionMutation
// ---------------------------------------------------------------------------

describe("addReactionMutation()", () => {
  it("returns channel-scoped mutationKey", () => {
    expect(addReactionMutation("chan-1").mutationKey).toEqual([
      "channels",
      "chan-1",
      "reactions",
      "add",
    ]);
  });

  it("has a mutationFn function", () => {
    expect(typeof addReactionMutation("chan-1").mutationFn).toBe("function");
  });
});

describe("removeReactionMutation()", () => {
  it("returns channel-scoped mutationKey", () => {
    expect(removeReactionMutation("chan-1").mutationKey).toEqual([
      "channels",
      "chan-1",
      "reactions",
      "remove",
    ]);
  });

  it("has a mutationFn function", () => {
    expect(typeof removeReactionMutation("chan-1").mutationFn).toBe("function");
  });
});

// ---------------------------------------------------------------------------
// pinMessageMutation / unpinMessageMutation
// ---------------------------------------------------------------------------

describe("pinMessageMutation()", () => {
  it("returns channel-scoped mutationKey", () => {
    expect(pinMessageMutation("chan-1").mutationKey).toEqual([
      "channels",
      "chan-1",
      "messages",
      "pin",
    ]);
  });

  it("has a mutationFn function", () => {
    expect(typeof pinMessageMutation("chan-1").mutationFn).toBe("function");
  });
});

describe("unpinMessageMutation()", () => {
  it("returns channel-scoped mutationKey", () => {
    expect(unpinMessageMutation("chan-1").mutationKey).toEqual([
      "channels",
      "chan-1",
      "messages",
      "unpin",
    ]);
  });

  it("has a mutationFn function", () => {
    expect(typeof unpinMessageMutation("chan-1").mutationFn).toBe("function");
  });
});

// ---------------------------------------------------------------------------
// markReadMutation / unreadCountQuery
// ---------------------------------------------------------------------------

describe("markReadMutation()", () => {
  it("returns channel-scoped mutationKey", () => {
    expect(markReadMutation("chan-1").mutationKey).toEqual([
      "channels",
      "chan-1",
      "read",
    ]);
  });

  it("has a mutationFn function", () => {
    expect(typeof markReadMutation("chan-1").mutationFn).toBe("function");
  });
});

describe("unreadCountQuery()", () => {
  it('returns query key ["channels", id, "unread"]', () => {
    const q = unreadCountQuery("chan-1");
    expect(q.queryKey).toEqual(["channels", "chan-1", "unread"]);
  });

  it("is disabled when channelId is empty", () => {
    expect(unreadCountQuery("").enabled).toBe(false);
  });

  it("has staleTime of 10_000", () => {
    expect(unreadCountQuery("chan-1").staleTime).toBe(10_000);
  });
});
