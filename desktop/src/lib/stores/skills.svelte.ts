// src/lib/stores/skills.svelte.ts
import type { Skill } from "$api/types";
import { skills as skillsApi } from "$api/client";
import { toastStore } from "./toasts.svelte";

class SkillsStore {
  skills = $state<Skill[]>([]);
  loading = $state(false);
  error = $state<string | null>(null);

  searchQuery = $state("");

  // Derived
  enabledCount = $derived(this.skills.filter((s) => s.enabled).length);
  totalCount = $derived(this.skills.length);

  filteredSkills = $derived.by(() => {
    const q = this.searchQuery.toLowerCase().trim();
    const filtered = q
      ? this.skills.filter((s) => s.name.toLowerCase().includes(q))
      : this.skills;
    return [...filtered].sort((a, b) => a.name.localeCompare(b.name));
  });

  async fetchSkills(workspaceId?: string): Promise<void> {
    this.loading = true;
    try {
      this.skills = await skillsApi.list(workspaceId);
      this.error = null;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load skills", msg);
    } finally {
      this.loading = false;
    }
  }

  async toggleSkill(id: string): Promise<void> {
    const previous = this.skills;
    // Optimistic update
    this.skills = this.skills.map((s) =>
      s.id === id ? { ...s, enabled: !s.enabled } : s,
    );
    try {
      const updated = await skillsApi.toggle(id);
      this.skills = this.skills.map((s) => (s.id === id ? updated : s));
      this.error = null;
    } catch (e) {
      this.skills = previous;
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to toggle skill", msg);
    }
  }
}

export const skillsStore = new SkillsStore();
