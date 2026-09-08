/**
 * Tile context declaration system for decoupled cross-pane data sharing.
 * Panes produce keyed context values; any pane can consume them reactively.
 * Svelte 5 runes — reactive Map-backed store, singleton export.
 */

export interface ContextEntry {
  key: string; // e.g. "cwd", "branch", "sessionId", "agentSlug"
  value: unknown;
  source: string; // paneId that produced it
  updatedAt: number;
}

type WatchHandler = (entry: ContextEntry) => void;

class PaneContextStore {
  #entries = $state<Map<string, ContextEntry>>(new Map());
  // key → set of handlers watching it
  #watchers = new Map<string, Set<WatchHandler>>();

  /** A pane declares a context value it produces. Last-write-wins by updatedAt. */
  produce(paneId: string, key: string, value: unknown): void {
    const updatedAt = Date.now();
    const existing = this.#entries.get(key);

    // Reject stale writes (shouldn't happen in single-threaded JS, but defensive)
    if (existing && existing.updatedAt > updatedAt) return;

    const entry: ContextEntry = { key, value, source: paneId, updatedAt };
    this.#entries = new Map(this.#entries).set(key, entry);

    // Notify watchers synchronously
    this.#watchers.get(key)?.forEach((h) => {
      h(entry);
    });
  }

  /**
   * Read a context value by key.
   * Reactive — Svelte components can $derive from this.
   */
  consume(key: string): ContextEntry | undefined {
    return this.#entries.get(key);
  }

  /** Subscribe to changes on a key. Returns unsubscribe fn. */
  watch(key: string, handler: WatchHandler): () => void {
    if (!this.#watchers.has(key)) this.#watchers.set(key, new Set());
    this.#watchers.get(key)!.add(handler);

    return () => {
      this.#watchers.get(key)?.delete(handler);
      if (this.#watchers.get(key)?.size === 0) this.#watchers.delete(key);
    };
  }

  /** Get all current context entries as a flat array. Reactive. */
  all(): ContextEntry[] {
    return Array.from(this.#entries.values());
  }

  /**
   * Remove all context entries produced by a pane.
   * Call this when a pane is unmounted/closed.
   */
  removePaneContext(paneId: string): void {
    const next = new Map(this.#entries);
    let changed = false;

    for (const [key, entry] of next) {
      if (entry.source === paneId) {
        next.delete(key);
        changed = true;
        // Notify watchers that the key is gone (undefined-ish — re-consume will return undefined)
        this.#watchers.get(key)?.forEach((h) => {
          h({ key, value: undefined, source: paneId, updatedAt: Date.now() });
        });
      }
    }

    if (changed) this.#entries = next;
  }
}

export const paneContext = new PaneContextStore();
