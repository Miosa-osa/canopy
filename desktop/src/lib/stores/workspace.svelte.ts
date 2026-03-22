// src/lib/stores/workspace.svelte.ts
import { browser } from "$app/environment";
import { isTauri } from "$lib/utils/platform";
import type { Workspace as BackendWorkspace } from "$api/types";
import { toastStore } from "./toasts.svelte";
import { workspaces as workspacesApi, isMockEnabled } from "$api/client";

/**
 * Extract the `description` field from YAML frontmatter in a markdown file.
 * Returns undefined if the file has no frontmatter or no description key.
 */
function parseSystemMdDescription(content: string): string | undefined {
  const trimmed = content.trim();
  if (!trimmed.startsWith("---")) return undefined;
  const afterFirst = trimmed.slice(3);
  const end = afterFirst.indexOf("---");
  if (end === -1) return undefined;
  const yaml = afterFirst.slice(0, end);
  const match = yaml.match(/^description:\s*(.+)$/m);
  return match?.[1]?.trim() || undefined;
}

/** Resolve ~ to actual home directory path */
async function resolveHomePath(p: string): Promise<string> {
  if (!p.startsWith("~")) return p;
  if (isTauri()) {
    try {
      const { homeDir } = await import("@tauri-apps/api/path");
      const home = await homeDir();
      return p.replace("~", home.replace(/\/$/, ""));
    } catch {
      // fallback
    }
  }
  return p;
}

export interface LocalWorkspace {
  id: string;
  path: string;
  name: string;
  description?: string;
  addedAt: string;
}

interface CanopyWorkspaceScan {
  path: string;
  name: string;
  agents: any[];
  projects: any[];
  schedules: any[];
  skills: any[];
  /** Raw contents of .canopy/SYSTEM.md */
  system_md: string | null;
  /** Raw contents of .canopy/COMPANY.md */
  company_md: string | null;
  scanned_at: string;
}

const STORAGE_KEY = "canopy-workspaces";
const ACTIVE_KEY = "canopy-active-workspace";

class WorkspaceStore {
  workspaces = $state<LocalWorkspace[]>([]);
  activeWorkspaceId = $state<string | null>(null);
  isLoading = $state(false);
  error = $state<string | null>(null);
  lastScan = $state<CanopyWorkspaceScan | null>(null);

  get activeWorkspace(): LocalWorkspace | null {
    return (
      this.workspaces.find((w) => w.id === this.activeWorkspaceId) ??
      this.workspaces[0] ??
      null
    );
  }

