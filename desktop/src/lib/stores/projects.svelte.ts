// src/lib/stores/projects.svelte.ts
import type { Project, ProjectStatus } from "$api/types";
import { projects as projectsApi } from "$api/client";
import { toastStore } from "./toasts.svelte";

class ProjectsStore {
  projects = $state<Project[]>([]);
  selected = $state<Project | null>(null);
  loading = $state(false);
  error = $state<string | null>(null);

  // Filters
  filterStatus = $state<ProjectStatus | "all">("all");
  searchQuery = $state("");

  // Derived
  filteredProjects = $derived.by(() => {
    let result = this.projects;
    if (this.filterStatus !== "all") {
      result = result.filter((p) => p.status === this.filterStatus);
    }
    if (this.searchQuery) {
      const q = this.searchQuery.toLowerCase();
      result = result.filter(
        (p) =>
          p.name.toLowerCase().includes(q) ||
          (p.description ?? "").toLowerCase().includes(q),
      );
    }
    return result;
  });

  activeCount = $derived(
    this.projects.filter((p) => p.status === "active").length,
  );
  totalCount = $derived(this.projects.length);

  async fetchProjects(workspaceId?: string): Promise<void> {
    this.loading = true;
    try {
      this.projects = await projectsApi.list(workspaceId);
      // Auto-select first active project if nothing selected
      if (!this.selected && this.projects.length > 0) {
        this.selected =
          this.projects.find((p) => p.status === "active") ?? this.projects[0];
      }
      this.error = null;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load projects", msg);
    } finally {
      this.loading = false;
    }
  }

  async fetchProject(id: string): Promise<Project | null> {
    this.loading = true;
    try {
      const project = await projectsApi.get(id);
      // Upsert into the local list
      const exists = this.projects.some((p) => p.id === id);
      if (exists) {
        this.projects = this.projects.map((p) => (p.id === id ? project : p));
      } else {
        this.projects = [project, ...this.projects];
      }
      this.error = null;
      return project;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load project", msg);
      return null;
    } finally {
      this.loading = false;
    }
  }

  async createProject(data: Partial<Project>): Promise<Project | null> {
    this.loading = true;
    try {
      const created = await projectsApi.create(data);
      this.projects = [created, ...this.projects];
      this.error = null;
      toastStore.success("Project created", created.name);
      return created;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to create project", msg);
      return null;
    } finally {
      this.loading = false;
    }
  }

  async updateProject(
    id: string,
    data: Partial<Project>,
  ): Promise<Project | null> {
    const previous = this.projects;
    this.projects = this.projects.map((p) =>
      p.id === id ? { ...p, ...data } : p,
    );
    if (this.selected?.id === id) {
      this.selected = { ...this.selected, ...data };
    }
    try {
      const updated = await projectsApi.update(id, data);
      this.projects = this.projects.map((p) => (p.id === id ? updated : p));
      if (this.selected?.id === id) {
        this.selected = updated;
      }
      this.error = null;
      return updated;
    } catch (e) {
      this.projects = previous;
      if (this.selected?.id === id) {
        this.selected = previous.find((p) => p.id === id) ?? this.selected;
      }
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to update project", msg);
      return null;
    }
  }

  selectProject(project: Project | null): void {
    this.selected = project;
  }

  selectById(id: string): void {
    const project = this.projects.find((p) => p.id === id) ?? null;
    this.selected = project;
  }
}

export const projectsStore = new ProjectsStore();
