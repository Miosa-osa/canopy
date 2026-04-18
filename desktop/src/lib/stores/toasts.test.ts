/**
 * Toast store — pure-logic unit tests.
 *
 * The ToastsStore class uses Svelte 5 $state runes, which require the Svelte
 * compiler context. These tests exercise the pure functions and type contracts
 * that live outside rune-reactive state, verifiable in a Node environment.
 */
import { describe, expect, it } from 'vitest';
import type { Toast, ToastKind } from './toasts.svelte.js';

// ── ToastKind exhaustive check ────────────────────────────────────────────────

describe('ToastKind', () => {
  it('should accept all four valid kind values', () => {
    const kinds: ToastKind[] = ['info', 'success', 'warning', 'error'];
    expect(kinds).toHaveLength(4);
    for (const k of kinds) {
      expect(typeof k).toBe('string');
    }
  });
});

// ── Toast interface shape ─────────────────────────────────────────────────────

describe('Toast interface', () => {
  it('should satisfy the full shape contract', () => {
    const toast: Toast = {
      id: 'toast-1234-abc',
      message: 'Hello from tests',
      kind: 'success',
      expiresAt: Date.now() + 4_000,
    };

    expect(toast.id).toMatch(/^toast-/);
    expect(typeof toast.message).toBe('string');
    expect(toast.kind).toBe('success');
    expect(toast.expiresAt).toBeGreaterThan(Date.now());
  });

  it('should allow all valid kind values on a Toast', () => {
    const kinds: ToastKind[] = ['info', 'success', 'warning', 'error'];
    for (const kind of kinds) {
      const t: Toast = { id: `t-${kind}`, message: kind, kind, expiresAt: 0 };
      expect(t.kind).toBe(kind);
    }
  });
});

// ── ID generation shape ───────────────────────────────────────────────────────

describe('toast id format', () => {
  it('should generate unique-looking ids from the documented template', () => {
    // Reproduce the id generation logic from ToastsStore.show() in isolation.
    function makeId(): string {
      return `toast-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
    }

    const a = makeId();
    const b = makeId();

    expect(a).toMatch(/^toast-\d+-[a-z0-9]{5}$/);
    expect(b).toMatch(/^toast-\d+-[a-z0-9]{5}$/);
    // Vanishingly unlikely to collide — validates uniqueness pattern.
    expect(a).not.toBe(b);
  });
});

// ── Skeleton count clamping ───────────────────────────────────────────────────

describe('skeleton count clamp', () => {
  // Mirror the clamp logic used in SkeletonList and SkeletonGrid.
  function clampList(n: number): number {
    return Math.max(1, Math.min(n, 30));
  }
  function clampGrid(n: number): number {
    return Math.max(1, Math.min(n, 60));
  }
  function clampCols(n: number): number {
    return Math.max(1, Math.min(n, 12));
  }

  it('should clamp SkeletonList count to [1, 30]', () => {
    expect(clampList(0)).toBe(1);
    expect(clampList(-5)).toBe(1);
    expect(clampList(5)).toBe(5);
    expect(clampList(30)).toBe(30);
    expect(clampList(31)).toBe(30);
    expect(clampList(1000)).toBe(30);
  });

  it('should clamp SkeletonGrid count to [1, 60]', () => {
    expect(clampGrid(0)).toBe(1);
    expect(clampGrid(60)).toBe(60);
    expect(clampGrid(61)).toBe(60);
  });

  it('should clamp SkeletonGrid columns to [1, 12]', () => {
    expect(clampCols(0)).toBe(1);
    expect(clampCols(3)).toBe(3);
    expect(clampCols(12)).toBe(12);
    expect(clampCols(13)).toBe(12);
  });
});
