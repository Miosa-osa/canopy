// src/lib/stores/signals.svelte.ts
import type { Signal, SignalPattern, SignalStats } from "$api/types";
import { signals as signalsApi } from "$api/client";
import { toastStore } from "./toasts.svelte";

class SignalsStore {
  signals = $state<Signal[]>([]);
  patterns = $state<SignalPattern[]>([]);
  stats = $state<SignalStats | null>(null);
  loading = $state(false);
  patternsLoading = $state(false);
  statsLoading = $state(false);
  error = $state<string | null>(null);
  searchQuery = $state("");
  filterChannel = $state<string | "all">("all");
  filterMode = $state<string | "all">("all");

  // Derived
  filteredSignals = $derived.by(() => {
    let result = this.signals;
    if (this.filterChannel !== "all") {
      result = result.filter((s) => s.channel === this.filterChannel);
    }
    if (this.filterMode !== "all") {
      result = result.filter((s) => s.mode === this.filterMode);
    }
    if (this.searchQuery) {
      const q = this.searchQuery.toLowerCase();
      result = result.filter(
        (s) =>
          s.id.toLowerCase().includes(q) ||
          s.channel.toLowerCase().includes(q) ||
          s.agent_name.toLowerCase().includes(q) ||
          s.input_preview.toLowerCase().includes(q),
      );
    }
    return result;
  });

  totalCount = $derived(this.signals.length);

  async fetchSignals(limit = 100): Promise<void> {
    this.loading = true;
    try {
      this.signals = await signalsApi.list(limit);
      this.error = null;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load signals", msg);
    } finally {
      this.loading = false;
    }
  }

  async fetchPatterns(): Promise<void> {
    this.patternsLoading = true;
    try {
      this.patterns = await signalsApi.patterns();
    } catch (e) {
      toastStore.error("Failed to load signal patterns", (e as Error).message);
    } finally {
      this.patternsLoading = false;
    }
  }

  async fetchStats(): Promise<void> {
    this.statsLoading = true;
    try {
      this.stats = await signalsApi.stats();
    } catch (e) {
      toastStore.error("Failed to load signal stats", (e as Error).message);
    } finally {
      this.statsLoading = false;
    }
  }

  async fetchAll(limit = 100): Promise<void> {
    await Promise.all([
      this.fetchSignals(limit),
      this.fetchPatterns(),
      this.fetchStats(),
    ]);
  }

  setSearch(q: string): void {
    this.searchQuery = q;
  }

  setChannelFilter(channel: string | "all"): void {
    this.filterChannel = channel;
  }

  setModeFilter(mode: string | "all"): void {
    this.filterMode = mode;
  }
}

export const signalsStore = new SignalsStore();