  /** Hydrate from localStorage */
  fetchWorkspaces(): void {
    if (!browser) return;
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) this.workspaces = JSON.parse(raw) as LocalWorkspace[];
      const activeId = localStorage.getItem(ACTIVE_KEY);
      if (activeId && this.workspaces.some((w) => w.id === activeId)) {
        this.activeWorkspaceId = activeId;
      } else if (this.workspaces.length > 0) {
        this.activeWorkspaceId = this.workspaces[0].id;
      }
    } catch {
      // Corrupted storage — leave state empty
    }
  }

  /** Persist to localStorage */
  #persist(): void {
    if (!browser) return;
    localStorage.setItem(STORAGE_KEY, JSON.stringify(this.workspaces));
    if (this.activeWorkspaceId) {
      localStorage.setItem(ACTIVE_KEY, this.activeWorkspaceId);
    }
  }

  /** Scan a directory via Tauri IPC — returns null if .canopy/ doesn't exist */
  async scanWorkspace(path: string): Promise<CanopyWorkspaceScan | null> {
    if (!isTauri()) return null;
    try {
      const { invoke } = await import("@tauri-apps/api/core");
      const canopyPath = path.endsWith(".canopy") ? path : path + "/.canopy";
      const result = await invoke<CanopyWorkspaceScan>("scan_canopy_dir", {
        path: canopyPath,
      });
      this.lastScan = result;
      return result;
    } catch {
      toastStore.warning(
        "Workspace scan failed",
        `.canopy directory not found at ${path}`,
      );
      return null;
    }
  }

  /** Add a workspace entry — no-ops on duplicate path */
  addWorkspace(ws: LocalWorkspace): void {
    if (this.workspaces.some((w) => w.path === ws.path)) return;
    this.workspaces = [...this.workspaces, ws];
    this.#persist();
  }

  /** Set active workspace — page $effects are the single source of data refresh */
  async setActiveWorkspace(id: string): Promise<void> {
    this.activeWorkspaceId = id;
    this.#persist();

    // 1. Tell the backend which workspace is now active so it scopes
    //    subsequent queries (agents, sessions, issues, etc.) correctly.
    try {
      const { workspaces: workspacesApi } = await import("$api/client");
      await workspacesApi.activate(id);
    } catch {
      // Non-fatal: backend may be unavailable or workspace may not exist there
    }

    // 2. Bust the response cache so stale data for the previous workspace is
    //    not served to the new workspace's API calls.
    const { clearCache } = await import("$api/client");
    clearCache();

    // 3. Try Tauri filesystem scan first (desktop app only).
    //    NOTE: Store fetches are intentionally omitted here. Each page component
    //    has a $effect watching activeWorkspaceId that triggers the appropriate
    //    fetch. Calling fetches here as well would cause a double-fetch on every
    //    workspace switch.
    const ws = this.workspaces.find((w) => w.id === id);
    if (ws) {
      await this.scanAndLoadAgents(ws.path);
    }
  }

  /** Scan workspace and load agents, skills, and context files into stores */
  async scanAndLoadAgents(path: string): Promise<void> {
    const scan = await this.scanWorkspace(path);
    if (!scan) return;

    // Update the active workspace's name/description from SYSTEM.md frontmatter
    if (scan.name || scan.system_md) {
      const ws = this.workspaces.find(
        (w) => w.path === path || path.startsWith(w.path),
      );
      if (ws) {
        const descFromSystem = scan.system_md
          ? parseSystemMdDescription(scan.system_md)
          : undefined;
        const nameChanged = scan.name && ws.name !== scan.name;
        const descChanged = descFromSystem && ws.description !== descFromSystem;
        if (nameChanged || descChanged) {
          this.workspaces = this.workspaces.map((w) =>
            w.path === ws.path
              ? {
                  ...w,
                  name: scan.name || w.name,
                  description: descFromSystem ?? w.description,
                }
              : w,
          );
          this.#persist();
        }
      }
    }

    if (scan.agents.length === 0) return;

    // Dynamic import to avoid circular deps
    const { canopyDefToAgent } = await import("$lib/utils/agents");
    const { agentsStore } = await import("./agents.svelte");

    const agents = scan.agents.map(canopyDefToAgent);
    agentsStore.agents = agents;
  }

  /** Watch active workspace for file changes via Tauri IPC */
  async watchActive(): Promise<void> {
    const ws = this.activeWorkspace;
    if (!ws || !isTauri()) return;

    try {
      const { invoke } = await import("@tauri-apps/api/core");
      const { listen } = await import("@tauri-apps/api/event");

      const canopyPath = ws.path.endsWith(".canopy")
        ? ws.path
        : ws.path + "/.canopy";
      await invoke("watch_canopy_dir", { path: canopyPath });

      listen("canopy-fs-event", async () => {
        const active = this.activeWorkspace;
        if (active) {
          await this.scanAndLoadAgents(active.path);
        }
      });
    } catch (e) {
      console.warn("Failed to start file watcher:", e);
    }
  }

  /** Remove a workspace */
  async removeWorkspace(id: string): Promise<void> {
    // Clean up deployed agents for this workspace
    try {
      const { clearMockWorkspaceAgents } = await import("$api/mock/agents");
      clearMockWorkspaceAgents(id);
    } catch {
      // Mock module may not be available
    }

    this.workspaces = this.workspaces.filter((w) => w.id !== id);
    if (this.activeWorkspaceId === id) {
      this.activeWorkspaceId = this.workspaces[0]?.id ?? null;
    }
    this.#persist();
    // Page $effects watching activeWorkspaceId handle data refresh.
  }

  /** Sync workspaces from the backend and set the active one */
  async syncFromBackend(): Promise<void> {
    try {
      const { workspaces: workspacesApi, clearMockData } =
        await import("$api/client");
      const backendWorkspaces: BackendWorkspace[] = await workspacesApi.list();
      if (!backendWorkspaces || backendWorkspaces.length === 0) return;

      // Backend responded with real workspace data — purge any mock agents or
      // other mock state that may have been persisted to localStorage during a
      // prior offline session. This must happen before any agents store fetch
      // so that stale mock agents cannot be merged with real backend agents.
      await clearMockData();

      // Prefer the first "active" workspace, fall back to the first in the list
      const activeBackendWs =
        backendWorkspaces.find((w) => w.status === "active") ??
        backendWorkspaces[0];

      // Register any backend workspaces not yet in local store
      for (const bws of backendWorkspaces) {
        if (!this.workspaces.some((w) => w.id === bws.id)) {
          const localWs: LocalWorkspace = {
            id: bws.id,
            name: bws.name,
            path:
              bws.path ??
              bws.directory ??
              `~/.canopy/${bws.name.toLowerCase().replace(/\s+/g, "-")}`,
            addedAt: bws.created_at ?? new Date().toISOString(),
          };
          this.workspaces = [...this.workspaces, localWs];
        }
      }
      this.#persist();

      // Point the active workspace at the backend's active one.
      // If this differs from what we had locally, bust the cache so that
      // subsequent data fetches (agents, dashboard, etc.) reflect the correct
      // workspace — not stale data from a previously active workspace.
      if (this.activeWorkspaceId !== activeBackendWs.id) {
        const { clearCache } = await import("$api/client");
        clearCache();
      }
      this.activeWorkspaceId = activeBackendWs.id;
      this.#persist();
    } catch {
      // Backend not available — keep existing local workspaces
    }
  }

  /** Create workspace (for API compatibility) */
  async createWorkspace(
    name: string,
    directory?: string,
  ): Promise<LocalWorkspace | null> {
    const rawPath =
      directory ?? `~/.canopy/${name.toLowerCase().replace(/\s+/g, "-")}`;
    const resolvedPath = await resolveHomePath(rawPath);

    let backendId: string | null = null;

    // Create workspace in backend so agents can reference it
    if (!isMockEnabled()) {
      try {
        const created = await workspacesApi.create({
          name,
          path: resolvedPath,
        });
        backendId =
          (created as any).workspace?.id ?? (created as any).id ?? null;
      } catch (e) {
        // Backend create failed — fall back to local-only
        console.warn("[WorkspaceStore] Backend workspace create failed:", e);
      }
    }

    const ws: LocalWorkspace = {
      id: backendId ?? crypto.randomUUID(),
      path: resolvedPath,
      name,
      addedAt: new Date().toISOString(),
    };
    this.addWorkspace(ws);
    this.activeWorkspaceId = ws.id;
    this.#persist();
    return ws;
  }
}

export const workspaceStore = new WorkspaceStore();
