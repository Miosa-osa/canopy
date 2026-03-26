// src/lib/stores/chat.svelte.ts
// Canopy chat store — manages sessions, messages, and SSE streaming

import type { Message, Session, StreamEvent, ToolCallRef } from "$api/types";
import { sessions as sessionsApi, messages as messagesApi } from "$api/client";
import { streamMessage, type StreamController } from "$api/sse";

export interface StreamingMessage {
  textBuffer: string;
  thinkingBuffer: string;
  toolCalls: ToolCallRef[];
}

class ChatStore {
  sessions = $state<Session[]>([]);
  currentSession = $state<Session | null>(null);
  messages = $state<Message[]>([]);
  pendingUserMessage = $state<Message | null>(null);
  streaming = $state<StreamingMessage>({
    textBuffer: "",
    thinkingBuffer: "",
    toolCalls: [],
  });
  isStreaming = $state(false);
  isLoadingSessions = $state(false);
  isLoadingMessages = $state(false);
  error = $state<string | null>(null);

  // Side panel visibility — toggled by ⌘/
  isPanelOpen = $state(false);

  #streamController: StreamController | null = null;
  #streamListeners: Array<(event: StreamEvent) => void> = [];

  // ── Panel controls ────────────────────────────────────────────────────────

  togglePanel(): void {
    this.isPanelOpen = !this.isPanelOpen;
  }

  openPanel(): void {
    this.isPanelOpen = true;
  }

  closePanel(): void {
    this.isPanelOpen = false;
  }

  // ── Stream listeners ──────────────────────────────────────────────────────

  addStreamListener(fn: (event: StreamEvent) => void): void {
    this.#streamListeners = [...this.#streamListeners, fn];
  }

  removeStreamListener(fn: (event: StreamEvent) => void): void {
    this.#streamListeners = this.#streamListeners.filter((l) => l !== fn);
  }

  // ── Session operations ────────────────────────────────────────────────────

  async listSessions(workspaceId?: string): Promise<void> {
    this.isLoadingSessions = true;
    this.error = null;
    try {
      this.sessions = await sessionsApi.list(workspaceId);
    } catch (e) {
      this.error = (e as Error).message;
    } finally {
      this.isLoadingSessions = false;
    }
  }

  async createSession(agentId?: string, title?: string): Promise<Session> {
    const result = await sessionsApi.create({
      agent_id: agentId ?? "default",
      title,
    });
    const session: Session = {
      id: result.id,
      agent_id: agentId ?? "default",
      agent_name: result.agent_name ?? "Default",
      title: title ?? null,
      status: "active",
      message_count: 0,
      token_usage: { input: 0, output: 0, cache_read: 0, cache_write: 0 },
      cost_cents: 0,
      started_at: new Date().toISOString(),
      completed_at: null,
      created_at: new Date().toISOString(),
    };
    this.sessions = [session, ...this.sessions];
    this.currentSession = session;
    this.messages = [];
    return session;
  }

  async loadSession(sessionId: string): Promise<void> {
    this.isLoadingMessages = true;
    this.error = null;
    this.cancelGeneration();
    try {
      const [session, msgs] = await Promise.all([
        sessionsApi.get(sessionId),
        messagesApi.list(sessionId),
      ]);
      this.currentSession = session;
      this.messages = msgs;
      this.pendingUserMessage = null;
    } catch (e) {
      this.error = (e as Error).message;
    } finally {
      this.isLoadingMessages = false;
    }
  }

  async deleteSession(sessionId: string): Promise<void> {
    const previousSessions = this.sessions;
    const previousCurrent = this.currentSession;
    const previousMessages = this.messages;
    this.sessions = this.sessions.filter((s) => s.id !== sessionId);
    if (this.currentSession?.id === sessionId) {
      this.currentSession = null;
      this.messages = [];
    }
    try {
      await sessionsApi.delete(sessionId);
    } catch (e) {
      this.sessions = previousSessions;
      this.currentSession = previousCurrent;
      this.messages = previousMessages;
      this.error = (e as Error).message;
    }
  }

