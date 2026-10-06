// src/lib/utils/template-parser.ts
// Utilities for parsing agent markdown files with YAML frontmatter.

import type { CanopyAgent, AdapterType } from "$api/types";

/** Raw result of parsing a YAML frontmatter block */
export interface ParsedFrontmatter {
  frontmatter: Record<string, unknown>;
  /** The markdown body (system prompt) following the closing --- delimiter */
  body: string;
}

/**
 * Parse YAML frontmatter from a markdown agent file content string.
 * Supports the subset of YAML used in Canopy agent files:
 *   - Quoted strings: "value"
 *   - Arrays: [a, b, c]
 *   - Numbers: 500
 *   - Null values: null
 *   - Bare strings (unquoted)
 */
export function parseAgentFrontmatter(content: string): ParsedFrontmatter {
  // Match --- delimited YAML frontmatter at the start of the file
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!match) return { frontmatter: {}, body: content };

  const yaml = match[1];
  const body = match[2];
  const frontmatter: Record<string, unknown> = {};

  for (const line of yaml.split("\n")) {
    // Support key: value and key: "value" — skip indented/continuation lines
    const kvMatch = line.match(/^(\w[\w-]*):\s*(.*?)\s*$/);
    if (!kvMatch) continue;
    const [, key, rawValue] = kvMatch;

    frontmatter[key] = coerceYamlValue(rawValue.trim());
  }

  return { frontmatter, body };
}

/**
 * Coerce a raw YAML scalar string into the appropriate JS type.
 */
function coerceYamlValue(raw: string): unknown {
  if (raw === "" || raw === "null" || raw === "~") return null;
  if (raw === "true") return true;
  if (raw === "false") return false;

  // Quoted string
  if (
    (raw.startsWith('"') && raw.endsWith('"')) ||
    (raw.startsWith("'") && raw.endsWith("'"))
  ) {
    return raw.slice(1, -1);
  }

  // Inline array: [a, b, c] or ["a", "b"]
  if (raw.startsWith("[") && raw.endsWith("]")) {
    const inner = raw.slice(1, -1).trim();
    if (inner === "") return [];
    return inner.split(",").map((s) => {
      const trimmed = s.trim();
      return coerceYamlValue(trimmed) as string;
    });
  }

  // Number
  const asNum = Number(raw);
  if (!isNaN(asNum) && raw !== "") return asNum;

  // Bare string
  return raw;
}

/**
 * Normalise an adapter string from frontmatter to a valid AdapterType.
 * The markdown files use formats like "claude_code" or "claude-code".
 */
function normaliseAdapter(raw: unknown): AdapterType {
  if (typeof raw !== "string") return "claude_code";
  const normalised = raw.replace(/-/g, "_");
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
  return valid.includes(normalised as AdapterType)
    ? (normalised as AdapterType)
    : "claude_code";
}

/**
 * Convert parsed frontmatter and markdown body into a CanopyAgent object.
 * The `id` field in the returned agent is prefixed with "tpl-" so it does not
 * collide with backend-assigned IDs.
 */
export function frontmatterToAgent(
  frontmatter: Record<string, unknown>,
  body: string,
): CanopyAgent {
  const now = new Date().toISOString();
  const rawId = (frontmatter["id"] as string | undefined) ?? "unknown";

  return {
    id: `tpl-${rawId}`,
    name: rawId,
    display_name: (frontmatter["name"] as string | undefined) ?? rawId,
    avatar_emoji: (frontmatter["emoji"] as string | undefined) ?? "🤖",
    role: (frontmatter["role"] as string | undefined) ?? "agent",
    status: "idle",
    adapter: normaliseAdapter(frontmatter["adapter"]),
    model:
      typeof frontmatter["model"] === "string" && frontmatter["model"]
        ? frontmatter["model"]
        : "claude-sonnet-4-20250514",
    system_prompt: body.trim(),
    config: {
      division: (frontmatter["division"] as string | null | undefined) ?? null,
      reportsTo:
        (frontmatter["reportsTo"] as string | null | undefined) ?? null,
      budget:
        typeof frontmatter["budget"] === "number" ? frontmatter["budget"] : 400,
      color:
        typeof frontmatter["color"] === "string"
          ? frontmatter["color"]
          : "#94a3b8",
      signal: (frontmatter["signal"] as string | undefined) ?? "",
      title:
        (frontmatter["title"] as string | undefined) ??
        (frontmatter["name"] as string | undefined) ??
        rawId,
    },
    skills: Array.isArray(frontmatter["skills"])
      ? (frontmatter["skills"] as string[])
      : [],
    team_id: null,
    schedule_id: null,
    budget_policy_id: null,
    current_task: null,
    last_active_at: now,
    token_usage_today: { input: 0, output: 0, cache_read: 0, cache_write: 0 },
    cost_today_cents: 0,
    created_at: now,
    updated_at: now,
  };
}

/**
 * Parse a raw markdown string (with YAML frontmatter) into a CanopyAgent.
 */
export function parseAgentFile(content: string): CanopyAgent {
  const { frontmatter, body } = parseAgentFrontmatter(content);
  return frontmatterToAgent(frontmatter, body);
}
