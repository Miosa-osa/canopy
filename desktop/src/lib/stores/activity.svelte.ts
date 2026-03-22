// src/lib/stores/activity.svelte.ts
import type { ActivityEvent, ActivityEventType } from "$api/types";
import { activity as activityApi } from "$api/client";
import { subscribeToActivityStream } from "$api/sse";
import { toastStore } from "./toasts.svelte";

const MAX_EVENTS = 500;

class ActivityStore {
  events = $state<ActivityEvent[]>([]);
  loading = $state(false);
  error = $state<string | null>(null);
  connected = $state(false);

  // Filters
  filterType = $state<ActivityEventType | "all">("all");
  filterLevel = $state<"info" | "warning" | "error" | "success" | "all">("all");
  filterAgentId = $state<string | "all">("all");
  searchQuery = $state("");

  // Derived
  filteredEvents = $derived.by(() => {
    let result = this.events;
    if (this.filterType !== "all") {
      result = result.filter((e) => e.type === this.filterType);
    }
    if (this.filterLevel !== "all") {
      result = result.filter((e) => e.level === this.filterLevel);
    }
    if (this.filterAgentId !== "all") {
      result = result.filter((e) => e.agent_id === this.filterAgentId);
    }
    if (this.searchQuery) {
      const q = this.searchQuery.toLowerCase();
      result = result.filter(
        (e) =>
          e.title.toLowerCase().includes(q) ||
          (e.detail ?? "").toLowerCase().includes(q) ||
          (e.agent_name ?? "").toLowerCase().includes(q),
      );
    }
    return result;
  });

  errorCount = $derived(this.events.filter((e) => e.level === "error").length);
  warningCount = $derived(
    this.events.filter((e) => e.level === "warning").length,
  );

  // SSE abort controller
  #sseAbortController: AbortController | null = null;

  async fetchRecent(limit = 100): Promise<void> {
    this.loading = true;
    try {
      const recent = await activityApi.list(limit);
      // Merge: place fetched events as baseline, deduplicating by id
      const existingIds = new Set(this.events.map((e) => e.id));
      const newEvents = recent.filter((e) => !existingIds.has(e.id));
      this.events = this.#trimToMax([...newEvents, ...this.events]);
      this.error = null;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load activity", msg);
    } finally {
      this.loading = false;
    }
  }

  subscribe(): void {
    if (this.#sseAbortController) return; // already connected

    const controller = new AbortController();
    this.#sseAbortController = controller;

    subscribeToActivityStream(
      {
        onConnect: () => {
          this.connected = true;
          this.error = null;
        },
        onDisconnect: () => {
          this.connected = false;
        },
        onEvent: (event) => {
          // Backend sends raw event objects with {event: "event.type", ...metadata}
          // Convert to ActivityEvent shape for the store
          const raw = event as unknown as Record<string, unknown>;
          if (raw.event && typeof raw.event === "string") {
            const activityEvent: ActivityEvent = {
              id: (raw.id as string) || crypto.randomUUID(),
              type: raw.event as ActivityEventType,
              agent_id: (raw.agent_id as string) || null,
              agent_name: (raw.agent_name as string) || null,
              title: (raw.event as string).replace(/\./g, " "),
              detail: (raw.message as string) || null,
              level:
                (raw.level as "info" | "warning" | "error" | "success") ||
                "info",
              metadata: raw,
              created_at: new Date().toISOString(),
            };
            this.#prependEvent(activityEvent);
          }
        },
        onError: (err) => {
          this.connected = false;
          this.error = err.message;
        },
      },
      controller.signal,
    );
  }

  unsubscribe(): void {
    if (this.#sseAbortController) {
      this.#sseAbortController.abort();
      this.#sseAbortController = null;
    }
    this.connected = false;
  }

  #prependEvent(event: ActivityEvent): void {
    // Deduplicate by id
    if (this.events.some((e) => e.id === event.id)) return;
    this.events = this.#trimToMax([event, ...this.events]);
  }

  #trimToMax(events: ActivityEvent[]): ActivityEvent[] {
    if (events.length > MAX_EVENTS) {
      return events.slice(0, MAX_EVENTS);
    }
    return events;
  }

  clearFilters(): void {
    this.filterType = "all";
    this.filterLevel = "all";
    this.filterAgentId = "all";
    this.searchQuery = "";
  }
}

export const activityStore = new ActivityStore();
