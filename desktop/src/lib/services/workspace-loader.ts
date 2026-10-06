/**
 * workspace-loader.ts
 *
 * Initialises all workspace-dependent stores after auth resolves.
 * Call once per session after initializeAuth() + the onboarding guard pass.
 */

import { connectionStore } from "$lib/stores/connection.svelte";
import { activityStore } from "$lib/stores/activity.svelte";
import { workspaceStore } from "$lib/stores/workspace.svelte";
import { agentsStore } from "$lib/stores/agents.svelte";
import { projectsStore } from "$lib/stores/projects.svelte";
import { organizationsStore } from "$lib/stores/organizations.svelte";
import { approvalsStore } from "$lib/stores/approvals.svelte";
import { hierarchyStore } from "$lib/stores/hierarchy.svelte";
import { nodesStore } from "$lib/stores/nodes.svelte";
import { signalsFsStore } from "$lib/stores/signals-fs.svelte";
import { rhythmStore } from "$lib/stores/rhythm.svelte";
import { topologyStore } from "$lib/stores/topology.svelte";

/**
 * Starts connection polling and the activity SSE stream.
 * Returns a cleanup function that stops polling and unsubscribes SSE.
 */
export function startConnectionServices(): () => void {
  const stopPolling = connectionStore.startPolling(30_000);
  activityStore.subscribe();
  return () => {
    stopPolling();
    activityStore.unsubscribe();
  };
}

/**
 * Loads all filesystem stores from the active workspace path.
 * No-op if no workspace path is available.
 */
export async function loadFilesystemStores(wsPath: string): Promise<void> {
  await Promise.all([
    nodesStore.load(wsPath),
    signalsFsStore.load(wsPath),
    rhythmStore.load(wsPath),
    topologyStore.load(wsPath),
  ]);
}

/**
 * Syncs workspace + org data from the backend, then pre-fetches the full
 * hierarchy tree, agents, projects, and approvals.
 */
export async function loadWorkspaceStores(): Promise<void> {
  // Fetch local workspaces + sync from backend.
  workspaceStore.fetchWorkspaces();

  // Load filesystem stores from whatever path is set in localStorage now.
  // syncFromBackend() may change the active workspace — we re-load after it
  // completes to make sure we always end up on the correct path.
  const wsPathBefore = workspaceStore.activeWorkspace?.path;
  if (wsPathBefore) {
    void loadFilesystemStores(wsPathBefore);
  }

  await workspaceStore.syncFromBackend();

  // After backend sync, the active workspace may have changed. Reload if so.
  const wsPathAfter = workspaceStore.activeWorkspace?.path;
  if (wsPathAfter && wsPathAfter !== wsPathBefore) {
    void loadFilesystemStores(wsPathAfter);
  }

  // Organisations.
  await organizationsStore.ensureDefault();

  // Hierarchy tree.
  if (organizationsStore.current) {
    void hierarchyStore.fetchTree(organizationsStore.current.id);
    void hierarchyStore.fetchDivisions(organizationsStore.current.id);
    void hierarchyStore.fetchDepartments();
    void hierarchyStore.fetchTeams();
  }

  // Workspace-scoped data.
  const ws = workspaceStore.activeWorkspace;
  const wsId = workspaceStore.activeWorkspaceId ?? undefined;

  void approvalsStore.fetchApprovals(wsId);
  void projectsStore.fetchProjects(wsId);

  if (ws) {
    workspaceStore.scanAndLoadAgents(ws.path).then(() => {
      workspaceStore.watchActive();
      if (agentsStore.agents.length === 0) {
        void agentsStore.fetchAgents(wsId);
      }
    });
  } else {
    void agentsStore.fetchAgents(wsId);
  }
}
