/**
 * TanStack Query factories for the agent ↔ skill assignment resource.
 *
 * Backend endpoints:
 *   GET    /api/v1/agents/:slug/skills              — list assignments with joined skill
 *   POST   /api/v1/agents/:slug/skills              — assign a skill { skill_slug, priority? }
 *   DELETE /api/v1/agents/:slug/skills/:skill_slug  — remove assignment
 */

import { apiDelete, apiGet, apiPost } from "$lib/api/client.js";
import type { AgentSkillAssignment } from "$lib/domain/skills/types.js";

// ── Raw API calls ────────────────────────────────────────────────────────────

export function listAgentSkills(
  agentSlug: string,
): Promise<AgentSkillAssignment[]> {
  return apiGet<AgentSkillAssignment[]>(`/agents/${agentSlug}/skills`);
}

export function assignSkill(
  agentSlug: string,
  skillSlug: string,
  priority = 0,
): Promise<AgentSkillAssignment> {
  return apiPost<AgentSkillAssignment>(`/agents/${agentSlug}/skills`, {
    skill_slug: skillSlug,
    priority,
  });
}

export function unassignSkill(
  agentSlug: string,
  skillSlug: string,
): Promise<void> {
  return apiDelete<void>(`/agents/${agentSlug}/skills/${skillSlug}`);
}

// ── TanStack Query option factories ─────────────────────────────────────────

/** Query options for listing an agent's assigned skills. */
export function agentSkillsQuery(agentSlug: string) {
  return {
    queryKey: ["agents", agentSlug, "skills"] as const,
    queryFn: () =>
      listAgentSkills(agentSlug).then((data) => {
        // Backend wraps in { data: [...] }
        return (data as unknown as { data: AgentSkillAssignment[] }).data;
      }),
    staleTime: 30_000,
    enabled: Boolean(agentSlug),
  };
}

/** Mutation options for assigning a skill to an agent. */
export function assignSkillMutation() {
  return {
    mutationKey: ["agents", "skills", "assign"] as const,
    mutationFn: ({
      agentSlug,
      skillSlug,
      priority,
    }: {
      agentSlug: string;
      skillSlug: string;
      priority?: number;
    }) => assignSkill(agentSlug, skillSlug, priority ?? 0),
  };
}

/** Mutation options for removing a skill assignment from an agent. */
export function unassignSkillMutation() {
  return {
    mutationKey: ["agents", "skills", "unassign"] as const,
    mutationFn: ({
      agentSlug,
      skillSlug,
    }: {
      agentSlug: string;
      skillSlug: string;
    }) => unassignSkill(agentSlug, skillSlug),
  };
}
