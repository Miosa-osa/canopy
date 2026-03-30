/**
 * E-04: Frontend nodes store unit tests (sprint-01 deliverable)
 *
 * Tests the `nodesStore` from `src/lib/stores/nodes.svelte.ts`.
 *
 * ## Actual API (from source inspection)
 *
 * The store:
 *   - calls `invoke('scan_nodes_dir', { path: workspacePath + "/nodes" })`
 *   - receives `NodeMeta[]` directly (Tauri throws on error, no ok/error wrapper)
 *   - early-returns from load() when `!isTauri()`
 *   - nodeById is a `Map<string, Node>` keyed by node id
 *
 * ## Test Strategy
 *
 * 1. We set `window.__TAURI_INTERNALS__` to a non-null value to satisfy isTauri().
 * 2. We mock `@tauri-apps/api/core` so invoke is a controllable spy.
 * 3. We call load() and inspect the reactive state via the store's getter properties.
 *
 * ## Note on Svelte 5 $state/$derived
 * The store uses Svelte 5 runes. In a jsdom Vitest environment without the
 * Svelte compiler transformation, $state and $derived are resolved at module
 * load time as plain reactive closures. The store's exported object uses
 * getters (get nodes(), get error(), etc.) which delegate to the private
 * rune variables — this works in Vitest because Svelte 5 runes compile to
 * plain JS signals, not framework-specific hooks.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

// ── Mock @tauri-apps/api/core BEFORE importing store ─────────────────────────
vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));

import { invoke } from "@tauri-apps/api/core";
const mockInvoke = vi.mocked(invoke);

// ── Mock $lib/utils/platform to always return isTauri() = true ───────────────
vi.mock("$lib/utils/platform", () => ({
  isTauri: () => true,
  isMacOS: () => false,
  isWindows: () => false,
  isLinux: () => false,
}));

// ── Import store after mocks are in place ────────────────────────────────────
import { nodesStore } from "../nodes.svelte";

// ── Fixture data ──────────────────────────────────────────────────────────────

const mockNodeMetas = [
  {
    id: "01-roberto",
    name: "Roberto",
    nodeType: "person",
    health: "green",
    owner: "Roberto H. Luna",
    path: "/nodes/01-roberto",
    signalCount: 3,
    lastUpdated: "2026-03-29T00:00:00Z",
  },
  {
    id: "02-miosa",
    name: "MIOSA",
    nodeType: "entity",
    health: "yellow",
    owner: "Roberto H. Luna",
    path: "/nodes/02-miosa",
    signalCount: 7,
    lastUpdated: "2026-03-29T00:00:00Z",
  },
  {
    id: "04-ai-masters",
    name: "AI Masters",
    nodeType: "operation:program",
    health: "green",
    owner: "Ed, Robert Potter",
    path: "/nodes/04-ai-masters",
    signalCount: 2,
    lastUpdated: "2026-03-28T00:00:00Z",
  },
];

// ── Setup / teardown ──────────────────────────────────────────────────────────

beforeEach(() => {
  mockInvoke.mockReset();
  nodesStore.reset();
});

afterEach(() => {
  nodesStore.reset();
});

// ── Test 1: load() calls invoke with correct args ─────────────────────────────

describe("nodesStore.load()", () => {
  it("calls invoke('scan_nodes_dir', { path: workspacePath + '/nodes' })", async () => {
    mockInvoke.mockResolvedValueOnce([]);

    await nodesStore.load("/Users/rhl/Desktop/OptimalOS");

    expect(mockInvoke).toHaveBeenCalledTimes(1);
    expect(mockInvoke).toHaveBeenCalledWith("scan_nodes_dir", {
      path: "/Users/rhl/Desktop/OptimalOS/nodes",
    });
  });

  it("appends /nodes to the workspacePath before calling invoke", async () => {
    mockInvoke.mockResolvedValueOnce([]);

    await nodesStore.load("/some/workspace");

    const [, args] = mockInvoke.mock.calls[0] as unknown as [
      string,
      { path: string },
    ];
    expect((args as unknown as { path: string }).path).toBe(
      "/some/workspace/nodes",
    );
  });

  // ── Test 2: ok response populates nodes ────────────────────────────────────

  it("populates nodesStore.nodes from NodeMeta[] response", async () => {
    mockInvoke.mockResolvedValueOnce(mockNodeMetas);

    await nodesStore.load("/nodes");

    expect(nodesStore.nodes).toHaveLength(3);
    expect(nodesStore.error).toBeNull();

    const roberto = nodesStore.nodes.find((n) => n.id === "01-roberto");
    expect(roberto).toBeDefined();
    expect(roberto?.name).toBe("Roberto");
    expect(roberto?.path).toBe("/nodes/01-roberto");
  });

  it("maps NodeMeta to Node with number field parsed from id prefix", async () => {
    mockInvoke.mockResolvedValueOnce([mockNodeMetas[1]]); // 02-miosa

    await nodesStore.load("/nodes");

    const miosa = nodesStore.nodes[0];
    expect(miosa.number).toBe(2);
    expect(miosa.href).toBe("/app/nodes/02-miosa");
  });

  it("clears error on successful load", async () => {
    // First cause an error
    mockInvoke.mockRejectedValueOnce(new Error("connection failed"));
    await nodesStore.load("/nodes");
    expect(nodesStore.error).toBe("connection failed");

    // Then succeed
    mockInvoke.mockResolvedValueOnce(mockNodeMetas);
    await nodesStore.load("/nodes");

    expect(nodesStore.error).toBeNull();
    expect(nodesStore.nodes).toHaveLength(3);
  });

  // ── Test 3: error response sets error, clears nodes ────────────────────────

  it("sets error and clears nodes when invoke throws", async () => {
    mockInvoke.mockRejectedValueOnce(new Error("directory not found"));

    await nodesStore.load("/nonexistent/path");

    expect(nodesStore.nodes).toHaveLength(0);
    expect(nodesStore.error).toBe("directory not found");
  });

  it("handles non-Error throws by converting to string", async () => {
    mockInvoke.mockRejectedValueOnce("string error from Tauri");

    await nodesStore.load("/bad/path");

    expect(nodesStore.nodes).toHaveLength(0);
    expect(nodesStore.error).toBe("string error from Tauri");
  });

  it("handles empty array response without error", async () => {
    mockInvoke.mockResolvedValueOnce([]);

    await nodesStore.load("/empty/workspace");

    expect(nodesStore.nodes).toHaveLength(0);
    expect(nodesStore.error).toBeNull();
  });

  // ── Test 4: nodeById map ────────────────────────────────────────────────────

  it("nodeById is a Map keyed by node id", async () => {
    mockInvoke.mockResolvedValueOnce(mockNodeMetas);

    await nodesStore.load("/nodes");

    const map = nodesStore.nodeById;

    expect(map).toBeInstanceOf(Map);
    expect(map.has("01-roberto")).toBe(true);
    expect(map.has("02-miosa")).toBe(true);
    expect(map.has("04-ai-masters")).toBe(true);
    expect(map.has("99-nonexistent")).toBe(false);
  });

  it("nodeById values match loaded nodes", async () => {
    mockInvoke.mockResolvedValueOnce(mockNodeMetas);

    await nodesStore.load("/nodes");

    const roberto = nodesStore.nodeById.get("01-roberto");
    expect(roberto).toBeDefined();
    expect(roberto?.name).toBe("Roberto");
    expect(roberto?.number).toBe(1);

    const miosa = nodesStore.nodeById.get("02-miosa");
    expect(miosa?.health).toBe("yellow");
  });

  it("nodeById is empty after reset", async () => {
    mockInvoke.mockResolvedValueOnce(mockNodeMetas);
    await nodesStore.load("/nodes");
    expect(nodesStore.nodeById.size).toBe(3);

    nodesStore.reset();
    expect(nodesStore.nodeById.size).toBe(0);
  });
});

// ── Test: sortedNodes ─────────────────────────────────────────────────────────

describe("nodesStore.sortedNodes", () => {
  it("returns nodes sorted by number ascending", async () => {
    // Return in reverse order to verify sort
    const reversed = [...mockNodeMetas].reverse();
    mockInvoke.mockResolvedValueOnce(reversed);

    await nodesStore.load("/nodes");

    const sorted = nodesStore.sortedNodes;
    expect(sorted[0].number).toBeLessThanOrEqual(sorted[1].number);
    expect(sorted[1].number).toBeLessThanOrEqual(sorted[2].number);
  });
});

// ── Test: reset() ─────────────────────────────────────────────────────────────

describe("nodesStore.reset()", () => {
  it("clears nodes, error, and loading state", async () => {
    mockInvoke.mockResolvedValueOnce(mockNodeMetas);
    await nodesStore.load("/nodes");

    expect(nodesStore.nodes).toHaveLength(3);

    nodesStore.reset();

    expect(nodesStore.nodes).toHaveLength(0);
    expect(nodesStore.error).toBeNull();
    expect(nodesStore.loading).toBe(false);
  });
});
