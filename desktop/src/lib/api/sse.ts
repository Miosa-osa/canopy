// src/lib/api/sse.ts
// fetch-based SSE client with authorization support and auto-reconnect

import type { StreamEvent } from "./types";
import { getToken, isMockEnabled } from "./client";

const BASE_URL = import.meta.env.VITE_API_URL ?? "http://127.0.0.1:9089";
const API_PREFIX = "/api/v1";

const INITIAL_DELAY_MS = 1_000;
const MAX_DELAY_MS = 30_000;
const BACKOFF_FACTOR = 2;

/**
 * Append JWT as query param for SSE authentication.
 *
 * SECURITY NOTE: Tokens in query parameters may be logged in server access logs,
 * browser history, and Referer headers. This is a known tradeoff required because
 * the native EventSource API does not support custom headers. The fetch-based SSE
 * client also sends the token via Authorization header where supported. Query param
 * tokens should be short-lived and rotated frequently in production.
 */
function appendTokenParam(url: string, token: string | null): string {
  if (!token) return url;
  const separator = url.includes("?") ? "&" : "?";
  return `${url}${separator}token=${encodeURIComponent(token)}`;
}

export interface SSECallbacks {
  onEvent: (event: StreamEvent) => void;
  onConnect?: () => void;
  onDisconnect?: () => void;
  onError?: (error: Error) => void;
  onDone?: () => void;
}

export interface StreamController {
  abort: () => void;
}

function parseSSEBlock(block: string): StreamEvent | null {
  const lines = block.split("\n");
  let eventType = "";
  let data = "";
  for (const line of lines) {
    if (line.startsWith(":")) continue;
    if (line.startsWith("event: "))
      eventType = line.slice("event: ".length).trim();
    else if (line.startsWith("data: "))
      data = line.slice("data: ".length).trim();
  }
  if (!data || data === "[DONE]") return null;
  try {
    const parsed = JSON.parse(data);
    if (eventType && (parsed.type === "system_event" || !parsed.type))
      parsed.type = eventType;
    return parsed as StreamEvent;
  } catch {
    if (eventType === "streaming_token" || eventType === "token") {
      return { type: "streaming_token", delta: data } as StreamEvent;
    }
    return null;
  }
}

async function consumeStream(
  response: Response,
  callbacks: SSECallbacks,
  signal: AbortSignal,
): Promise<void> {
  if (!response.body) throw new Error("Response body is null");
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  callbacks.onConnect?.();
  try {
    while (true) {
      if (signal.aborted) break;
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const blocks = buffer.split("\n\n");
      buffer = blocks.pop() ?? "";
      for (const block of blocks) {
        if (!block.trim()) continue;
        const event = parseSSEBlock(block);
        if (!event) continue;
        callbacks.onEvent(event);
        if (event.type === "done") {
          callbacks.onDone?.();
          return;
        }
        if (event.type === "error") {
          callbacks.onError?.(
            new Error(
              (event as { message?: string }).message ?? "Stream error",
            ),
          );
          return;
        }
      }
    }
  } finally {
    reader.cancel().catch(() => undefined);
    callbacks.onDisconnect?.();
  }
}

export interface ChatStreamOptions extends SSECallbacks {
  sessionId: string;
  content: string;
  model?: string;
}

