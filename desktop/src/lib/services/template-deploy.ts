// src/lib/services/template-deploy.ts
// Template deployment pipeline: scaffolds .canopy/ workspace via Tauri IPC,
// loads agents from filesystem or bundled data, and registers them.

import type { CanopyAgent } from "$api/types";
import { workspaceStore } from "$lib/stores/workspace.svelte";
import { agentsStore } from "$lib/stores/agents.svelte";
import { toastStore } from "$lib/stores/toasts.svelte";
import { isTauri } from "$lib/utils/platform";
import { isMockEnabled } from "$api/client";

export interface DeployResult {
  success: boolean;
  workspaceId: string | null;
  agentCount: number;
  failedAgents: Array<{ name: string; error: string }>;
  error?: string;
  warnings?: string[];
}

/**
 * Deploy a template to a new workspace.
 *
 * Desktop (Tauri) flow:
 *   1. Load agent definitions from bundled TS module
 *   2. Create workspace entry (localStorage)
 *   3. Call scaffold_canopy_dir IPC → creates .canopy/agents/*.md on disk
 *   4. Set active workspace
 *   5. Register agents into store + backend
 *
 * Web fallback:
 *   1. Load agent definitions from bundled TS module
 *   2. Create workspace entry (localStorage)
 *   3. Set active workspace
 *   4. Register agents into store
 */
export async function deployTemplate(
  templateId: string,
  templateName: string,
): Promise<DeployResult> {
  try {
    // Step 1: Load agents from bundled template module
    const agents = await loadBundledTemplate(templateId);

    // Step 2: Create workspace (API + local storage)
    const ws = await workspaceStore.createWorkspace(templateName);
    if (!ws) throw new Error("Failed to create workspace");

    // Step 3: Register agents in mock layer BEFORE setting active workspace
    // (so any fetchAgents triggered by setActiveWorkspace finds them)
    let failedAgents: Array<{ name: string; error: string }> = [];
    if (agents.length > 0) {
      failedAgents = await registerAgents(agents, ws.id);
    }

    // Step 4: Scaffold .canopy/ directory on disk via Tauri IPC
    if (isTauri() && agents.length > 0) {
      try {
        const { invoke } = await import("@tauri-apps/api/core");
        await invoke("scaffold_canopy_dir", {
          path: ws.path,
          name: templateName,
          description: `${templateName} workspace deployed from template.`,
          agents: agents.map((a) => ({
            id: a.name,
            name: a.display_name || a.name,
            emoji: a.avatar_emoji || "🤖",
            role: a.role,
            adapter: a.adapter.replace(/_/g, "-"), // Rust expects hyphenated
            model: a.model || null,
            skills: a.skills || [],
            system_prompt: a.system_prompt || null,
          })),
        });
      } catch {
        // scaffold_canopy_dir failed — agents still loaded from bundled data
      }
    }

    // Step 5: Set active workspace
    await workspaceStore.setActiveWorkspace(ws.id);

    return {
      success: true,
      workspaceId: ws.id,
      agentCount: agents.length - failedAgents.length,
      failedAgents,
    };
  } catch (e) {
    return {
      success: false,
      workspaceId: null,
      agentCount: 0,
      failedAgents: [],
      error: (e as Error).message,
    };
  }
}

/**
 * Load bundled template agent definitions via dynamic import.
 * Each template ships a module at:
 *   src/lib/api/mock/library/templates/{templateId}.ts
 * that exports its agents as both `default` and named `agents`.
 */
async function loadBundledTemplate(templateId: string): Promise<CanopyAgent[]> {
  try {
    const modules = import.meta.glob<{
      default: CanopyAgent[];
      agents?: CanopyAgent[];
    }>("../api/mock/library/templates/*.ts");

    // Vite key format varies by version — match by suffix to be safe
    const suffix = `/${templateId}.ts`;
    const matchKey = Object.keys(modules).find((k) => k.endsWith(suffix));
    const loader = matchKey ? modules[matchKey] : undefined;
    if (!loader) return [];

    const mod = await loader();
    return mod.agents ?? mod.default ?? [];
  } catch {
    return [];
  }
}

/**
 * Register agents for immediate display and persistence.
 *
 * 1. Persist in mock layer (survives navigation / fetchAgents cycles)
 * 2. Inject into Svelte store for instant UI
 * 3. Persist to real backend if available
 *
 * Returns a list of agents that failed to register (empty on full success).
 */
async function registerAgents(
  agents: CanopyAgent[],
  workspaceId: string,
): Promise<Array<{ name: string; error: string }>> {
  if (isMockEnabled()) {
    // Mock mode only: persist agents to localStorage so they survive
    // fetchAgents() calls and page reloads while offline.
    const { setMockWorkspaceAgents } = await import("$api/mock/agents");
    setMockWorkspaceAgents(workspaceId, agents);

    // Inject into store immediately so the UI reflects them without a refetch.
    agentsStore.agents = agents;
    return [];
  } else {
    // Real backend available: create agents via API. The store will be
    // refreshed by the subsequent fetchAgents() call, so we do not need to
    // set agentsStore.agents directly — doing so would risk showing a mix
    // of partially-created agents before the backend confirms them.
    try {
      const { agents: agentsApi } = await import("$api/client");

      const results = await Promise.allSettled(
        agents.map((agent) => {
          // Derive slug from agent.name (the short ID, e.g. "growth-director")
          const slug = (agent.name || agent.display_name || "agent")
            .toLowerCase()
            .replace(/[^a-z0-9-]/g, "-")
            .replace(/-+/g, "-")
            .replace(/^-|-$/g, "");

          // Normalize adapter: template may use underscores, schema requires hyphens
          const adapter = (agent.adapter || "claude-code").replace(/_/g, "-");

          return agentsApi.create({
            slug,
            name: agent.display_name || agent.name,
            display_name: agent.display_name || agent.name,
            role: agent.role,
            adapter,
            model: agent.model || "sonnet",
            workspace_id: workspaceId,
            avatar_emoji: agent.avatar_emoji,
            system_prompt: agent.system_prompt,
            config: agent.config || {},
          });
        }),
      );

      // Collect failed registrations
      const failures: Array<{ name: string; error: string }> = [];
      results.forEach((result, index) => {
        if (result.status === "rejected") {
          const agent = agents[index];
          failures.push({
            name: agent.display_name || agent.name,
            error:
              result.reason instanceof Error
                ? result.reason.message
                : String(result.reason),
          });
        }
      });

      if (failures.length > 0) {
        const detail = failures.map((f) => `${f.name}: ${f.error}`).join("\n");
        toastStore.warning(
          `${failures.length} agent${failures.length > 1 ? "s" : ""} failed to register`,
          detail,
          8000,
        );
      }

      return failures;
    } catch (err) {
      // Entire API call failed — fall back to store-only injection so the
      // user at least sees something, but do NOT persist to localStorage.
      agentsStore.agents = agents;
      const errorMsg = err instanceof Error ? err.message : String(err);
      return agents.map((a) => ({
        name: a.display_name || a.name,
        error: errorMsg,
      }));
    }
  }
}
