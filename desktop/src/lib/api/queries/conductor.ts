/**
 * Conductor realtime helpers.
 *
 * Conductor (the Build cockpit's primary chat agent + runtime delegator)
 * emits structured tool-call results from the backend. The frontend listens
 * to those results on the Conductor session's SSE stream and feeds each one
 * to `buildDispatcher` which translates the action into a Mosaic layout
 * mutation.
 *
 * SSE infrastructure already exists for sessions
 * (`/api/v1/sessions/:id/events`) — see `subscribeToSession` in
 * `$lib/api/realtime.ts`. This module wraps it with a Conductor-specific
 * filter so the dispatcher only sees tool-call results, not raw transcript
 * text.
 *
 * Note: a Conductor-specific SSE topic (e.g. `/api/v1/conductor/:id/events`)
 * does not yet exist on the backend. Until it does, Conductor tool-call
 * results are extracted from the assistant's transcript entries on the
 * existing session SSE stream — the `tool_call` payload shape is preserved
 * as `entry.content.tool_result` (see flagged gap in
 * `wiring/conductor-bootstrap-wiring.md`).
 */

import { subscribeToSession } from '$lib/api/realtime.js';
import {
  type ConductorAction,
  type ConductorToolResult,
  isConductorAction,
} from '$lib/domain/conductor/types.js';
import type { TranscriptEntry } from '$lib/domain/sessions/types.js';

export type ConductorResultHandler = (result: ConductorToolResult) => void;

/**
 * Subscribe to Conductor tool-call results for a session.
 *
 * Wraps `subscribeToSession`: every transcript entry is inspected for a
 * Conductor-shaped tool result. Matches are forwarded to `onResult`;
 * non-matching entries are ignored.
 *
 * Returns an unsubscribe function that closes the underlying EventSource.
 */
export function subscribeToConductor(
  sessionId: string,
  onResult: ConductorResultHandler
): () => void {
  return subscribeToSession(
    sessionId,
    (entry) => {
      const result = extractConductorResult(entry);
      if (result) onResult(result);
    },
    () => {
      // Status changes are not consumed by the dispatcher.
    },
    () => {
      // Stream completion handled by the SSE helper itself.
    }
  );
}

// ── Internals ────────────────────────────────────────────────────────────────

/**
 * Pull a `ConductorToolResult` out of a transcript entry, if the entry is a
 * tool-call result for one of the Conductor `build.*` tools.
 *
 * Recognised shapes (be lenient — backend may evolve):
 *   - `entry.content.action: "open_pane" | ...` — the action sits directly
 *     inside the entry content (current pattern for the registry's
 *     dispatch return value).
 *   - `entry.content.result.action: ...` — wrapped in a `result` field.
 *   - `entry.content.tool: "build.open_pane", entry.content.result: {...}`.
 *
 * Returns null when the entry is not a Conductor action.
 */
function extractConductorResult(entry: TranscriptEntry): ConductorToolResult | null {
  const content = (entry as { content?: unknown }).content;
  if (!content || typeof content !== 'object') return null;

  // Shape 1: direct action.
  if (isConductorAction(content)) {
    return { result: content as ConductorAction };
  }

  // Shape 2: wrapped in result.
  const wrapped = (content as { result?: unknown }).result;
  if (isConductorAction(wrapped)) {
    return {
      tool: stringField(content, 'tool'),
      run_id: stringField(content, 'run_id'),
      result: wrapped as ConductorAction,
    };
  }

  return null;
}

function stringField(obj: unknown, key: string): string | undefined {
  if (typeof obj !== 'object' || obj === null) return undefined;
  const v = (obj as Record<string, unknown>)[key];
  return typeof v === 'string' ? v : undefined;
}
