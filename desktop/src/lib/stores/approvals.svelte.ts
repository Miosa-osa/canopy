// src/lib/stores/approvals.svelte.ts
import type {
  Approval,
  ApprovalStatus,
  ApprovalCreateRequest,
} from "$api/types";
import { approvals as approvalsApi } from "$api/client";
import { toastStore } from "./toasts.svelte";

class ApprovalsStore {
  approvals = $state<Approval[]>([]);
  selected = $state<Approval | null>(null);
  loading = $state(false);
  error = $state<string | null>(null);

  // Filter state
  filterStatus = $state<ApprovalStatus | "all">("all");

  // Derived
  pendingCount = $derived(
    this.approvals.filter((a) => a.status === "pending").length,
  );

  filteredApprovals = $derived.by(() => {
    if (this.filterStatus === "all") return this.approvals;
    return this.approvals.filter((a) => a.status === this.filterStatus);
  });

  pendingApprovals = $derived(
    this.approvals.filter((a) => a.status === "pending"),
  );

  async fetchApprovals(
    workspaceId?: string,
    params?: Record<string, string>,
  ): Promise<void> {
    this.loading = true;
    try {
      const mergedParams = workspaceId
        ? { ...params, workspace_id: workspaceId }
        : params;
      this.approvals = await approvalsApi.list(mergedParams);
      this.error = null;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load approvals", msg);
    } finally {
      this.loading = false;
    }
  }

  async createApproval(data: ApprovalCreateRequest): Promise<Approval | null> {
    this.loading = true;
    try {
      const created = await approvalsApi.create(data);
      this.approvals = [created, ...this.approvals];
      this.error = null;
      toastStore.success("Approval request created", data.title);
      return created;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to create approval", msg);
      return null;
    } finally {
      this.loading = false;
    }
  }

  async approve(id: string, comment?: string): Promise<Approval | null> {
    const previous = this.approvals;
    // Optimistic update
    this.approvals = this.approvals.map((a) =>
      a.id === id ? { ...a, status: "approved" as ApprovalStatus } : a,
    );
    if (this.selected?.id === id) {
      this.selected = { ...this.selected, status: "approved" };
    }
    try {
      const updated = await approvalsApi.approve(id, comment);
      this.approvals = this.approvals.map((a) => (a.id === id ? updated : a));
      if (this.selected?.id === id) this.selected = updated;
      this.error = null;
      toastStore.success("Approval granted");
      return updated;
    } catch (e) {
      this.approvals = previous;
      if (this.selected?.id === id) {
        this.selected = previous.find((a) => a.id === id) ?? this.selected;
      }
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to approve", msg);
      return null;
    }
  }

  async reject(id: string, comment?: string): Promise<Approval | null> {
    const previous = this.approvals;
    // Optimistic update
    this.approvals = this.approvals.map((a) =>
      a.id === id ? { ...a, status: "rejected" as ApprovalStatus } : a,
    );
    if (this.selected?.id === id) {
      this.selected = { ...this.selected, status: "rejected" };
    }
    try {
      const updated = await approvalsApi.reject(id, comment);
      this.approvals = this.approvals.map((a) => (a.id === id ? updated : a));
      if (this.selected?.id === id) this.selected = updated;
      this.error = null;
      toastStore.success("Approval rejected");
      return updated;
    } catch (e) {
      this.approvals = previous;
      if (this.selected?.id === id) {
        this.selected = previous.find((a) => a.id === id) ?? this.selected;
      }
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to reject", msg);
      return null;
    }
  }

  selectApproval(approval: Approval | null): void {
    this.selected = approval;
  }

  setFilter(status: ApprovalStatus | "all"): void {
    this.filterStatus = status;
  }

  getById(id: string): Approval | null {
    return this.approvals.find((a) => a.id === id) ?? null;
  }
}

export const approvalsStore = new ApprovalsStore();