  // ── Messaging ─────────────────────────────────────────────────────────────

  async sendMessage(content: string, agentId?: string): Promise<void> {
    if (this.isStreaming || !content.trim()) return;
    this.error = null;

    let sessionId = this.currentSession?.id;
    if (!sessionId) {
      const session = await this.createSession(agentId);
      sessionId = session.id;
    }

    this.pendingUserMessage = {
      id: `msg-${Date.now()}`,
      session_id: sessionId,
      role: "user",
      content,
      timestamp: new Date().toISOString(),
    };
    this.streaming = { textBuffer: "", thinkingBuffer: "", toolCalls: [] };
    this.isStreaming = true;

    try {
      this.#streamController = streamMessage({
        sessionId,
        content,
        onEvent: (event: StreamEvent) => this.#handleStreamEvent(event),
        onConnect: () => {
          this.error = null;
        },
        onDisconnect: () => {},
        onError: () => {
          this.error = "Stream connection failed";
          this.isStreaming = false;
        },
        onDone: () => this.#finalizeStream(),
      });
    } catch {
      this.isStreaming = false;
      this.error = "Failed to start stream";
    }
  }

  cancelGeneration(): void {
    if (!this.isStreaming) return;
    this.#streamController?.abort();
    this.#streamController = null;
    this.isStreaming = false;
    if (this.streaming.textBuffer || this.streaming.thinkingBuffer) {
      this.#finalizeStream();
    } else {
      this.pendingUserMessage = null;
      this.streaming = { textBuffer: "", thinkingBuffer: "", toolCalls: [] };
    }
  }

  // ── Private ───────────────────────────────────────────────────────────────

  #handleStreamEvent(event: StreamEvent): void {
    for (const fn of this.#streamListeners) fn(event);

    switch (event.type) {
      case "streaming_token":
        this.streaming = {
          ...this.streaming,
          textBuffer: this.streaming.textBuffer + event.delta,
        };
        break;

      case "thinking_delta":
        this.streaming = {
          ...this.streaming,
          thinkingBuffer: this.streaming.thinkingBuffer + event.delta,
        };
        break;

      case "tool_call":
        this.streaming = {
          ...this.streaming,
          toolCalls: [
            ...this.streaming.toolCalls,
            {
              id: event.tool_use_id,
              name: event.tool_name,
              input: event.input,
            },
          ],
        };
        break;

      case "tool_result":
        // tool_result events arrive after the tool runs — no UI mutation needed here
        // (the tool call is already in the list; full result is in the finalized message)
        break;

      case "error":
        this.error = event.message;
        this.isStreaming = false;
        if (this.pendingUserMessage) {
          this.messages = [...this.messages, this.pendingUserMessage];
          this.pendingUserMessage = null;
        }
        this.streaming = { textBuffer: "", thinkingBuffer: "", toolCalls: [] };
        break;
    }
  }

  #finalizeStream(): void {
    if (this.pendingUserMessage) {
      this.messages = [...this.messages, this.pendingUserMessage];
      this.pendingUserMessage = null;
    }

    if (this.streaming.textBuffer || this.streaming.toolCalls.length > 0) {
      const msg: Message = {
        id: `assistant-${Date.now()}`,
        session_id: this.currentSession?.id ?? "",
        role: "assistant",
        content: this.streaming.textBuffer,
        timestamp: new Date().toISOString(),
        tool_calls:
          this.streaming.toolCalls.length > 0
            ? [...this.streaming.toolCalls]
            : undefined,
        thinking: this.streaming.thinkingBuffer
          ? { type: "thinking", thinking: this.streaming.thinkingBuffer }
          : undefined,
      };
      this.messages = [...this.messages, msg];
    }

    this.streaming = { textBuffer: "", thinkingBuffer: "", toolCalls: [] };
    this.isStreaming = false;
    this.#streamController = null;
  }
}

export const chatStore = new ChatStore();
