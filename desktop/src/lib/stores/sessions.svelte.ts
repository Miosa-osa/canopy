// src/lib/stores/sessions.svelte.ts
// Observability store for session list, detail, and live transcript streaming

import type { Session, Message, ActivityEvent } from "$api/types";
import { sessions as sessionsApi, messages as messagesApi } from "$api/client";
import { connectSSE, type StreamController } from "$api/sse";
import { toastStore } from "./toasts.svelte";

export type SessionSortKey = "date" | "duration" | "cost" | "tokens";
export type SessionStatusFilter =
  | "all"
  | "active"
  | "completed"
  | "failed"
  | "cancelled";

export interface SessionFilters {
  agentId: string | null;
  status: SessionStatusFilter;
  search: string;
  sort: SessionSortKey;
  sortDir: "asc" | "desc";
}

class SessionsStore {
  // ── List state ─────────────────────────────────────────────────────────────
  sessions = $state<Session[]>([]);
  loading = $state(false);
  error = $state<string | null>(null);

  // ── Pagination ─────────────────────────────────────────────────────────────
  page = $state(1);
  pageSize = $state(25);

  // ── Filters ────────────────────────────────────────────────────────────────
  filters = $state<SessionFilters>({
    agentId: null,
    status: "all",
    search: "",
    sort: "date",
    sortDir: "desc",
  });

  // ── Detail state ───────────────────────────────────────────────────────────
  selectedSession = $state<Session | null>(null);
  transcript = $state<Message[]>([]);
  transcriptLoading = $state(false);

  // ── Live streaming for active sessions ─────────────────────────────────────
  isLive = $state(false);
  #transcriptStream: StreamController | null = null;

  // ── Derived ────────────────────────────────────────────────────────────────
  filteredSessions = $derived.by(() => {
    let result = this.sessions;

    if (this.filters.agentId) {
      result = result.filter((s) => s.agent_id === this.filters.agentId);
    }

    if (this.filters.status !== "all") {
      result = result.filter((s) => s.status === this.filters.status);
    }

    if (this.filters.search.trim()) {
      const q = this.filters.search.toLowerCase();
      result = result.filter(
        (s) =>
          (s.title ?? "").toLowerCase().includes(q) ||
          s.agent_name.toLowerCase().includes(q) ||
          s.id.toLowerCase().includes(q),
      );
    }

    result = [...result].sort((a, b) => {
      let cmp = 0;
      switch (this.filters.sort) {
        case "date":
          cmp =
            new Date(a.started_at).getTime() - new Date(b.started_at).getTime();
          break;
        case "duration": {
          const durationA = a.completed_at
            ? new Date(a.completed_at).getTime() -
              new Date(a.started_at).getTime()
            : Date.now() - new Date(a.started_at).getTime();
          const durationB = b.completed_at
            ? new Date(b.completed_at).getTime() -
              new Date(b.started_at).getTime()
            : Date.now() - new Date(b.started_at).getTime();
          cmp = durationA - durationB;
          break;
        }
        case "cost":
          cmp = a.cost_cents - b.cost_cents;
          break;
        case "tokens":
          cmp =
            a.token_usage.input +
            a.token_usage.output -
            (b.token_usage.input + b.token_usage.output);
          break;
      }
      return this.filters.sortDir === "asc" ? cmp : -cmp;
    });

    return result;
  });

  pagedSessions = $derived(
    this.filteredSessions.slice(
      (this.page - 1) * this.pageSize,
      this.page * this.pageSize,
    ),
  );

  totalPages = $derived(
    Math.max(1, Math.ceil(this.filteredSessions.length / this.pageSize)),
  );

  activeSessions = $derived(this.sessions.filter((s) => s.status === "active"));
  activeCount = $derived(this.activeSessions.length);
  totalCount = $derived(this.sessions.length);

  // Unique agent names for filter dropdown
  agentOptions = $derived.by(() => {
    const seen = new Map<string, string>();
    for (const s of this.sessions) {
      if (!seen.has(s.agent_id)) seen.set(s.agent_id, s.agent_name);
    }
    return Array.from(seen.entries()).map(([id, name]) => ({ id, name }));
  });

  // ── List operations ────────────────────────────────────────────────────────

  async fetch(workspaceId?: string): Promise<void> {
    this.loading = true;
    this.error = null;
    try {
      this.sessions = await sessionsApi.list(workspaceId);
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load sessions", msg);
    } finally {
      this.loading = false;
    }
  }

  async fetchById(id: string): Promise<Session | null> {
    try {
      const session = await sessionsApi.get(id);
      this.selectedSession = session;
      // Sync into the list if present
      const idx = this.sessions.findIndex((s) => s.id === id);
      if (idx >= 0) {
        this.sessions = this.sessions.map((s) => (s.id === id ? session : s));
      }
      return session;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load session", msg);
      return null;
    }
  }

