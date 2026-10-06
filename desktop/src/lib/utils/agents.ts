// src/lib/utils/agents.ts
// Converters between the three agent representations used in Canopy:
//   - CanopyAgentDef  (.canopy/ filesystem scan, from Tauri IPC / canopy.ts)
//   - AgentTemplateData  (onboarding store, onboarding.svelte.ts)
//   - CanopyAgent  (API / backend wire type, api/types.ts)

import type { CanopyAgent, AdapterType } from "$api/types";
import type { CanopyAgentDef } from "$lib/types/canopy";
import type { AgentTemplateData } from "$lib/stores/onboarding.svelte";

// The .canopy/ workspace uses hyphenated adapter names (e.g. "claude-code")
// while the API uses underscored names (e.g. "claude_code"). This normalizes
// any hyphenated value into the API's AdapterType union.
function normalizeAdapter(raw: string): AdapterType {
  const normalized = raw.replace(/-/g, "_") as AdapterType;
  const valid: AdapterType[] = [
    "osa",
    "claude_code",
    "codex",
    "openclaw",
    "jidoclaw",
    "hermes",
    "bash",
    "http",
    "human",
    "custom",
  ];
  return valid.includes(normalized) ? normalized : "custom";
}

function capitalize(s: string): string {
  return s.replace(/[-_]/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

const DEFAULT_MODEL = "claude-sonnet-4-20250514";

const ZERO_USAGE = {
  input: 0,
  output: 0,
  cache_read: 0,
  cache_write: 0,
} as const;

/** Convert a scanned CanopyAgentDef (from Tauri IPC / .canopy/ workspace) to a CanopyAgent. */
export function canopyDefToAgent(def: CanopyAgentDef): CanopyAgent {
  const now = new Date().toISOString();
  return {
    id: def.id,
    name: def.name,
    display_name: capitalize(def.name),
    avatar_emoji: def.emoji ?? "🤖",
    role: def.role,
    status: "idle",
    adapter: normalizeAdapter(def.adapter),
    model: def.model ?? DEFAULT_MODEL,
    system_prompt: def.system_prompt ?? "",
    config: {},
    skills: def.skills,
    team_id: null,
    schedule_id: def.schedule ?? null,
    budget_policy_id: null,
    current_task: null,
    last_active_at: now,
    token_usage_today: { ...ZERO_USAGE },
    cost_today_cents: 0,
    created_at: now,
    updated_at: now,
  };
}

/** Convert an onboarding AgentTemplateData to a CanopyAgent. */
export function templateToAgent(tmpl: AgentTemplateData): CanopyAgent {
  const now = new Date().toISOString();
  return {
    id: tmpl.id,
    name: tmpl.name,
    display_name: capitalize(tmpl.name),
    avatar_emoji: tmpl.emoji || "🤖",
    role: tmpl.role,
    status: "idle",
    adapter: normalizeAdapter(tmpl.adapter),
    model: tmpl.model ?? DEFAULT_MODEL,
    system_prompt: tmpl.system_prompt ?? "",
    config: {},
    skills: tmpl.skills,
    team_id: null,
    schedule_id: null,
    budget_policy_id: null,
    current_task: null,
    last_active_at: now,
    token_usage_today: { ...ZERO_USAGE },
    cost_today_cents: 0,
    created_at: now,
    updated_at: now,
  };
}
