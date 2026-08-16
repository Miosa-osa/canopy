/**
 * WebSocket helper for the live_runs event bus.
 *
 * Opens a Phoenix v2 channel over raw WebSocket and returns a Svelte readable
 * store of accumulated events. Uses the same frame format as the terminal
 * session channel — no Phoenix.js dependency.
 *
 * Usage:
 *   const { events, disconnect } = subscribeLiveRuns({ workspace: 'default' });
 *   $events  // LiveRunEvent[]  (newest at head, appended on arrival)
 *   disconnect();  // clean close
 */

import { readable, type Readable } from "svelte/store";

// ── Types ─────────────────────────────────────────────────────────────────────

export type LiveRunEventKind =
  | "run_started"
  | "run_status"
  | "run_log"
  | "run_event"
  | "run_tool_call"
  | "run_tool_result"
  | "run_finished";

export interface RunStartedPayload {
  runId: string;
  shortId: string;
  sessionId: string | null;
  workspaceSlug: string;
  agentSlug: string | null;
  startedAt: string;
}

export interface RunStatusPayload {
  runId: string;
  shortId: string;
  workspaceSlug: string;
  status: "paused" | "running";
  at: string;
}

export interface RunLogPayload {
  runId: string;
  shortId: string;
  workspaceSlug: string;
  seq: number;
  kind: "stdout" | "stderr" | "event" | "tool_call" | "tool_result";
  data: string;
  at: string;
}

export interface RunEventPayload {
  runId: string;
  shortId: string;
  workspaceSlug: string;
  kind: string;
  payload: unknown;
  at: string;
}

export interface RunToolCallPayload {
  runId: string;
  shortId: string;
  workspaceSlug: string;
  toolName: string;
  params: Record<string, unknown>;
  at: string;
}

export interface RunToolResultPayload {
  runId: string;
  shortId: string;
  workspaceSlug: string;
  toolName: string;
  result: unknown;
  at: string;
}

export interface RunFinishedPayload {
  runId: string;
  shortId: string;
  workspaceSlug: string;
  status: string;
  usageJson: Record<string, unknown>;
  finishedAt: string;
}

export type LiveRunEventPayload =
  | RunStartedPayload
  | RunStatusPayload
  | RunLogPayload
  | RunEventPayload
  | RunToolCallPayload
  | RunToolResultPayload
  | RunFinishedPayload;

export interface LiveRunEvent {
  kind: LiveRunEventKind;
  payload: LiveRunEventPayload;
  receivedAt: string;
}

// ── Scope helpers ─────────────────────────────────────────────────────────────

type Scope =
  | { workspace: string; run?: never }
  | { run: string; workspace?: never }
  | "all";

function topicFor(scope: Scope): string {
  if (scope === "all") return "live_runs:all";
  if ("run" in scope && scope.run) return `live_runs:run:${scope.run}`;
  if ("workspace" in scope && scope.workspace)
    return `live_runs:workspace:${scope.workspace}`;
  return "live_runs:all";
}

// ── Phoenix v2 frame codec ────────────────────────────────────────────────────
// Phoenix encodes messages as JSON arrays:
// [join_ref, ref, topic, event, payload]

interface PhxFrame {
  joinRef: string | null;
  ref: string | null;
  topic: string;
  event: string;
  payload: unknown;
}

function encodeFrame(frame: PhxFrame): string {
  return JSON.stringify([
    frame.joinRef,
    frame.ref,
    frame.topic,
    frame.event,
    frame.payload,
  ]);
}

function decodeFrame(raw: string): PhxFrame | null {
  try {
    const arr = JSON.parse(raw) as [
      string | null,
      string | null,
      string,
      string,
      unknown,
    ];
    if (!Array.isArray(arr) || arr.length < 5) return null;
    return {
      joinRef: arr[0],
      ref: arr[1],
      topic: arr[2],
      event: arr[3],
      payload: arr[4],
    };
  } catch {
    return null;
  }
}

// snake_case → camelCase (shallow, for event payloads only)
function toCamel(obj: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(obj)) {
    const camel = k.replace(/_([a-z])/g, (_, c: string) => c.toUpperCase());
    out[camel] = v;
  }
  return out;
}

// ── WebSocket URL ─────────────────────────────────────────────────────────────

const WS_BASE = "ws://localhost:9190/socket/websocket";

// ── Public API ────────────────────────────────────────────────────────────────

export function subscribeLiveRuns(scope: Scope): {
  events: Readable<LiveRunEvent[]>;
  disconnect: () => void;
} {
  const topic = topicFor(scope);
  let ws: WebSocket | null = null;
  let stopFn: (() => void) | null = null;
  let refCounter = 0;

  const nextRef = (): string => String(++refCounter);

  const events = readable<LiveRunEvent[]>([], (set) => {
    const accumulated: LiveRunEvent[] = [];
    const url = `${WS_BASE}?vsn=2.0.0`;

    ws = new WebSocket(url);

    let joined = false;
    let closed = false;

    ws.onopen = () => {
      if (!ws || closed) return;
      ws.send(
        encodeFrame({
          joinRef: "1",
          ref: nextRef(),
          topic,
          event: "phx_join",
          payload: {},
        }),
      );
    };

    ws.onmessage = (e: MessageEvent<string>) => {
      const frame = decodeFrame(e.data);
      if (!frame || frame.topic !== topic) return;

      if (frame.event === "phx_reply") {
        const resp = frame.payload as { status?: string };
        if (resp.status === "ok") joined = true;
        return;
      }
      if (frame.event === "phx_error" || frame.event === "phx_close") return;

      if (!joined) return;

      const kind = frame.event as LiveRunEventKind;
      const rawPayload = frame.payload as Record<string, unknown>;
      const payload = toCamel(rawPayload) as unknown as LiveRunEventPayload;

      const event: LiveRunEvent = {
        kind,
        payload,
        receivedAt: new Date().toISOString(),
      };

      accumulated.unshift(event);
      set([...accumulated]);
    };

    ws.onerror = () => {
      // Silently swallow — onclose handles cleanup.
    };

    ws.onclose = () => {
      closed = true;
      // Do NOT re-trigger the store or set() on close — prevents
      // the infinite re-render loop when the channel doesn't exist.
    };

    stopFn = () => {
      if (ws && ws.readyState < WebSocket.CLOSING) {
        // Send phx_leave before closing
        ws.send(
          encodeFrame({
            joinRef: "1",
            ref: nextRef(),
            topic,
            event: "phx_leave",
            payload: {},
          }),
        );
        ws.close(1000, "disconnect");
      }
      ws = null;
    };

    return stopFn;
  });

  return {
    events,
    disconnect: () => stopFn?.(),
  };
}
