// src/lib/stores/connection.svelte.ts
import { health, isMockEnabled } from "$api/client";
import type { HealthResponse } from "$api/types";

export type ConnectionStatus =
  | "connecting"
  | "connected"
  | "reconnecting"
  | "disconnected"
  | "mock";

class ConnectionStore {
  status = $state<ConnectionStatus>("connecting");
  lastChecked = $state<Date | null>(null);
  lastConnectedAt = $state<Date | null>(null);
  error = $state<string | null>(null);
  health = $state<HealthResponse | null>(null);
  isChecking = $state(false);
  reconnectAttempts = $state(0);
  offlineQueueSize = $state(0);

  #pollInterval: ReturnType<typeof setInterval> | null = null;
  #reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  #pollMs: number = 30_000;
  #maxReconnectAttempts = 5;

  get isConnected(): boolean {
    return this.status === "connected" || this.status === "mock";
  }

  get isReady(): boolean {
    return this.status === "connected" || this.status === "mock";
  }

  async check(): Promise<void> {
    if (this.isChecking) return;
    this.isChecking = true;
    const prevStatus = this.status;
    try {
      const data = await health.get();
      this.health = data;
      if (isMockEnabled()) {
        if (this.status !== "mock") this.status = "mock";
      } else {
        if (this.status !== "connected") {
          this.lastConnectedAt = new Date();
          if (prevStatus === "reconnecting") {
            this.reconnectAttempts = 0;
            await this.#syncOnReconnect();
          }
        }
        this.status = "connected";
      }
      this.error = null;
    } catch (e) {
      if (isMockEnabled()) {
        if (this.status !== "mock") this.status = "mock";
        this.error = null;
      } else {
        this.health = null;
        if (prevStatus === "connected") this.#startReconnecting();
        else if (this.status !== "reconnecting") this.status = "disconnected";
        this.error = (e as Error).message;
      }
    } finally {
      this.isChecking = false;
      this.lastChecked = new Date();
    }
  }

  startPolling(intervalMs: number = this.#pollMs): () => void {
    this.#pollMs = intervalMs;
    // Do one initial check, then poll at a relaxed interval
    void this.check();
    this.#pollInterval = setInterval(() => void this.check(), intervalMs);
    return () => this.stopPolling();
  }

  stopPolling(): void {
    if (this.#pollInterval !== null) {
      clearInterval(this.#pollInterval);
      this.#pollInterval = null;
    }
    if (this.#reconnectTimer !== null) {
      clearTimeout(this.#reconnectTimer);
      this.#reconnectTimer = null;
    }
  }

  updateQueueSize(size: number): void {
    this.offlineQueueSize = size;
  }

  #startReconnecting(): void {
    if (this.status === "reconnecting") return;
    this.status = "reconnecting";
    this.reconnectAttempts = 0;
    void this.#attemptReconnect();
  }

  async #attemptReconnect(): Promise<void> {
    if (this.status !== "reconnecting") return;
    this.reconnectAttempts++;
    try {
      const data = await health.get();
      this.health = data;
      this.status = "connected";
      this.error = null;
      this.lastChecked = new Date();
      this.lastConnectedAt = new Date();
      this.reconnectAttempts = 0;
      await this.#syncOnReconnect();
      if (this.#pollInterval === null) this.startPolling(this.#pollMs);
      return;
    } catch {
      /* still offline */
    }
    if (this.reconnectAttempts >= this.#maxReconnectAttempts) {
      this.status = "disconnected";
      this.error = "Max reconnection attempts reached";
      return;
    }
    const delay = Math.min(2000 * 2 ** (this.reconnectAttempts - 1), 30_000);
    this.#reconnectTimer = setTimeout(
      () => void this.#attemptReconnect(),
      delay,
    );
  }

  async #syncOnReconnect(): Promise<void> {
    const { flushOfflineQueue, clearCache, disableMock } =
      await import("$api/client");
    // disableMock() is now async — it notifies the mock module and purges
    // all mock localStorage keys before any live requests are made.
    await disableMock();
    clearCache();
    const result = await flushOfflineQueue();
    this.offlineQueueSize = 0;
    if (result.failed > 0) {
      this.error = `${result.failed} queued requests failed to sync`;
    }
  }
}

export const connectionStore = new ConnectionStore();
