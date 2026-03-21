import type { CanopyAgent } from "../types";

const now = new Date().toISOString();
const mins = (n: number) => new Date(Date.now() - n * 60_000).toISOString();

// Deterministic mock IDs — referenced by other mock files (activity, sessions, costs, etc.)
export const AGENT_IDS = {
  orchestrator: "agt-orch-001",
  researcher: "agt-rsrch-002",
  developer: "agt-dev-003",
  reviewer: "agt-rev-004",
  devops: "agt-devops-005",
  apiMonitor: "agt-mon-006",
} as const;

const AGENTS: CanopyAgent[] = [
  // ── Orchestrator ────────────────────────────────────────────────────────────
  {
    id: AGENT_IDS.orchestrator,
    name: "orchestrator",
    display_name: "Orchestrator",
    avatar_emoji: "🎯",
    role: "orchestrator",
    status: "idle",
    adapter: "osa",
    model: "claude-opus-4-6",
    system_prompt:
      "You are the Orchestrator, the top-level coordinator for the Canopy development team. " +
      "You decompose goals into subtasks, assign work to specialist agents, track progress, " +
      "resolve blockers, and synthesize results back to the user. You maintain the team's " +
      "shared context and ensure every agent is working toward the current objective.",
    config: {
      max_concurrent_agents: 5,
      delegation_strategy: "capability-match",
      escalation_threshold: 3,
    },
    skills: ["code-generation", "web-search", "pr-review", "deployment"],
    schedule_id: null,
    budget_policy_id: "bp-elite",
    current_task: "Coordinating agent team for Canopy development",
    last_active_at: mins(2),
    token_usage_today: {
      input: 145000,
      output: 42000,
      cache_read: 68000,
      cache_write: 9000,
    },
    cost_today_cents: 890,
    created_at: "2026-03-01T00:00:00Z",
    updated_at: mins(2),
  },

  // ── Research Agent ───────────────────────────────────────────────────────────
  {
    id: AGENT_IDS.researcher,
    name: "researcher",
    display_name: "Research Agent",
    avatar_emoji: "🔬",
    role: "researcher",
    status: "sleeping",
    adapter: "claude_code",
    model: "claude-sonnet-4-6",
    system_prompt:
      "You are the Research Agent, responsible for gathering technical context before implementation begins. " +
      "You perform web searches, read documentation, survey existing codebases, and produce structured " +
      "research briefs that guide the Developer and Reviewer agents. Prioritize authoritative sources " +
      "and flag conflicting information explicitly.",
    config: {
      search_depth: "deep",
      citation_style: "inline",
    },
    skills: ["web-search", "code-generation", "pr-review"],
    schedule_id: null,
    budget_policy_id: "bp-1",
    current_task: null,
    last_active_at: mins(45),
    token_usage_today: {
      input: 38000,
      output: 11000,
      cache_read: 21000,
      cache_write: 3000,
    },
    cost_today_cents: 145,
    created_at: "2026-03-01T00:00:00Z",
    updated_at: mins(45),
  },

  // ── Developer Agent ──────────────────────────────────────────────────────────
  {
    id: AGENT_IDS.developer,
    name: "developer",
    display_name: "Developer Agent",
    avatar_emoji: "💻",
    role: "developer",
    status: "running",
    adapter: "claude_code",
    model: "claude-sonnet-4-6",
    system_prompt:
      "You are the Developer Agent, responsible for writing, editing, and debugging code across the " +
      "Canopy stack (SvelteKit frontend, Phoenix backend, Elixir OSA core). You follow TDD, write " +
      "typed Svelte 5 runes components, use Foundation UI primitives, and produce clean PRs with " +
      "descriptive commit messages. You do not merge without a passing Reviewer sign-off.",
    config: {
      preferred_languages: ["elixir", "typescript", "svelte"],
      test_framework: "vitest",
      lint_on_save: true,
    },
    skills: ["code-generation", "web-search", "pr-review", "deployment"],
    schedule_id: "sched-1",
    budget_policy_id: "bp-1",
    current_task: "Fixing SSE connection drops",
    last_active_at: now,
    token_usage_today: {
      input: 72000,
      output: 24000,
      cache_read: 31000,
      cache_write: 5500,
    },
    cost_today_cents: 295,
    created_at: "2026-03-01T00:00:00Z",
    updated_at: now,
  },

  // ── Code Reviewer ────────────────────────────────────────────────────────────
  {
    id: AGENT_IDS.reviewer,
    name: "reviewer",
    display_name: "Code Reviewer",
    avatar_emoji: "👁️",
    role: "reviewer",
    status: "running",
    adapter: "claude_code",
    model: "claude-sonnet-4-6",
    system_prompt:
      "You are the Code Reviewer, the quality gate for all code changes in the Canopy project. " +
      "You review PRs for correctness, security, performance, test coverage, and adherence to " +
      "Signal Theory output standards. You approve, request changes, or block merges. You provide " +
      "actionable, specific feedback — never vague objections. Security and auth flows receive " +
      "extra scrutiny.",
    config: {
      block_on_missing_tests: true,
      require_type_safety: true,
      security_scan_enabled: true,
    },
    skills: ["pr-review", "code-generation", "web-search"],
    schedule_id: null,
    budget_policy_id: "bp-1",
    current_task: "Reviewing auth flow",
    last_active_at: now,
    token_usage_today: {
      input: 55000,
      output: 18000,
      cache_read: 24000,
      cache_write: 4000,
    },
    cost_today_cents: 210,
    created_at: "2026-03-01T00:00:00Z",
    updated_at: now,
  },

  // ── DevOps Agent ─────────────────────────────────────────────────────────────
  {
    id: AGENT_IDS.devops,
    name: "devops",
    display_name: "DevOps Agent",
    avatar_emoji: "🔧",
    role: "devops",
    status: "sleeping",
    adapter: "bash",
    model: "bash",
    system_prompt:
      "You are the DevOps Agent, responsible for infrastructure, CI/CD pipelines, deployments, " +
      "and operational health of the Canopy platform. You run shell commands, manage Docker containers, " +
      "configure GitHub Actions workflows, and trigger deployments. You operate non-interactively and " +
      "emit structured logs for every action.",
    config: {
      shell: "bash",
      timeout_seconds: 300,
      dry_run_by_default: false,
    },
    skills: ["deployment", "code-generation"],
    schedule_id: "sched-2",
    budget_policy_id: "bp-1",
    current_task: null,
    last_active_at: mins(120),
    token_usage_today: {
      input: 8000,
      output: 2500,
      cache_read: 4000,
      cache_write: 800,
    },
    cost_today_cents: 22,
    created_at: "2026-03-01T00:00:00Z",
    updated_at: mins(120),
  },

  // ── API Monitor ──────────────────────────────────────────────────────────────
  {
    id: AGENT_IDS.apiMonitor,
    name: "api-monitor",
    display_name: "API Monitor",
    avatar_emoji: "📡",
    role: "monitor",
    status: "sleeping",
    adapter: "http",
    model: "http",
    system_prompt:
      "You are the API Monitor, continuously polling Canopy backend health endpoints and external " +
      "service dependencies. You emit structured alerts when latency exceeds thresholds, error rates " +
      "spike, or services become unreachable. You do not take remediation actions — you escalate " +
      "to the Orchestrator with a structured incident report.",
    config: {
      poll_interval_seconds: 30,
      latency_threshold_ms: 500,
      error_rate_threshold_percent: 5,
      endpoints: [
        "http://localhost:9089/api/health",
        "http://localhost:9090/health",
      ],
    },
    skills: ["web-search"],
    schedule_id: "sched-3",
    budget_policy_id: "bp-1",
    current_task: null,
    last_active_at: mins(30),
    token_usage_today: {
      input: 2000,
      output: 500,
      cache_read: 1000,
      cache_write: 100,
    },
    cost_today_cents: 4,
    created_at: "2026-03-01T00:00:00Z",
    updated_at: mins(30),
  },
];

