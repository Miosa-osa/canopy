/**
 * Agent configuration domain types.
 * Capabilities and config fields not yet in the backend schema are stored in
 * the agent's `config` jsonb blob (accessed via PATCH /agents/:slug/config
 * when that endpoint exists; otherwise stashed to localStorage as a local draft).
 */

// ── Capabilities ─────────────────────────────────────────────────────────────

/** Atomic capability strings — stored in config.capabilities[]. */
export type Capability =
  | 'read_files'
  | 'write_files'
  | 'exec_shell'
  | 'network_access'
  | 'send_email'
  | 'create_prs'
  | 'merge_prs'
  | 'modify_infrastructure';

/** Risk level per capability — drives UI warnings. */
export const CAPABILITY_RISK: Record<Capability, 'low' | 'medium' | 'high'> = {
  read_files: 'low',
  write_files: 'high',
  exec_shell: 'high',
  network_access: 'medium',
  send_email: 'medium',
  create_prs: 'low',
  merge_prs: 'medium',
  modify_infrastructure: 'high',
};

/** Human-readable labels + descriptions. */
export const CAPABILITY_META: Record<
  Capability,
  { label: string; description: string; risk_note?: string }
> = {
  read_files: {
    label: 'Read files',
    description: 'Read files from the workspace filesystem.',
  },
  write_files: {
    label: 'Write files',
    description: 'Create or modify files in the workspace.',
    risk_note: 'Can overwrite or delete files. Enable only for trusted agents.',
  },
  exec_shell: {
    label: 'Execute shell commands',
    description: 'Run arbitrary shell commands inside the agent sandbox.',
    risk_note: 'Grants full command execution. Highest-risk capability — restrict carefully.',
  },
  network_access: {
    label: 'Network access',
    description: 'Make outbound HTTP/TCP requests from the agent process.',
    risk_note: 'Agent can exfiltrate data or call external APIs.',
  },
  send_email: {
    label: 'Send email',
    description: 'Send emails via configured mail integration.',
    risk_note: 'Agent can send emails on your behalf.',
  },
  create_prs: {
    label: 'Create pull requests',
    description: 'Open new pull requests in connected Git repos.',
  },
  merge_prs: {
    label: 'Merge pull requests',
    description: 'Merge open pull requests (requires review bypass in repo settings).',
    risk_note: 'Agent can merge code without human review.',
  },
  modify_infrastructure: {
    label: 'Modify infrastructure',
    description: 'Apply infrastructure-as-code changes (Terraform, k8s manifests, etc.).',
    risk_note: 'Can alter production systems. Enable only for dedicated infra agents.',
  },
};

/** Preset bundles that map a role to a sensible capability set. */
export type CapabilityPreset = 'observer' | 'reviewer' | 'developer' | 'admin';

export const CAPABILITY_PRESETS: Record<CapabilityPreset, Capability[]> = {
  observer: [],
  reviewer: ['read_files', 'create_prs'],
  developer: ['read_files', 'write_files', 'exec_shell'],
  admin: [
    'read_files',
    'write_files',
    'exec_shell',
    'network_access',
    'send_email',
    'create_prs',
    'merge_prs',
    'modify_infrastructure',
  ],
};

export const CAPABILITY_PRESET_META: Record<
  CapabilityPreset,
  { label: string; description: string }
> = {
  observer: {
    label: 'Observer',
    description: 'No permissions — read-only agent.',
  },
  reviewer: { label: 'Code reviewer', description: 'Read files + open PRs.' },
  developer: {
    label: 'Developer',
    description: 'Read, write, and execute shell.',
  },
  admin: { label: 'Admin', description: 'Full permissions. Use sparingly.' },
};

// ── Guardrails ────────────────────────────────────────────────────────────────

export interface AgentGuardrails {
  /** Budget ID from /budgets to bind to this agent. */
  budget_id: string | null;
  /** Governance rule IDs bound to this agent. */
  rule_ids: string[];
  /** Max tokens per session. null = no limit. */
  max_tokens_per_session: number | null;
  /** Max runtime per session in seconds. null = no limit. */
  max_runtime_seconds: number | null;
}

// ── Persona ───────────────────────────────────────────────────────────────────

export interface AgentPersona {
  /** System prompt (markdown) — stored in backend persona_markdown field. */
  system_prompt: string;
  /** Category — maps to AgentCategory. */
  category: string;
  /** Free-form personality trait tags. */
  traits: string[];
}

// ── Config blob ───────────────────────────────────────────────────────────────

/**
 * The `config` jsonb blob on the Agent schema.
 * All UI-managed fields that have no dedicated backend column live here.
 * PATCH /agents/:slug/config is the target endpoint (may not exist yet — see agents.ts).
 */
export interface AgentConfig {
  /** Capability permission list. */
  capabilities: Capability[];
  /** Knowledge base slugs assigned to this agent (supplement to KB assignment API). */
  kb_slugs: string[];
  /** Skill slugs toggled on for this agent. */
  skill_slugs: string[];
  /** Guardrail settings. */
  guardrails: AgentGuardrails;
  /** Persona trait tags — supplements persona_markdown. */
  persona_traits: string[];
}

export const DEFAULT_AGENT_CONFIG: AgentConfig = {
  capabilities: [],
  kb_slugs: [],
  skill_slugs: [],
  guardrails: {
    budget_id: null,
    rule_ids: [],
    max_tokens_per_session: null,
    max_runtime_seconds: null,
  },
  persona_traits: [],
};
