/**
 * AgentConversationPane — contract-level tests.
 *
 * The pane component itself uses Svelte 5 runes + TanStack Query, which
 * the Vitest "server" project doesn't load (mirrors CodeEditorPane.test
 * and TabHoverCard.test). So this file tests the contracts the pane
 * relies on, NOT the rendered DOM:
 *
 *   - PaneKind union accepts "agent_conversation"
 *   - Pane.config round-trips through JSON unchanged (the persistence
 *     layer is a JSON.stringify into localStorage)
 *   - The fork-clone helper produces a structurally-independent twin
 *     with a fresh id, mirroring the TabsSection menu mutators
 *
 * Type-only imports from `mosaic-layout.svelte.js` are safe — only the
 * runtime store class would pull in runes (server project disallows).
 */
import { describe, expect, it } from 'vitest';
import type { Pane, PaneKind } from '$lib/stores/mosaic-layout.svelte.js';

// ── PaneKind union ───────────────────────────────────────────────────────────

describe('PaneKind', () => {
  it("includes 'agent_conversation' as a valid variant", () => {
    // Compile-time assertion: if the union ever drops the variant, this
    // file fails type-check, which the Vitest pipeline picks up via tsc.
    const k: PaneKind = 'agent_conversation';
    expect(k).toBe('agent_conversation');
  });
});

// ── Pane.config shape ────────────────────────────────────────────────────────

describe('Pane.config', () => {
  it('accepts agent-conversation config without losing fields', () => {
    const pane: Pane = {
      id: 'p1',
      kind: 'agent_conversation',
      ref: 'new',
      title: 'New conversation',
      config: {
        cwd: '~/code/MIOSA/code',
        model: 'auto (cost-efficient)',
      },
    };
    expect(pane.config?.cwd).toBe('~/code/MIOSA/code');
    expect(pane.config?.model).toBe('auto (cost-efficient)');
  });

  it('treats a session-bound conversation config as round-trippable JSON', () => {
    const pane: Pane = {
      id: 'p2',
      kind: 'agent_conversation',
      ref: 'abc-123-uuid',
      title: 'New conversation',
      config: {
        sessionId: 'abc-123-uuid',
        cwd: '/tmp',
        model: 'claude-sonnet-4',
      },
    };
    const round = JSON.parse(JSON.stringify(pane)) as Pane;
    expect(round).toEqual(pane);
  });

  it('permits omitting config entirely (matches existing pane kinds)', () => {
    const pane: Pane = {
      id: 'p3',
      kind: 'agent_conversation',
      ref: 'new',
      title: 'New conversation',
    };
    expect(pane.config).toBeUndefined();
  });
});

// ── Fork-clone helper (mirrors TabsSection mutators) ─────────────────────────
// Reimplemented here in pure form — the .svelte version is the only call site
// and its tests rely on this being structurally identical.

function freshId(): string {
  return Math.random().toString(36).slice(2, 9);
}

function clonePaneForFork(src: Pane): Pane {
  return {
    id: freshId(),
    kind: src.kind,
    ref: src.ref,
    title: src.title,
    config: src.config ? { ...src.config } : undefined,
  };
}

describe('clonePaneForFork()', () => {
  it('regenerates the pane id so original and clone are independent', () => {
    const original: Pane = {
      id: 'orig',
      kind: 'agent_conversation',
      ref: 'session-uuid',
      title: 'New conversation',
    };
    const clone = clonePaneForFork(original);
    expect(clone.id).not.toBe(original.id);
    expect(clone.kind).toBe(original.kind);
    expect(clone.ref).toBe(original.ref);
    expect(clone.title).toBe(original.title);
  });

  it('shallow-clones config so mutating one does not leak into the other', () => {
    const original: Pane = {
      id: 'orig',
      kind: 'agent_conversation',
      ref: 'new',
      title: 'New conversation',
      config: { cwd: '~', model: 'auto', sessionId: 's-1' },
    };
    const clone = clonePaneForFork(original);
    expect(clone.config).toEqual(original.config);
    // Mutate clone's config — original should be untouched.
    (clone.config as Record<string, unknown>).cwd = '/tmp';
    expect(original.config?.cwd).toBe('~');
  });

  it('preserves an undefined config rather than fabricating an empty object', () => {
    const original: Pane = {
      id: 'orig',
      kind: 'agent_conversation',
      ref: 'new',
      title: 'New conversation',
    };
    const clone = clonePaneForFork(original);
    expect(clone.config).toBeUndefined();
  });

  it('works for non-conversation pane kinds (Fork is generic)', () => {
    const original: Pane = {
      id: 'orig',
      kind: 'terminal',
      ref: 'local',
      title: 'Local shell',
    };
    const clone = clonePaneForFork(original);
    expect(clone.kind).toBe('terminal');
    expect(clone.id).not.toBe(original.id);
  });
});

// ── Default config defaults ──────────────────────────────────────────────────

describe('default conversation config', () => {
  // The PaneContent dispatcher applies these defaults when a pane lands
  // without explicit config (e.g. created by the seed effect on /build).
  const DEFAULT_CWD = '~';
  const DEFAULT_MODEL = 'auto (cost-efficient)';

  function resolveConfig(cfg: Record<string, unknown> | undefined) {
    return {
      cwd: typeof cfg?.cwd === 'string' ? cfg.cwd : DEFAULT_CWD,
      model: typeof cfg?.model === 'string' ? cfg.model : DEFAULT_MODEL,
      sessionId: typeof cfg?.sessionId === 'string' ? cfg.sessionId : undefined,
    };
  }

  it("falls back to '~' and 'auto (cost-efficient)' when config is empty", () => {
    expect(resolveConfig(undefined)).toEqual({
      cwd: '~',
      model: 'auto (cost-efficient)',
      sessionId: undefined,
    });
  });

  it('respects explicit overrides', () => {
    expect(
      resolveConfig({
        cwd: '/Users/rhl/code/MIOSA/code',
        model: 'claude-opus-4',
        sessionId: 'sess-1',
      })
    ).toEqual({
      cwd: '/Users/rhl/code/MIOSA/code',
      model: 'claude-opus-4',
      sessionId: 'sess-1',
    });
  });

  it('ignores non-string config values', () => {
    expect(resolveConfig({ cwd: 42, model: null, sessionId: ['x'] })).toEqual({
      cwd: '~',
      model: 'auto (cost-efficient)',
      sessionId: undefined,
    });
  });
});
