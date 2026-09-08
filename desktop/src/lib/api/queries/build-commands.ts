/**
 * TanStack Query factory for the multi-source slash-command registry.
 *
 * Backed by `GET /api/v1/build/commands`. Each row aggregates from one of
 * five sources (builtin / runtime / drive_workflow / drive_prompt /
 * template / skill) and arrives in a single normalized shape — see
 * `BuildCommand` below.
 */

import { apiGet } from '$lib/api/client.js';

export type BuildCommandSource =
  | 'builtin'
  | 'runtime'
  | 'drive_workflow'
  | 'drive_prompt'
  | 'template'
  | 'skill';

export type BuildCommandNamespace = 'build' | 'runtimes' | 'drive' | 'templates' | 'skills';

/**
 * Normalized slash command. Mirrors `Canopy.Build.Commands.command` on the
 * backend — every source is mapped onto this shape so the palette can render
 * uniformly and the dispatcher can pattern-match on `source`.
 */
export interface BuildCommand {
  namespace: BuildCommandNamespace;
  /** Slash command including the leading `/` — render and dispatch verbatim. */
  name: string;
  description: string;
  /** lucide-svelte icon name. */
  icon: string;
  source: BuildCommandSource;
  /** Drive entry id, template slug, runtime type, skill slug — null for built-ins. */
  source_id: string | null;
}

export interface CommandsQueryOpts {
  /** Substring filter applied to name + description, case-insensitive. */
  q?: string;
  /** Hard-capped at 200 server-side. */
  limit?: number;
}

/**
 * Query factory for the slash-command palette. Pass directly to
 * `createQuery()` from `@tanstack/svelte-query`.
 */
export function commandsQuery(opts: CommandsQueryOpts = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ['build', 'commands', opts] as const,
    queryFn: async () => {
      const response = await apiGet<{ data?: BuildCommand[] }>(`/build/commands${qs}`);
      if (!Array.isArray(response.data)) return [...FALLBACK_BUILTINS];
      return response.data;
    },
    // Slash palette is opened frequently; re-fetch on focus is overkill.
    staleTime: 30_000,
  };
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function buildQuery(opts: object): string {
  const entries = Object.entries(opts as Record<string, unknown>).filter(
    ([, v]) => v !== undefined && v !== null && v !== ''
  );
  if (entries.length === 0) return '';

  const params = new URLSearchParams();
  for (const [key, value] of entries) {
    params.set(key, String(value));
  }
  return `?${params.toString()}`;
}

/**
 * Group helper: bucket a command list by `source` in the canonical display
 * order. Returns `[label, commands][]` so the palette can render a
 * `<section>` per group without re-sorting in the template.
 */
const SOURCE_ORDER: BuildCommandSource[] = [
  'builtin',
  'runtime',
  'drive_workflow',
  'drive_prompt',
  'template',
  'skill',
];

const SOURCE_LABELS: Record<BuildCommandSource, string> = {
  builtin: 'BUILT-IN',
  runtime: 'RUNTIMES',
  drive_workflow: 'DRIVE — WORKFLOWS',
  drive_prompt: 'DRIVE — PROMPTS',
  template: 'TEMPLATES',
  skill: 'SKILLS',
};

export function groupBySource(
  commands: readonly BuildCommand[]
): Array<{ source: BuildCommandSource; label: string; items: BuildCommand[] }> {
  const buckets = new Map<BuildCommandSource, BuildCommand[]>();
  for (const cmd of commands) {
    const bucket = buckets.get(cmd.source) ?? [];
    bucket.push(cmd);
    buckets.set(cmd.source, bucket);
  }

  const result: Array<{
    source: BuildCommandSource;
    label: string;
    items: BuildCommand[];
  }> = [];
  for (const source of SOURCE_ORDER) {
    const items = buckets.get(source);
    if (items && items.length > 0) {
      result.push({ source, label: SOURCE_LABELS[source], items });
    }
  }
  return result;
}

/**
 * Fallback set used when the commands query errors. Matches the canonical
 * built-ins on the backend so the palette never renders empty on a network
 * blip — the user can still type `/agent` and get something sensible.
 */
export const FALLBACK_BUILTINS: readonly BuildCommand[] = [
  {
    namespace: 'build',
    name: '/agent',
    description: 'Start a new conversation',
    icon: 'Bot',
    source: 'builtin',
    source_id: null,
  },
  {
    namespace: 'build',
    name: '/plan',
    description: 'Prompt the agent to do some research',
    icon: 'Sparkles',
    source: 'builtin',
    source_id: null,
  },
  {
    namespace: 'build',
    name: '/open-file',
    description: "Open a file in the workspace's code editor",
    icon: 'FileText',
    source: 'builtin',
    source_id: null,
  },
  {
    namespace: 'build',
    name: '/conversations',
    description: 'Open conversation history',
    icon: 'History',
    source: 'builtin',
    source_id: null,
  },
  {
    namespace: 'build',
    name: '/prompts',
    description: 'Search saved prompts',
    icon: 'Wand2',
    source: 'builtin',
    source_id: null,
  },
  {
    namespace: 'build',
    name: '/add-prompt',
    description: 'Add new agent prompt',
    icon: 'Plus',
    source: 'builtin',
    source_id: null,
  },
  {
    namespace: 'build',
    name: '/add-rule',
    description: 'Add a new global rule for the agent',
    icon: 'BookOpen',
    source: 'builtin',
    source_id: null,
  },
  {
    namespace: 'build',
    name: '/add-mcp',
    description: 'Add new MCP server',
    icon: 'Plug',
    source: 'builtin',
    source_id: null,
  },
  {
    namespace: 'build',
    name: '/create-environment',
    description: 'Create a sandbox environment',
    icon: 'GitBranch',
    source: 'builtin',
    source_id: null,
  },
  {
    namespace: 'build',
    name: '/review',
    description: 'Open code review',
    icon: 'MessageCircle',
    source: 'builtin',
    source_id: null,
  },
];
