// src/lib/services/template-deploy.ts
// Template deployment pipeline: scaffolds .canopy/ workspace via Tauri IPC,
// loads agents from filesystem or bundled data, and registers them.

import type { CanopyAgent } from "$api/types";
import { workspaceStore } from "$lib/stores/workspace.svelte";
import { agentsStore } from "$lib/stores/agents.svelte";
import { isTauri } from "$lib/utils/platform";
import { isMockEnabled } from "$api/client";

export interface DeployResult {
  success: boolean;
  workspaceId: string | null;
  agentCount: number;
  error?: string;
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
    if (agents.length > 0) {
      await registerAgents(agents, ws.id);
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
      agentCount: agents.length,
    };
  } catch (e) {
    return {
      success: false,
      workspaceId: null,
      agentCount: 0,
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
 */
async function registerAgents(
  agents: CanopyAgent[],
  workspaceId: string,
): Promise<void> {
  if (isMockEnabled()) {
    // Mock mode only: persist agents to localStorage so they survive
    // fetchAgents() calls and page reloads while offline.
    const { setMockWorkspaceAgents } = await import("$api/mock/agents");
    setMockWorkspaceAgents(workspaceId, agents);

    // Inject into store immediately so the UI reflects them without a refetch.
    agentsStore.agents = agents;
  } else {
    // Real backend available: create agents via API. The store will be
    // refreshed by the subsequent fetchAgents() call, so we do not need to
    // set agentsStore.agents directly — doing so would risk showing a mix
    // of partially-created agents before the backend confirms them.
    try {
      const { agents: agentsApi } = await import("$api/client");

      await Promise.allSettled(
        agents.map((agent) =>
          agentsApi.create({
            name: agent.display_name || agent.name,
            display_name: agent.display_name,
            avatar_emoji: agent.avatar_emoji,
            role: agent.role,
            adapter: agent.adapter,
            model: agent.model,
            system_prompt: agent.system_prompt,
            config: { ...agent.config, workspace_id: workspaceId },
            skills: agent.skills,
          }),
        ),
      );
    } catch {
      // API creation failed — fall back to store-only injection so the
      // user at least sees something, but do NOT persist to localStorage.
      agentsStore.agents = agents;
    }
  }
}
