/**
 * SSE EventSource helper for live session streaming.
 *
 * Connects to /api/v1/sessions/:id/events and dispatches typed callbacks
 * for transcript entries, status changes, and stream completion.
 *
 * Supports replay from a sequence position via ?from=<sequence> query param.
 * Returns an unsubscribe function that closes the EventSource cleanly.
 */

import type { SessionStatus, TranscriptEntry } from '$lib/domain/sessions/types.js';
import { API_BASE } from './client.js';

export type { SessionStatus, TranscriptEntry };

export interface RealtimeEvent {
  type: string;
  payload: unknown;
}

export type RealtimeHandler = (event: RealtimeEvent) => void;

/**
 * Subscribe to live transcript entries and status updates for a session.
 *
 * @param id         - Session ID to stream
 * @param onEntry    - Called for each new TranscriptEntry
 * @param onStatus   - Called when session status changes
 * @param onDone     - Called when the stream signals completion
 * @param fromSeq    - Optional sequence number for replay (SSE ?from= param)
 * @returns Unsubscribe function — call it to close the EventSource
 */
export function subscribeToSession(
  id: string,
  onEntry: (entry: TranscriptEntry) => void,
  onStatus: (status: SessionStatus) => void,
  onDone: () => void,
  fromSeq?: number
): () => void {
  const url = new URL(`${API_BASE}/sessions/${id}/events`);
  if (fromSeq !== undefined) {
    url.searchParams.set('from', String(fromSeq));
  }

  const source = new EventSource(url.toString());

  source.addEventListener('transcript_entry', (e: MessageEvent<string>) => {
    try {
      const entry = JSON.parse(e.data) as TranscriptEntry;
      onEntry(entry);
    } catch {
      // malformed entry — skip silently, don't crash the stream
    }
  });

  source.addEventListener('status', (e: MessageEvent<string>) => {
    try {
      const payload = JSON.parse(e.data) as { status: SessionStatus };
      onStatus(payload.status);
    } catch {
      // ignore malformed status events
    }
  });

  source.addEventListener('done', () => {
    onDone();
    source.close();
  });

  source.addEventListener('error', () => {
    // EventSource will auto-reconnect on transient errors.
    // We do not call onDone here — let the server signal done explicitly.
  });

  return () => {
    source.close();
  };
}

/**
 * @deprecated Use subscribeToSession for session-scoped events.
 * Legacy no-op kept for backward compatibility with stub callers.
 */
export function connectRealtime(_handler: RealtimeHandler): () => void {
  return () => {
    // no-op
  };
}
