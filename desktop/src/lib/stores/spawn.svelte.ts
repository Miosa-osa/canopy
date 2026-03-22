// src/lib/stores/spawn.svelte.ts
import type { SpawnInstance } from "$api/types";
import { spawn as spawnApi } from "$api/client";
import { toastStore } from "./toasts.svelte";

interface SpawnCreateRequest {
  agent_id: string;
  task: string;
  model?: string;
}

class SpawnStore {
  instances = $state<SpawnInstance[]>([]);
  loading = $state(false);
  error = $state<string | null>(null);

  // Derived
  activeInstances = $derived(
    this.instances.filter((i) => i.status === "running"),
  );

  completedInstances = $derived(
    [...this.instances]
      .filter((i) => i.status === "completed" || i.status === "failed")
      .sort((a, b) => {
        const timeA = a.completed_at
          ? new Date(a.completed_at).getTime()
          : new Date(a.started_at).getTime();
        const timeB = b.completed_at
          ? new Date(b.completed_at).getTime()
          : new Date(b.started_at).getTime();
        return timeB - timeA;
      }),
  );

  activeCount = $derived(this.activeInstances.length);
  totalCostCents = $derived(
    this.instances.reduce((sum, i) => sum + (i.cost_cents ?? 0), 0),
  );

  async fetchInstances(): Promise<void> {
    this.loading = true;
    try {
      this.instances = await spawnApi.list();
      this.error = null;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load spawn instances", msg);
    } finally {
      this.loading = false;
    }
  }

  async createSpawn(data: SpawnCreateRequest): Promise<SpawnInstance | null> {
    this.loading = true;
    try {
      const created = await spawnApi.create(data);
      this.instances = [created, ...this.instances];
      this.error = null;
      toastStore.success(
        "Spawn started",
        `Agent task dispatched successfully.`,
      );
      return created;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to spawn agent", msg);
      return null;
    } finally {
      this.loading = false;
    }
  }

  // Sync a single instance with fresh data from the full list (no per-ID endpoint)
  updateInstance(updated: SpawnInstance): void {
    this.instances = this.instances.map((i) =>
      i.id === updated.id ? updated : i,
    );
  }

  // Poll active instances and refresh their status from the full list
  async refreshActive(): Promise<void> {
    if (this.activeInstances.length === 0) return;
    try {
      const fresh = await spawnApi.list();
      // Merge fresh data — preserve ordering of existing instances
      const freshMap = new Map(fresh.map((i) => [i.id, i]));
      const merged = this.instances.map((i) => freshMap.get(i.id) ?? i);
      // Collect truly new instances not yet in our list (snapshot existingIds
      // before any mutation to avoid checking against partially-updated state)
      const existingIds = new Set(this.instances.map((i) => i.id));
      const newInstances = fresh.filter((f) => !existingIds.has(f.id));
      this.instances = [...newInstances, ...merged];
      this.error = null;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
    }
  }

  #pollTimer: ReturnType<typeof setInterval> | null = null;

  startPolling(intervalMs = 5_000): () => void {
    void this.fetchInstances();
    this.#pollTimer = setInterval(() => void this.refreshActive(), intervalMs);
    return () => this.stopPolling();
  }

  async cancelSpawn(id: string): Promise<void> {
    const previous = this.instances;
    this.instances = this.instances.filter((i) => i.id !== id);
    try {
      await spawnApi.kill(id);
      this.error = null;
      toastStore.success("Spawn cancelled");
    } catch (e) {
      this.instances = previous;
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to cancel spawn", msg);
    }
  }

  stopPolling(): void {
    if (this.#pollTimer !== null) {
      clearInterval(this.#pollTimer);
      this.#pollTimer = null;
    }
  }
}

export const spawnStore = new SpawnStore();
