// src/lib/stores/webhooks.svelte.ts
import type { Webhook } from "$api/types";
import { webhooks as webhooksApi } from "$api/client";
import { toastStore } from "./toasts.svelte";

class WebhooksStore {
  webhooks = $state<Webhook[]>([]);
  loading = $state(false);
  error = $state<string | null>(null);

  totalCount = $derived(this.webhooks.length);

  async fetchWebhooks(workspaceId?: string): Promise<void> {
    this.loading = true;
    try {
      this.webhooks = await webhooksApi.list(workspaceId);
      this.error = null;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load webhooks", msg);
    } finally {
      this.loading = false;
    }
  }

  async createWebhook(data: Partial<Webhook>): Promise<Webhook | null> {
    this.loading = true;
    try {
      const created = await webhooksApi.create(data);
      this.webhooks = [created, ...this.webhooks];
      this.error = null;
      toastStore.success("Webhook created");
      return created;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to create webhook", msg);
      return null;
    } finally {
      this.loading = false;
    }
  }

  async deleteWebhook(id: string): Promise<void> {
    const previous = this.webhooks;
    this.webhooks = this.webhooks.filter((w) => w.id !== id);
    try {
      await webhooksApi.delete(id);
      this.error = null;
      toastStore.success("Webhook deleted");
    } catch (e) {
      this.webhooks = previous;
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to delete webhook", msg);
    }
  }

  async updateWebhook(id: string, data: Partial<Webhook>): Promise<void> {
    const previous = this.webhooks;
    this.webhooks = this.webhooks.map((w) =>
      w.id === id ? { ...w, ...data } : w,
    );
    try {
      await webhooksApi.update(id, data);
      this.error = null;
      toastStore.success("Webhook updated");
    } catch (e) {
      this.webhooks = previous;
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to update webhook", msg);
    }
  }

  async testWebhook(id: string): Promise<void> {
    try {
      await webhooksApi.test(id);
      this.error = null;
      toastStore.success(
        "Webhook test sent",
        "Test payload delivered successfully.",
      );
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Webhook test failed", msg);
    }
  }
}

export const webhooksStore = new WebhooksStore();
