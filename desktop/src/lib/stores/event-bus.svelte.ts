/**
 * Client-side typed event bus for cross-pane communication.
 * Supports wildcard routing, ring-buffer history, singleton export.
 * Svelte 5 runes — reactive history maps.
 */

export interface BusEvent {
  channel: string; // e.g. "tile:abc123", "agent:conductor", "kanban:default"
  type: string; // e.g. "claimed", "output", "status-change"
  payload: unknown;
  timestamp: number;
}

type Handler = (event: BusEvent) => void;

const RING_BUFFER_SIZE = 200;

/** Simple glob match: supports leading/trailing/middle `*` wildcard. */
function matchPattern(pattern: string, channel: string): boolean {
  if (pattern === '*') return true;
  if (pattern === channel) return true;
  if (pattern.endsWith(':*')) {
    const prefix = pattern.slice(0, -1); // "tile:" from "tile:*"
    return channel.startsWith(prefix);
  }
  if (pattern.startsWith('*:')) {
    const suffix = pattern.slice(2); // "output" from "*:output"
    return channel.endsWith(`:${suffix}`);
  }
  return false;
}

class EventBusStore {
  // Exact-channel subscriptions
  #exact = new Map<string, Set<Handler>>();
  // Wildcard subscriptions: pattern → handlers
  #wildcards = new Map<string, Set<Handler>>();
  // Ring buffer: channel → circular BusEvent[]
  #history = $state<Map<string, BusEvent[]>>(new Map());

  /** Subscribe to events. Supports wildcards: "tile:*", "*". Returns unsubscribe fn. */
  on(pattern: string, handler: Handler): () => void {
    const isWildcard = pattern.includes('*');
    const bucket = isWildcard ? this.#wildcards : this.#exact;

    if (!bucket.has(pattern)) bucket.set(pattern, new Set());
    bucket.get(pattern)!.add(handler);

    return () => {
      bucket.get(pattern)?.delete(handler);
      if (bucket.get(pattern)?.size === 0) bucket.delete(pattern);
    };
  }

  /** Publish an event to channel with type and optional payload. */
  emit(channel: string, type: string, payload: unknown = undefined): void {
    const event: BusEvent = { channel, type, payload, timestamp: Date.now() };

    // Append to ring buffer (circular overwrite at RING_BUFFER_SIZE)
    const current = this.#history.get(channel) ?? [];
    const next =
      current.length >= RING_BUFFER_SIZE ? [...current.slice(1), event] : [...current, event];
    // Reassign to trigger Svelte reactivity
    this.#history = new Map(this.#history).set(channel, next);

    // Dispatch to exact subscribers
    this.#exact.get(channel)?.forEach((h) => {
      h(event);
    });

    // Dispatch to matching wildcard subscribers
    this.#wildcards.forEach((handlers, pattern) => {
      if (matchPattern(pattern, channel)) {
        handlers.forEach((h) => {
          h(event);
        });
      }
    });
  }

  /**
   * Get recent events for a channel.
   * Reactive — Svelte components can $derive from this.
   */
  history(channel: string, limit: number = RING_BUFFER_SIZE): BusEvent[] {
    const buf = this.#history.get(channel) ?? [];
    return limit >= buf.length ? buf : buf.slice(buf.length - limit);
  }

  /** Clear all subscriptions and history. */
  reset(): void {
    this.#exact.clear();
    this.#wildcards.clear();
    this.#history = new Map();
  }
}

export const eventBus = new EventBusStore();
