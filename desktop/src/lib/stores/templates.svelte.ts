// src/lib/stores/templates.svelte.ts
import type { AgentTemplate } from "$api/types";
import { templates as templatesApi } from "$api/client";
import { toastStore } from "./toasts.svelte";

class TemplatesStore {
  templates = $state<AgentTemplate[]>([]);
  selected = $state<AgentTemplate | null>(null);
  loading = $state(false);
  error = $state<string | null>(null);

  // Filter state
  searchQuery = $state("");
  filterCategory = $state<string | "all">("all");

  // Derived
  totalCount = $derived(this.templates.length);

  filteredTemplates = $derived.by(() => {
    let result = this.templates;
    if (this.filterCategory !== "all") {
      result = result.filter((t) => t.category === this.filterCategory);
    }
    if (this.searchQuery) {
      const q = this.searchQuery.toLowerCase();
      result = result.filter(
        (t) =>
          t.name.toLowerCase().includes(q) ||
          t.description.toLowerCase().includes(q),
      );
    }
    return result;
  });

  categories = $derived(
    [...new Set(this.templates.map((t) => t.category))].sort(),
  );

  async fetchTemplates(workspaceId?: string): Promise<void> {
    this.loading = true;
    try {
      this.templates = await templatesApi.list(workspaceId);
      this.error = null;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load templates", msg);
    } finally {
      this.loading = false;
    }
  }

  async createTemplate(
    data: Partial<AgentTemplate>,
  ): Promise<AgentTemplate | null> {
    this.loading = true;
    try {
      const created = await templatesApi.create(data);
      this.templates = [created, ...this.templates];
      this.error = null;
      toastStore.success("Template created", data.name ?? "");
      return created;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to create template", msg);
      return null;
    } finally {
      this.loading = false;
    }
  }

  selectTemplate(template: AgentTemplate | null): void {
    this.selected = template;
  }

  setSearch(q: string): void {
    this.searchQuery = q;
  }

  setCategoryFilter(category: string | "all"): void {
    this.filterCategory = category;
  }

  getById(id: string): AgentTemplate | null {
    return this.templates.find((t) => t.id === id) ?? null;
  }
}

export const templatesStore = new TemplatesStore();