export function streamMessage(options: ChatStreamOptions): StreamController {
  const controller = new AbortController();
  const { signal } = controller;
  (async () => {
    const token = getToken();
    const headers: Record<string, string> = {
      Accept: "text/event-stream",
      "Cache-Control": "no-cache",
      "X-Accel-Buffering": "no",
    };
    if (token) headers["Authorization"] = `Bearer ${token}`;
    try {
      const streamUrl = appendTokenParam(
        `${BASE_URL}${API_PREFIX}/sessions/${options.sessionId}/stream`,
        token,
      );
      const streamResponse = await fetch(streamUrl, { headers, signal });
      if (!streamResponse.ok)
        throw new Error(`Stream HTTP ${streamResponse.status}`);
      const msgHeaders: Record<string, string> = {
        "Content-Type": "application/json",
      };
      if (token) msgHeaders["Authorization"] = `Bearer ${token}`;
      const messagePromise = fetch(
        `${BASE_URL}${API_PREFIX}/sessions/${options.sessionId}/message`,
        {
          method: "POST",
          headers: msgHeaders,
          body: JSON.stringify({
            message: options.content,
            model: options.model,
          }),
          signal,
        },
      ).then(async (res) => {
        if (!res.ok) throw new Error(`Message HTTP ${res.status}`);
      });
      await Promise.all([
        consumeStream(streamResponse, options, signal),
        messagePromise,
      ]);
    } catch (error) {
      if ((error as Error).name === "AbortError") return;
      options.onError?.(error as Error);
    }
  })();
  return { abort: () => controller.abort() };
}

export function subscribeToActivityStream(
  callbacks: SSECallbacks,
  signal: AbortSignal,
): void {
  if (isMockEnabled()) return;
  let delayMs = INITIAL_DELAY_MS;
  const connect = async (): Promise<void> => {
    if (signal.aborted || isMockEnabled()) return;
    const token = getToken();
    const headers: Record<string, string> = {
      Accept: "text/event-stream",
      "Cache-Control": "no-cache",
    };
    if (token) headers["Authorization"] = `Bearer ${token}`;
    try {
      const activityUrl = appendTokenParam(
        `${BASE_URL}${API_PREFIX}/activity/stream`,
        token,
      );
      const response = await fetch(activityUrl, { headers, signal });
      if (!response.ok || !response.body)
        throw new Error(`HTTP ${response.status}`);
      delayMs = INITIAL_DELAY_MS;
      await consumeStream(response, callbacks, signal);
    } catch (error) {
      if ((error as Error).name === "AbortError") return;
      callbacks.onError?.(error as Error);
    }
    if (!signal.aborted) {
      await new Promise<void>((resolve) => {
        const timer = setTimeout(resolve, delayMs);
        signal.addEventListener(
          "abort",
          () => {
            clearTimeout(timer);
            resolve();
          },
          { once: true },
        );
      });
      delayMs = Math.min(delayMs * BACKOFF_FACTOR, MAX_DELAY_MS);
      connect();
    }
  };
  connect();
}

export function connectSSE(
  path: string,
  callbacks: SSECallbacks,
  maxAttempts = 5,
): StreamController {
  const outer = new AbortController();
  const { signal } = outer;
  if (isMockEnabled()) return { abort: () => outer.abort() };
  let attempt = 0;
  let delayMs = INITIAL_DELAY_MS;
  const connect = async (): Promise<void> => {
    if (signal.aborted || isMockEnabled()) return;
    const token = getToken();
    const headers: Record<string, string> = {
      Accept: "text/event-stream",
      "Cache-Control": "no-cache",
    };
    if (token) headers["Authorization"] = `Bearer ${token}`;
    try {
      const sseUrl = appendTokenParam(`${BASE_URL}${API_PREFIX}${path}`, token);
      const response = await fetch(sseUrl, { headers, signal });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      attempt = 0;
      delayMs = INITIAL_DELAY_MS;
      await consumeStream(response, callbacks, signal);
    } catch (error) {
      if ((error as Error).name === "AbortError") return;
      callbacks.onDisconnect?.();
      if (attempt >= maxAttempts) {
        callbacks.onError?.(
          new Error(`SSE: max reconnect attempts (${maxAttempts}) exceeded`),
        );
        return;
      }
    }
    if (!signal.aborted) {
      attempt++;
      await new Promise<void>((resolve) => {
        const timer = setTimeout(resolve, delayMs);
        signal.addEventListener(
          "abort",
          () => {
            clearTimeout(timer);
            resolve();
          },
          { once: true },
        );
      });
      delayMs = Math.min(delayMs * BACKOFF_FACTOR, MAX_DELAY_MS);
      connect();
    }
  };
  connect();
  return { abort: () => outer.abort() };
}
