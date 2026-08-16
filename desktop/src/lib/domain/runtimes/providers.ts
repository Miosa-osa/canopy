/**
 * Provider config — unified declaration for all runtime providers.
 *
 * Pure data file. Zero side effects. Import freely.
 *
 * Covers: Claude Code (claude-local), Codex CLI, Gemini CLI.
 * Extend by pushing into PROVIDERS and re-exporting.
 */

// ── Interfaces ───────────────────────────────────────────────────────────────

export interface ModelConfig {
  /** Stable identifier used in API calls, e.g. "opus-4" */
  id: string;
  /** Human-readable display name */
  name: string;
  contextWindow: number;
  costTier: "low" | "medium" | "high" | "elite";
  supportsThinking?: boolean;
  /** [min, max] tokens for extended thinking budget */
  thinkingBudgetRange?: [number, number];
}

export interface ModeConfig {
  /** Stable mode identifier */
  id: string;
  name: string;
  description: string;
}

export interface ProviderConfig {
  /** Stable provider identifier — matches runtimeType on sessions */
  id: string;
  /** Human-readable display name */
  name: string;
  models: ModelConfig[];
  modes: ModeConfig[];
  /** Fine-grained capability flags */
  capabilities: string[];
  defaultModel: string;
  defaultMode: string;
}

// ── Provider definitions ─────────────────────────────────────────────────────

const claudeLocal: ProviderConfig = {
  id: "claude-local",
  name: "Claude Code",
  capabilities: ["tool_use", "streaming", "thinking", "vision"],
  defaultModel: "sonnet-4",
  defaultMode: "agent",
  modes: [
    {
      id: "agent",
      name: "Agent",
      description: "Autonomous multi-step task execution with tool use",
    },
    {
      id: "chat",
      name: "Chat",
      description: "Interactive conversation without autonomous actions",
    },
  ],
  models: [
    {
      id: "opus-4",
      name: "Claude Opus 4",
      contextWindow: 200_000,
      costTier: "elite",
      supportsThinking: true,
      thinkingBudgetRange: [1_024, 32_000],
    },
    {
      id: "sonnet-4",
      name: "Claude Sonnet 4",
      contextWindow: 200_000,
      costTier: "high",
      supportsThinking: true,
      thinkingBudgetRange: [1_024, 16_000],
    },
    {
      id: "haiku-3-5",
      name: "Claude Haiku 3.5",
      contextWindow: 200_000,
      costTier: "low",
      supportsThinking: false,
    },
  ],
};

const codexCli: ProviderConfig = {
  id: "codex",
  name: "Codex CLI",
  capabilities: ["tool_use", "streaming"],
  defaultModel: "o4-mini",
  defaultMode: "agent",
  modes: [
    {
      id: "agent",
      name: "Agent",
      description: "Autonomous coding agent with file and shell access",
    },
  ],
  models: [
    {
      id: "o3",
      name: "OpenAI o3",
      contextWindow: 200_000,
      costTier: "elite",
    },
    {
      id: "o4-mini",
      name: "OpenAI o4-mini",
      contextWindow: 200_000,
      costTier: "medium",
    },
  ],
};

const geminiCli: ProviderConfig = {
  id: "gemini-cli",
  name: "Gemini CLI",
  capabilities: ["tool_use", "streaming", "vision"],
  defaultModel: "gemini-2.5-flash",
  defaultMode: "agent",
  modes: [
    {
      id: "agent",
      name: "Agent",
      description: "Autonomous agent with tool use and large context",
    },
    { id: "chat", name: "Chat", description: "Interactive conversation mode" },
  ],
  models: [
    {
      id: "gemini-2.5-pro",
      name: "Gemini 2.5 Pro",
      contextWindow: 1_000_000,
      costTier: "high",
    },
    {
      id: "gemini-2.5-flash",
      name: "Gemini 2.5 Flash",
      contextWindow: 1_000_000,
      costTier: "low",
    },
  ],
};

// ── Registry ─────────────────────────────────────────────────────────────────

export const PROVIDERS: ProviderConfig[] = [claudeLocal, codexCli, geminiCli];

export const DEFAULT_PROVIDER: string = "claude-local";

// ── Lookup helpers ───────────────────────────────────────────────────────────

export function getProvider(id: string): ProviderConfig | undefined {
  return PROVIDERS.find((p) => p.id === id);
}

export function getModel(
  providerId: string,
  modelId: string,
): ModelConfig | undefined {
  return getProvider(providerId)?.models.find((m) => m.id === modelId);
}