  async fetchTranscript(id: string): Promise<void> {
    this.transcriptLoading = true;
    this.stopLiveStream();
    try {
      this.transcript = await messagesApi.list(id);
      this.error = null;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load transcript", msg);
    } finally {
      this.transcriptLoading = false;
    }
  }

  // ── SSE live transcript ────────────────────────────────────────────────────

  startLiveStream(sessionId: string): void {
    this.stopLiveStream();
    this.isLive = true;
    this.#transcriptStream = connectSSE(`/sessions/${sessionId}/stream`, {
      onEvent: (event) => {
        // Append live token deltas and tool calls as synthetic messages
        if (event.type === "streaming_token") {
          const last = this.transcript[this.transcript.length - 1];
          if (last?.role === "assistant" && last.id.startsWith("live-")) {
            this.transcript = [
              ...this.transcript.slice(0, -1),
              { ...last, content: last.content + event.delta },
            ];
          } else {
            this.transcript = [
              ...this.transcript,
              {
                id: `live-${Date.now()}`,
                session_id: sessionId,
                role: "assistant",
                content: event.delta,
                timestamp: new Date().toISOString(),
              },
            ];
          }
        }
      },
      onDone: () => {
        this.isLive = false;
        // Refresh the transcript with final persisted messages
        void this.fetchTranscript(sessionId);
      },
      onError: () => {
        this.isLive = false;
      },
    });
  }

  stopLiveStream(): void {
    this.#transcriptStream?.abort();
    this.#transcriptStream = null;
    this.isLive = false;
  }

  // ── Filter helpers ─────────────────────────────────────────────────────────

  setSearch(q: string): void {
    this.filters = { ...this.filters, search: q };
    this.page = 1;
  }

  setAgentFilter(agentId: string | null): void {
    this.filters = { ...this.filters, agentId };
    this.page = 1;
  }

  setStatusFilter(status: SessionStatusFilter): void {
    this.filters = { ...this.filters, status };
    this.page = 1;
  }

  setSort(sort: SessionSortKey, dir?: "asc" | "desc"): void {
    const sortDir =
      dir ??
      (this.filters.sort === sort && this.filters.sortDir === "desc"
        ? "asc"
        : "desc");
    this.filters = { ...this.filters, sort, sortDir };
  }

  resetFilters(): void {
    this.filters = {
      agentId: null,
      status: "all",
      search: "",
      sort: "date",
      sortDir: "desc",
    };
    this.page = 1;
  }

  setPage(p: number): void {
    this.page = Math.max(1, Math.min(p, this.totalPages));
  }

  selectSession(session: Session | null): void {
    this.selectedSession = session;
    if (!session) {
      this.transcript = [];
      this.stopLiveStream();
    }
  }

  // ── Live activity event handling ────────────────────────────────────────────
  // Called from the app layout whenever the activity store emits an event.
  // Keeps the session list in sync during live agent execution without
  // requiring a full refetch.

  handleActivityEvent(event: ActivityEvent): void {
    const meta = event.metadata as Record<string, unknown>;
    const sessionId =
      typeof meta.session_id === "string" ? meta.session_id : null;

    if (event.type === "session_started") {
      if (!sessionId) return;
      // Add a new active session entry if we don't already have it
      const exists = this.sessions.some((s) => s.id === sessionId);
      if (!exists) {
        const newSession: Session = {
          id: sessionId,
          agent_id: event.agent_id ?? "",
          agent_name: event.agent_name ?? "",
          title: typeof meta.title === "string" ? meta.title : null,
          status: "active",
          message_count: 0,
          token_usage: { input: 0, output: 0, cache_read: 0, cache_write: 0 },
          cost_cents: 0,
          started_at: event.created_at,
          completed_at: null,
          created_at: event.created_at,
        };
        this.sessions = [newSession, ...this.sessions];
      } else {
        // Already in list — just mark as active
        this.sessions = this.sessions.map((s) =>
          s.id === sessionId ? { ...s, status: "active" as const } : s,
        );
      }
      return;
    }

    if (
      event.type === "session_completed" ||
      event.type === "heartbeat_completed" ||
      event.type === "heartbeat_failed"
    ) {
      if (!sessionId) return;
      const finalStatus: Session["status"] =
        event.type === "session_completed" ||
        event.type === "heartbeat_completed"
          ? "completed"
          : "failed";
      this.sessions = this.sessions.map((s) =>
        s.id === sessionId
          ? {
              ...s,
              status: finalStatus,
              completed_at:
                typeof meta.completed_at === "string"
                  ? meta.completed_at
                  : new Date().toISOString(),
            }
          : s,
      );
      // Sync detail view if this is the currently selected session
      if (this.selectedSession?.id === sessionId) {
        this.selectedSession = {
          ...this.selectedSession,
          status: finalStatus,
          completed_at:
            typeof meta.completed_at === "string"
              ? meta.completed_at
              : new Date().toISOString(),
        };
      }
    }
  }
}

export const sessionsStore = new SessionsStore();
