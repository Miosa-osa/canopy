// src/lib/stores/goals.svelte.ts
import type { Goal, GoalTreeNode, GoalStatus, GoalPriority } from "$api/types";
import { goals as goalsApi } from "$api/client";
import { toastStore } from "./toasts.svelte";

class GoalsStore {
  goals = $state<GoalTreeNode[]>([]);
  selected = $state<GoalTreeNode | null>(null);
  loading = $state(false);
  error = $state<string | null>(null);

  // Active project context
  activeProjectId = $state<string | null>(null);

  // Filters
  filterStatus = $state<GoalStatus | "all">("all");
  filterPriority = $state<GoalPriority | "all">("all");
  searchQuery = $state("");

  // Derived: flat list from tree
  flatGoals = $derived.by(() => {
    const flatten = (nodes: GoalTreeNode[]): GoalTreeNode[] =>
      nodes.flatMap((n) => [n, ...flatten(n.children)]);
    return flatten(this.goals);
  });

  // Derived: filtered flat list
  filteredGoals = $derived.by(() => {
    let result = this.flatGoals;
    if (this.filterStatus !== "all") {
      result = result.filter((g) => g.status === this.filterStatus);
    }
    if (this.filterPriority !== "all") {
      result = result.filter((g) => g.priority === this.filterPriority);
    }
    if (this.searchQuery) {
      const q = this.searchQuery.toLowerCase();
      result = result.filter(
        (g) =>
          g.title.toLowerCase().includes(q) ||
          (g.description ?? "").toLowerCase().includes(q),
      );
    }
    return result;
  });

  // Derived: aggregate progress across all root goals
  overallProgress = $derived.by(() => {
    const roots = this.goals;
    if (roots.length === 0) return 0;
    const total = roots.reduce((sum, g) => sum + g.progress, 0);
    return Math.round(total / roots.length);
  });

  completedCount = $derived(
    this.flatGoals.filter((g) => g.status === "completed").length,
  );
  totalCount = $derived(this.flatGoals.length);

  async fetchGoals(projectId: string): Promise<void> {
    this.loading = true;
    this.activeProjectId = projectId;
    try {
      this.goals = await goalsApi.list(projectId);
      this.error = null;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load goals", msg);
    } finally {
      this.loading = false;
    }
  }

  async createGoal(data: Partial<Goal>): Promise<Goal | null> {
    if (!this.activeProjectId) {
      toastStore.error(
        "No active project",
        "Select a project before creating goals.",
      );
      return null;
    }
    this.loading = true;
    try {
      const created = await goalsApi.create(this.activeProjectId, data);
      // Re-fetch the full tree to get correct children/issue_count
      await this.fetchGoals(this.activeProjectId);
      this.error = null;
      toastStore.success("Goal created", created.title);
      return created;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to create goal", msg);
      return null;
    } finally {
      this.loading = false;
    }
  }

  async updateGoal(id: string, data: Partial<Goal>): Promise<Goal | null> {
    if (!this.activeProjectId) {
      toastStore.error("No active project");
      return null;
    }
    // Optimistic update on flat data embedded in tree nodes
    const applyUpdate = (nodes: GoalTreeNode[]): GoalTreeNode[] =>
      nodes.map((n) =>
        n.id === id
          ? { ...n, ...data, children: applyUpdate(n.children) }
          : { ...n, children: applyUpdate(n.children) },
      );
    const previousGoals = this.goals;
    this.goals = applyUpdate(this.goals);
    if (this.selected?.id === id) {
      this.selected = { ...this.selected, ...data };
    }
    try {
      const updated = await goalsApi.update(this.activeProjectId, id, data);
      // Re-fetch to sync computed fields (progress, issue_count, children)
      await this.fetchGoals(this.activeProjectId);
      if (this.selected?.id === id) {
        const refreshed = this.flatGoals.find((g) => g.id === id);
        this.selected = refreshed ?? null;
      }
      this.error = null;
      return updated;
    } catch (e) {
      this.goals = previousGoals;
      if (this.selected?.id === id) {
        const prev = previousGoals
          .flatMap((n) => [n, ...n.children])
          .find((g) => g.id === id);
        this.selected = prev ?? this.selected;
      }
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to update goal", msg);
      return null;
    }
  }

  async decompose(
    goalId: string,
    opts?: { max_issues?: number; auto_assign?: boolean },
  ): Promise<{ issues: import("$api/types").Issue[]; count: number } | null> {
    try {
      const result = await goalsApi.decompose(goalId, opts);
      // Re-fetch the full tree so issue_count is updated on the affected node
      if (this.activeProjectId) {
        await this.fetchGoals(this.activeProjectId);
      }
      toastStore.success(
        "Goal decomposed",
        `${result.count} issue${result.count === 1 ? "" : "s"} created`,
      );
      return result;
    } catch (e) {
      const msg = (e as Error).message;
      toastStore.error("Failed to decompose goal", msg);
      return null;
    }
  }

  selectGoal(goal: GoalTreeNode | null): void {
    this.selected = goal;
  }

  setActiveProject(projectId: string): void {
    this.activeProjectId = projectId;
    this.goals = [];
    this.selected = null;
  }
}

export const goalsStore = new GoalsStore();
