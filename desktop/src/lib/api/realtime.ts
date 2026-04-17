/**
 * SSE → TanStack Query invalidation stub.
 * Pattern: Multica WS-as-invalidation with 100ms debounce.
 * Week 3: connect to Phoenix SSE endpoint /api/stream.
 */
export type RealtimeEvent = {
  type: string;
  payload: unknown;
};

export type RealtimeHandler = (event: RealtimeEvent) => void;

// Stub — returns a no-op cleanup function
export function connectRealtime(_handler: RealtimeHandler): () => void {
  return () => {
    // disconnect — Week 3
  };
}
