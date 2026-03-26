// src/lib/stores/integrations.svelte.ts
import type { Integration } from "$api/types";
import { integrations as integrationsApi } from "$api/client";
import { toastStore } from "./toasts.svelte";

class IntegrationsStore {
  integrations = $state<Integration[]>([]);
  loading = $state(false);
  error = $state<string | null>(null);

  totalCount = $derived(this.integrations.length);
  connectedCount = $derived(
    this.integrations.filter((i) => {
      const raw = i as unknown as Record<string, unknown>;
      if (raw.connected === true) return true;
      return i.status === "connected";
    }).length,
  );

  async fetchIntegrations(workspaceId?: string): Promise<void> {
    this.loading = true;
    try {
      this.integrations = await integrationsApi.list(workspaceId);
      this.error = null;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load integrations", msg);
    } finally {
      this.loading = false;
    }
  }

  async connect(slug: string, config?: Record<string, unknown>): Promise<void> {
    this.loading = true;
    try {
      await integrationsApi.connect(slug, config);
      await this.fetchIntegrations();
      this.error = null;
      toastStore.success("Integration connected", slug);
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to connect integration", msg);
    } finally {
      this.loading = false;
    }
  }

  async disconnect(slug: string): Promise<void> {
    this.loading = true;
    try {
      await integrationsApi.disconnect(slug);
      await this.fetchIntegrations();
      this.error = null;
      toastStore.success("Integration disconnected", slug);
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to disconnect integration", msg);
    } finally {
      this.loading = false;
    }
  }
}

export const integrationsStore = new IntegrationsStore();
