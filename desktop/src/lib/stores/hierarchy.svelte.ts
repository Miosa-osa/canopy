// src/lib/stores/hierarchy.svelte.ts
import {
  divisions as divisionsApi,
  departments as departmentsApi,
  teams as teamsApi,
  hierarchy as hierarchyApi,
} from "$api/client";
import type { Division, Department, Team, HierarchyTree } from "$api/types";
import { toastStore } from "./toasts.svelte";

class HierarchyStore {
  // ── State ────────────────────────────────────────────────────────────────────
  divisions = $state<Division[]>([]);
  departments = $state<Department[]>([]);
  teams = $state<Team[]>([]);
  tree = $state<HierarchyTree | null>(null);

  selectedDivision = $state<Division | null>(null);
  selectedDepartment = $state<Department | null>(null);
  selectedTeam = $state<Team | null>(null);

  loading = $state(false);
  error = $state<string | null>(null);

  // ── Derived ──────────────────────────────────────────────────────────────────
  divisionCount = $derived(this.divisions.length);
  departmentCount = $derived(this.departments.length);
  teamCount = $derived(this.teams.length);

  // ── Fetch ────────────────────────────────────────────────────────────────────

  async fetchDivisions(organizationId?: string): Promise<void> {
    this.loading = true;
    try {
      this.divisions = await divisionsApi.list(organizationId);
      this.error = null;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load divisions", msg);
    } finally {
      this.loading = false;
    }
  }

  async fetchDepartments(divisionId?: string): Promise<void> {
    this.loading = true;
    try {
      this.departments = await departmentsApi.list(divisionId);
      this.error = null;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load departments", msg);
    } finally {
      this.loading = false;
    }
  }

  async fetchTeams(departmentId?: string): Promise<void> {
    this.loading = true;
    try {
      this.teams = await teamsApi.list(departmentId);
      this.error = null;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load teams", msg);
    } finally {
      this.loading = false;
    }
  }

  async fetchTree(organizationId: string): Promise<void> {
    this.loading = true;
    try {
      this.tree = await hierarchyApi.get(organizationId);
      this.error = null;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load hierarchy", msg);
    } finally {
      this.loading = false;
    }
  }

  // ── CRUD — Divisions ─────────────────────────────────────────────────────────

  async createDivision(data: Partial<Division>): Promise<Division | null> {
    try {
      const created = await divisionsApi.create(data);
      this.divisions = [created, ...this.divisions];
      toastStore.success("Division created", data.name ?? "");
      return created;
    } catch (e) {
      toastStore.error("Failed to create division", (e as Error).message);
      return null;
    }
  }

  async updateDivision(
    id: string,
    data: Partial<Division>,
  ): Promise<Division | null> {
    try {
      const updated = await divisionsApi.update(id, data);
      this.divisions = this.divisions.map((d) => (d.id === id ? updated : d));
      if (this.selectedDivision?.id === id) this.selectedDivision = updated;
      toastStore.success("Division updated");
      return updated;
    } catch (e) {
      toastStore.error("Failed to update division", (e as Error).message);
      return null;
    }
  }

  async deleteDivision(id: string): Promise<boolean> {
    try {
      await divisionsApi.delete(id);
      this.divisions = this.divisions.filter((d) => d.id !== id);
      if (this.selectedDivision?.id === id) this.selectedDivision = null;
      toastStore.success("Division deleted");
      return true;
    } catch (e) {
      toastStore.error("Failed to delete division", (e as Error).message);
      return false;
    }
  }

  // ── CRUD — Departments ───────────────────────────────────────────────────────

  async createDepartment(
    data: Partial<Department>,
  ): Promise<Department | null> {
    try {
      const created = await departmentsApi.create(data);
      this.departments = [created, ...this.departments];
      toastStore.success("Department created", data.name ?? "");
      return created;
    } catch (e) {
      toastStore.error("Failed to create department", (e as Error).message);
      return null;
    }
  }

  async updateDepartment(
    id: string,
    data: Partial<Department>,
  ): Promise<Department | null> {
    try {
      const updated = await departmentsApi.update(id, data);
      this.departments = this.departments.map((d) =>
        d.id === id ? updated : d,
      );
      if (this.selectedDepartment?.id === id) this.selectedDepartment = updated;
      toastStore.success("Department updated");
      return updated;
    } catch (e) {
      toastStore.error("Failed to update department", (e as Error).message);
      return null;
    }
  }

  async deleteDepartment(id: string): Promise<boolean> {
    try {
      await departmentsApi.delete(id);
      this.departments = this.departments.filter((d) => d.id !== id);
      if (this.selectedDepartment?.id === id) this.selectedDepartment = null;
      toastStore.success("Department deleted");
      return true;
    } catch (e) {
      toastStore.error("Failed to delete department", (e as Error).message);
      return false;
    }
  }

  // ── CRUD — Teams ─────────────────────────────────────────────────────────────

  async createTeam(data: Partial<Team>): Promise<Team | null> {
    try {
      const created = await teamsApi.create(data);
      this.teams = [created, ...this.teams];
      toastStore.success("Team created", data.name ?? "");
      return created;
    } catch (e) {
      toastStore.error("Failed to create team", (e as Error).message);
      return null;
    }
  }

  async updateTeam(id: string, data: Partial<Team>): Promise<Team | null> {
    try {
      const updated = await teamsApi.update(id, data);
      this.teams = this.teams.map((t) => (t.id === id ? updated : t));
      if (this.selectedTeam?.id === id) this.selectedTeam = updated;
      toastStore.success("Team updated");
      return updated;
    } catch (e) {
      toastStore.error("Failed to update team", (e as Error).message);
      return null;
    }
  }

  async deleteTeam(id: string): Promise<boolean> {
    try {
      await teamsApi.delete(id);
      this.teams = this.teams.filter((t) => t.id !== id);
      if (this.selectedTeam?.id === id) this.selectedTeam = null;
      toastStore.success("Team deleted");
      return true;
    } catch (e) {
      toastStore.error("Failed to delete team", (e as Error).message);
      return false;
    }
  }

  // ── Team membership ──────────────────────────────────────────────────────────

  async addTeamMember(
    teamId: string,
    agentId: string,
    role: "member" | "manager" = "member",
  ): Promise<boolean> {
    try {
      await teamsApi.addMember(teamId, agentId, role);
      toastStore.success("Agent added to team");
      return true;
    } catch (e) {
      toastStore.error("Failed to add member", (e as Error).message);
      return false;
    }
  }

  async removeTeamMember(teamId: string, agentId: string): Promise<boolean> {
    try {
      await teamsApi.removeMember(teamId, agentId);
      toastStore.success("Agent removed from team");
      return true;
    } catch (e) {
      toastStore.error("Failed to remove member", (e as Error).message);
      return false;
    }
  }

  // ── Selection ────────────────────────────────────────────────────────────────

  selectDivision(div: Division | null): void {
    this.selectedDivision = div;
  }

  selectDepartment(dept: Department | null): void {
    this.selectedDepartment = dept;
  }

  selectTeam(team: Team | null): void {
    this.selectedTeam = team;
  }
}

export const hierarchyStore = new HierarchyStore();
