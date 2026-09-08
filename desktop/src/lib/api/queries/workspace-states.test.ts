/**
 * workspace-states.ts — pure-logic tests.
 *
 * The TanStack hook + debounce/optimistic flow runs inside Svelte's rune
 * runtime; component-level tests would need the compiler. These tests
 * cover the constants, key encoding, and the rollback decision tree that
 * are independently verifiable.
 */
import { describe, expect, it, vi } from 'vitest';
import { WORKSPACE_STATE_DEBOUNCE_MS } from './workspace-states.js';

describe('WORKSPACE_STATE_DEBOUNCE_MS', () => {
  it('is 500 ms — fast enough for snappy UI, slow enough to coalesce', () => {
    expect(WORKSPACE_STATE_DEBOUNCE_MS).toBe(500);
  });
});

describe('debounce coalescing logic', () => {
  // Mirror the timer-coalescing logic from `useWorkspaceState.set()`.
  // Each call clears the previous timer, so multiple sets within the
  // window result in exactly ONE PUT carrying the final value.
  function makeDebouncer(flush: (v: number) => void, ms: number) {
    let timer: ReturnType<typeof setTimeout> | null = null;
    let pending = 0;
    return (v: number) => {
      pending = v;
      if (timer !== null) clearTimeout(timer);
      timer = setTimeout(() => flush(pending), ms);
    };
  }

  it('coalesces rapid calls into a single flush', () => {
    vi.useFakeTimers();
    try {
      const flush = vi.fn();
      const set = makeDebouncer(flush, WORKSPACE_STATE_DEBOUNCE_MS);

      set(1);
      set(2);
      set(3);
      vi.advanceTimersByTime(WORKSPACE_STATE_DEBOUNCE_MS);

      expect(flush).toHaveBeenCalledTimes(1);
      expect(flush).toHaveBeenCalledWith(3);
    } finally {
      vi.useRealTimers();
    }
  });

  it('emits a separate flush after the window has elapsed', () => {
    vi.useFakeTimers();
    try {
      const flush = vi.fn();
      const set = makeDebouncer(flush, WORKSPACE_STATE_DEBOUNCE_MS);

      set(1);
      vi.advanceTimersByTime(WORKSPACE_STATE_DEBOUNCE_MS);
      set(2);
      vi.advanceTimersByTime(WORKSPACE_STATE_DEBOUNCE_MS);

      expect(flush).toHaveBeenCalledTimes(2);
      expect(flush).toHaveBeenNthCalledWith(1, 1);
      expect(flush).toHaveBeenNthCalledWith(2, 2);
    } finally {
      vi.useRealTimers();
    }
  });
});

describe('optimistic-UI rollback logic', () => {
  // Mirror the rollback contract used by `useWorkspaceState.set()`.
  // After a failed PUT the cell value reverts to the last server-confirmed
  // value, and `error` is populated.
  function applyOutcome<T>(
    confirmed: T,
    optimistic: T,
    success: boolean
  ): { value: T; error: string | null } {
    if (success) return { value: optimistic, error: null };
    return { value: confirmed, error: 'PUT failed' };
  }

  it('retains optimistic value on success', () => {
    expect(applyOutcome('old', 'new', true)).toEqual({
      value: 'new',
      error: null,
    });
  });

  it('rolls back to confirmed value on failure', () => {
    expect(applyOutcome('old', 'new', false)).toEqual({
      value: 'old',
      error: 'PUT failed',
    });
  });
});

describe('key URL encoding', () => {
  // The key is dropped into a URL path segment via encodeURIComponent.
  // Dots are preserved (allowed by the server's key regex) but unsafe
  // chars are escaped.
  it('preserves dots inside a key', () => {
    expect(encodeURIComponent('mosaic.layout')).toBe('mosaic.layout');
  });

  it('escapes whitespace', () => {
    expect(encodeURIComponent('with space')).toBe('with%20space');
  });

  it('escapes slashes — keys cannot traverse paths', () => {
    expect(encodeURIComponent('a/b')).toBe('a%2Fb');
  });
});
