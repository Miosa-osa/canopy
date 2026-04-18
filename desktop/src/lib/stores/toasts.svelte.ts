/**
 * Global toast store — Svelte 5 runes.
 * Stacks up to 3 visible toasts, auto-dismisses by default in 4 000 ms.
 * Pattern: class-based store matching ui.svelte.ts conventions.
 */

export type ToastKind = 'info' | 'success' | 'warning' | 'error';

export interface Toast {
  id: string;
  message: string;
  kind: ToastKind;
  /** Epoch ms when this toast should auto-dismiss. */
  expiresAt: number;
}

class ToastsStore {
  items = $state<Toast[]>([]);

  /**
   * Show a toast. Returns the generated id so callers can dismiss early.
   * Auto-dismisses after `durationMs` (default 4 000).
   */
  show(message: string, kind: ToastKind = 'info', durationMs: number = 4_000): string {
    const id = `toast-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
    const expiresAt = Date.now() + durationMs;

    this.items = [...this.items, { id, message, kind, expiresAt }];

    // Schedule auto-dismiss — setTimeout keeps the store framework-agnostic.
    setTimeout(() => {
      this.dismiss(id);
    }, durationMs);

    return id;
  }

  /** Remove a toast by id. No-op if already gone. */
  dismiss(id: string): void {
    this.items = this.items.filter((t) => t.id !== id);
  }

  /** Convenience helpers. */
  info(message: string, durationMs?: number): string {
    return this.show(message, 'info', durationMs);
  }

  success(message: string, durationMs?: number): string {
    return this.show(message, 'success', durationMs);
  }

  warning(message: string, durationMs?: number): string {
    return this.show(message, 'warning', durationMs);
  }

  error(message: string, durationMs?: number): string {
    return this.show(message, 'error', durationMs);
  }
}

export const toasts = new ToastsStore();