// ── Workspace-scoped agent storage ──────────────────────────────────────────
// Deployed templates persist here so agents survive app restarts & HMR reloads.
// Uses localStorage as backing store, in-memory Map as read cache.

const STORAGE_KEY = "canopy-workspace-agents";

function loadFromStorage(): Map<string, CanopyAgent[]> {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return new Map();
    const entries = JSON.parse(raw) as Array<[string, CanopyAgent[]]>;
    return new Map(entries);
  } catch {
    return new Map();
  }
}

function saveToStorage(map: Map<string, CanopyAgent[]>): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify([...map.entries()]));
  } catch {
    // Storage full or unavailable — in-memory still works
  }
}

// Hydrate from localStorage on module load
const workspaceAgents: Map<string, CanopyAgent[]> = loadFromStorage();

export function setMockWorkspaceAgents(
  workspaceId: string,
  agents: CanopyAgent[],
): void {
  workspaceAgents.set(workspaceId, agents);
  saveToStorage(workspaceAgents);
}

export function getMockWorkspaceAgents(
  workspaceId: string,
): CanopyAgent[] | undefined {
  return workspaceAgents.get(workspaceId);
}

export function clearMockWorkspaceAgents(workspaceId: string): void {
  workspaceAgents.delete(workspaceId);
  saveToStorage(workspaceAgents);
}

/**
 * Flush every workspace's agents from both the in-memory map and localStorage.
 * Call this when the real backend is confirmed reachable so that no mock
 * agent data leaks into live workspace views.
 */
export function clearAllMockWorkspaceAgents(): void {
  workspaceAgents.clear();
  saveToStorage(workspaceAgents);
}

export function mockAgents(workspaceId?: string): CanopyAgent[] {
  // When a workspace is specified, return only its agents (empty if none deployed)
  if (workspaceId) {
    return workspaceAgents.get(workspaceId) ?? [];
  }
  // No workspace context — return default dev agents
  return AGENTS;
}

export function mockAgentById(
  id: string,
  workspaceId?: string,
): CanopyAgent | undefined {
  const pool = mockAgents(workspaceId);
  return pool.find((a) => a.id === id);
}
