// src/lib/stores/alerts.svelte.ts
import type { AlertRule } from "$api/types";
import { alerts as alertsApi } from "$api/client";
import { toastStore } from "./toasts.svelte";

class AlertsStore {
  rules = $state<AlertRule[]>([]);
  loading = $state(false);
  error = $state<string | null>(null);

  totalCount = $derived(this.rules.length);
  enabledCount = $derived(this.rules.filter((r) => r.enabled).length);

  async fetchRules(workspaceId?: string): Promise<void> {
    this.loading = true;
    try {
      this.rules = await alertsApi.list(workspaceId);
      this.error = null;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load alert rules", msg);
    } finally {
      this.loading = false;
    }
  }

  async createRule(data: Partial<AlertRule>): Promise<AlertRule | null> {
    this.loading = true;
    try {
      const created = await alertsApi.create(data);
      this.rules = [created, ...this.rules];
      this.error = null;
      toastStore.success("Alert rule created");
      return created;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to create alert rule", msg);
      return null;
    } finally {
      this.loading = false;
    }
  }

  async updateRule(
    id: string,
    data: Partial<AlertRule>,
  ): Promise<AlertRule | null> {
    const previous = this.rules;
    this.rules = this.rules.map((r) => (r.id === id ? { ...r, ...data } : r));
    try {
      const updated = await alertsApi.update(id, data);
      this.rules = this.rules.map((r) => (r.id === id ? updated : r));
      this.error = null;
      toastStore.success("Alert rule updated");
      return updated;
    } catch (e) {
      this.rules = previous;
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to update alert rule", msg);
      return null;
    }
  }

  async deleteRule(id: string): Promise<void> {
    const previous = this.rules;
    this.rules = this.rules.filter((r) => r.id !== id);
    try {
      await alertsApi.delete(id);
      this.error = null;
      toastStore.success("Alert rule deleted");
    } catch (e) {
      this.rules = previous;
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to delete alert rule", msg);
    }
  }
}

export const alertsStore = new AlertsStore();
