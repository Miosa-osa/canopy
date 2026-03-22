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
      if (i.status === "connected") return true;
      if ("connected" in i && (i as Record<string, unknown>).connected === true)
        return true;
      return false;
    }).length,
  );

  async fetchIntegrations(): Promise<void> {
    this.loading = true;
    try {
      this.integrations = await integrationsApi.list();
      this.error = null;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load integrations", msg);
    } finally {
      this.loading = false;
    }
  }
}

export const integrationsStore = new IntegrationsStore();
