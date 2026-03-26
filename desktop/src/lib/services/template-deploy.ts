// src/lib/services/template-deploy.ts
// Template deployment pipeline: scaffolds .canopy/ workspace via Tauri IPC,
// loads agents from filesystem or bundled data, and registers them with
// full organizational hierarchy (Division → Department → Team → Agent).

import type { CanopyAgent, AdapterType } from "$api/types";
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
 *   3. Register agents with hierarchy (3-pass)
 *   4. Call scaffold_canopy_dir IPC → creates .canopy/agents/*.md on disk
 *   5. Set active workspace
 *
 * Web fallback:
 *   1. Load agent definitions from bundled TS module
 *   2. Create workspace entry (localStorage)
 *   3. Register agents with hierarchy (3-pass)
 *   4. Set active workspace
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

    // Step 3: Register agents with hierarchy BEFORE setting active workspace
    // (so any fetchAgents triggered by setActiveWorkspace finds them)
    let failedAgents: Array<{ name: string; error: string }> = [];
    const warnings: string[] = [];
    if (agents.length > 0) {
      const result = await registerAgents(agents, ws.id);
      failedAgents = result.failures;
      warnings.push(...result.warnings);
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
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        toastStore.warning(
          "Workspace files not created on disk",
          `Tauri scaffold failed: ${msg}. Agents are loaded from bundled data and will work normally.`,
          6000,
        );
      }
    }

    // Step 5: Set active workspace
    await workspaceStore.setActiveWorkspace(ws.id);

    return {
      success: true,
      workspaceId: ws.id,
      agentCount: agents.length - failedAgents.length,
      failedAgents,
      warnings: warnings.length > 0 ? warnings : undefined,
    };
  } catch (e) {
    const msg = (e as Error).message;
    toastStore.error("Template deployment failed", msg);
    return {
      success: false,
      workspaceId: null,
      agentCount: 0,
      failedAgents: [],
      error: msg,
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

/** Derive a URL-safe slug from a display name or short ID. */
function toSlug(name: string): string {
  return (name || "agent")
    .toLowerCase()
    .replace(/[^a-z0-9-]/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
}

/** Normalize adapter string: template may use underscores, schema requires hyphens. */
function normalizeAdapter(adapter: string): AdapterType {
  return (adapter || "claude-code").replace(/_/g, "-") as AdapterType;
}

/** Capitalize the first letter of a string. */
function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

interface RegisterResult {
  failures: Array<{ name: string; error: string }>;
  warnings: string[];
}

/**
 * Register agents with full hierarchy using a 3-pass approach:
 *
 * Pass 1 — Create all agents, collecting a name→ID mapping.
 * Pass 2 — Patch each agent's reports_to with the resolved real ID.
 * Pass 3 — Create Divisions / Departments / Teams from config.division
 *           values, then assign agents to their teams.
 *
 * Both mock and real-backend paths use the same 3-pass flow so that
 * hierarchy is built consistently in both modes.
 */
async function registerAgents(
  agents: CanopyAgent[],
  workspaceId: string,
): Promise<RegisterResult> {
  const {
    agents: agentsApi,
    divisions: divisionsApi,
    departments: departmentsApi,
    teams: teamsApi,
  } = await import("$api/client");
  const { hierarchyStore } = await import("$lib/stores/hierarchy.svelte");

  const failures: Array<{ name: string; error: string }> = [];
  const warnings: string[] = [];

  // ── Pass 1: Create all agents, collect name→ID map ──────────────────────
  const nameToId = new Map<string, string>();
  const createdAgents: CanopyAgent[] = [];

  for (const agent of agents) {
    try {
      const slug = toSlug(agent.name);
      const adapter = normalizeAdapter(agent.adapter);

      const created = await agentsApi.create({
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
        // reports_to intentionally omitted — resolved in pass 2
      });

      nameToId.set(agent.name, created.id);
      createdAgents.push(created);
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      failures.push({
        name: agent.display_name || agent.name,
        error: errorMsg,
      });
      // Push a placeholder so indices stay aligned with `agents` array
      createdAgents.push(agent);
    }
  }

  // If all agents failed, bail early
  if (failures.length === agents.length) {
    toastStore.error(
      "All agents failed to create",
      failures.map((f) => `${f.name}: ${f.error}`).join("\n"),
    );
    return { failures, warnings };
  }

  // Show partial agent creation failures
  if (failures.length > 0) {
    const detail = failures.map((f) => `${f.name}: ${f.error}`).join("\n");
    toastStore.warning(
      `${failures.length} agent${failures.length > 1 ? "s" : ""} failed to create`,
      detail,
      8000,
    );
  }

  // ── Pass 2: Patch reports_to using resolved IDs ─────────────────────────
  for (let i = 0; i < agents.length; i++) {
    const template = agents[i];
    const reportsToName = template.config?.reportsTo as string | undefined;
    if (!reportsToName) continue;

    const reportsToId = nameToId.get(reportsToName);
    if (!reportsToId) continue; // parent not created — skip

    const agentId = nameToId.get(template.name);
    if (!agentId) continue; // this agent failed creation — skip

    try {
      await agentsApi.update(agentId, { reports_to: reportsToId });
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      warnings.push(
        `Failed to set reports_to for ${template.display_name || template.name}: ${msg}`,
      );
    }
  }

  // ── Pass 3: Create Divisions / Departments / Teams and assign members ───
  const divisionNames = [
    ...new Set(
      agents
        .map((a) => a.config?.division as string | undefined)
        .filter((d): d is string => Boolean(d)),
    ),
  ];

  for (const divName of divisionNames) {
    try {
      // Create Division
      const division = await divisionsApi.create({
        name: capitalize(divName),
      });

      // Create Department under Division
      const department = await departmentsApi.create({
        name: `${capitalize(divName)} Department`,
        division_id: division.id,
      });

      // Create Team under Department
      const team = await teamsApi.create({
        name: `${capitalize(divName)} Team`,
        department_id: department.id,
      });

      // Assign agents belonging to this division
      for (let i = 0; i < agents.length; i++) {
        if (agents[i].config?.division !== divName) continue;
        const agentId = nameToId.get(agents[i].name);
        if (!agentId) continue; // agent failed creation

        try {
          await teamsApi.addMember(team.id, agentId);
        } catch (err) {
          const msg = err instanceof Error ? err.message : String(err);
          warnings.push(
            `Failed to add ${agents[i].display_name || agents[i].name} to ${capitalize(divName)} Team: ${msg}`,
          );
        }
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      warnings.push(
        `Failed to create hierarchy for division "${capitalize(divName)}": ${msg}`,
      );
    }
  }

  // Surface hierarchy warnings
  if (warnings.length > 0) {
    toastStore.warning(
      `${warnings.length} hierarchy warning${warnings.length > 1 ? "s" : ""}`,
      warnings.join("\n"),
      8000,
    );
  }

  // ── Refresh stores so sidebar and hierarchy pages reflect new structure ──
  await hierarchyStore.fetchDivisions();
  await agentsStore.fetchAgents(workspaceId);

  // Also persist to mock layer for offline resilience
  if (isMockEnabled()) {
    try {
      const { setMockWorkspaceAgents } = await import("$api/mock/agents");
      const freshAgents = agentsStore.agents;
      if (freshAgents.length > 0) {
        setMockWorkspaceAgents(workspaceId, freshAgents);
      }
    } catch {
      // Mock module may not be available
    }
  }

  return { failures, warnings };
}
