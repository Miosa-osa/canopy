// src/lib/stores/secrets.svelte.ts
import type { Secret, SecretCreateRequest } from "$api/types";
import { secrets as secretsApi } from "$api/client";
import { toastStore } from "./toasts.svelte";

class SecretsStore {
  secrets = $state<Secret[]>([]);
  loading = $state(false);
  error = $state<string | null>(null);

  totalCount = $derived(this.secrets.length);
  expiringSoon = $derived(
    this.secrets.filter((s) => {
      if (!s.expires_at) return false;
      const daysUntilExpiry =
        (new Date(s.expires_at).getTime() - Date.now()) / (1000 * 60 * 60 * 24);
      return daysUntilExpiry >= 0 && daysUntilExpiry <= 30;
    }),
  );

  async fetchSecrets(workspaceId?: string): Promise<void> {
    this.loading = true;
    try {
      this.secrets = await secretsApi.list(workspaceId);
      this.error = null;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load secrets", msg);
    } finally {
      this.loading = false;
    }
  }

  async createSecret(data: SecretCreateRequest): Promise<Secret | null> {
    this.loading = true;
    try {
      const created = await secretsApi.create(data);
      this.secrets = [created, ...this.secrets];
      this.error = null;
      toastStore.success("Secret created", data.name);
      return created;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to create secret", msg);
      return null;
    } finally {
      this.loading = false;
    }
  }

  async deleteSecret(id: string): Promise<void> {
    const previous = this.secrets;
    this.secrets = this.secrets.filter((s) => s.id !== id);
    try {
      await secretsApi.delete(id);
      this.error = null;
      toastStore.success("Secret deleted");
    } catch (e) {
      this.secrets = previous;
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to delete secret", msg);
    }
  }

  async rotateSecret(id: string): Promise<Secret | null> {
    try {
      const rotated = await secretsApi.rotate(id);
      this.secrets = this.secrets.map((s) => (s.id === id ? rotated : s));
      this.error = null;
      toastStore.success("Secret rotated successfully");
      return rotated;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to rotate secret", msg);
      return null;
    }
  }

  getById(id: string): Secret | null {
    return this.secrets.find((s) => s.id === id) ?? null;
  }
}

export const secretsStore = new SecretsStore();
