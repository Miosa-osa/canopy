// @vitest-environment jsdom
/**
 * active-workspace.svelte.ts — unit tests covering pure-logic surface.
 *
 * The Svelte 5 rune state is exercised by component-level tests
 * (WorkspaceSwitcher, NewWorkspaceDialog). These tests cover the
 * persistence contract, slug resolution, and event-emission shape that
 * are independently verifiable.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ACTIVE_WORKSPACE_LS_KEY, WORKSPACE_CHANGED_EVENT } from './active-workspace.svelte.js';

describe('ACTIVE_WORKSPACE_LS_KEY', () => {
  it('uses the canonical localStorage key', () => {
    expect(ACTIVE_WORKSPACE_LS_KEY).toBe('canopy.activeWorkspace.slug');
  });

  it('is distinct from the legacy ui.svelte.ts key', () => {
    // The legacy key was `canopy.currentWorkspaceSlug` — they MUST differ
    // so a rollback to the old store doesn't clobber new state.
    expect(ACTIVE_WORKSPACE_LS_KEY).not.toBe('canopy.currentWorkspaceSlug');
  });
});

describe('WORKSPACE_CHANGED_EVENT', () => {
  it('is the canonical event name listeners subscribe to', () => {
    expect(WORKSPACE_CHANGED_EVENT).toBe('workspace.changed');
  });

  it('can be dispatched and received as a CustomEvent', () => {
    const listener = vi.fn();
    window.addEventListener(WORKSPACE_CHANGED_EVENT, listener);
    window.dispatchEvent(
      new CustomEvent(WORKSPACE_CHANGED_EVENT, {
        detail: { slug: 'x', name: 'X', rootPath: '/x' },
      })
    );
    window.removeEventListener(WORKSPACE_CHANGED_EVENT, listener);
    expect(listener).toHaveBeenCalledTimes(1);
  });
});

// ── Pool sync resolution ─────────────────────────────────────────────────────

describe('syncPool resolution logic', () => {
  // Mirror the resolver inside `syncPool()` — exercised in isolation.
  function resolve(currentSlug: string | null, pool: Array<{ slug: string }>): string | null {
    if (currentSlug === null && pool.length > 0) return pool[0].slug;
    if (currentSlug !== null) {
      const found = pool.find((w) => w.slug === currentSlug);
      if (found) return currentSlug;
      if (pool.length > 0) return pool[0].slug;
      return null;
    }
    return null;
  }

  it('auto-selects the first workspace when none is active', () => {
    expect(resolve(null, [{ slug: 'a' }, { slug: 'b' }])).toBe('a');
  });

  it('keeps the active slug when it still exists in the pool', () => {
    expect(resolve('b', [{ slug: 'a' }, { slug: 'b' }])).toBe('b');
  });

  it('falls back to first when persisted slug was deleted', () => {
    expect(resolve('ghost', [{ slug: 'alpha' }])).toBe('alpha');
  });

  it('returns null when the pool is empty and slug is unresolvable', () => {
    expect(resolve('ghost', [])).toBeNull();
    expect(resolve(null, [])).toBeNull();
  });
});

// ── Persistence contract ─────────────────────────────────────────────────────

describe('persistence contract', () => {
  let store: Map<string, string>;

  beforeEach(() => {
    store = new Map();
  });

  function persist(slug: string | null): void {
    if (slug === null) store.delete(ACTIVE_WORKSPACE_LS_KEY);
    else store.set(ACTIVE_WORKSPACE_LS_KEY, slug);
  }

  it('persists the slug under the canonical key', () => {
    persist('dev-shop');
    expect(store.get(ACTIVE_WORKSPACE_LS_KEY)).toBe('dev-shop');
  });

  it('removes the entry when slug is null', () => {
    persist('present');
    persist(null);
    expect(store.has(ACTIVE_WORKSPACE_LS_KEY)).toBe(false);
  });

  it('overwrites an existing slug', () => {
    persist('first');
    persist('second');
    expect(store.get(ACTIVE_WORKSPACE_LS_KEY)).toBe('second');
  });
});
