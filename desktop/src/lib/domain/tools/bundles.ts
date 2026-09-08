/**
 * Tool bundles — logical groupings of tools users can select as a unit during
 * agent creation/configuration. Pure data, zero side effects.
 */

import type { CapabilityPreset } from '../agents/config.js';
import type { Tool } from './types.js';

export interface ToolBundle {
  id: string;
  name: string;
  description: string;
  /** Tool names in this bundle — matched against Tool.name from the API. */
  tools: string[];
  /** Suggested capability preset when this bundle is selected. */
  suggestedCapabilities?: CapabilityPreset;
}

export interface ToolBundleGroup {
  id: string;
  label: string;
  bundles: ToolBundle[];
}

// ── Bundle definitions ────────────────────────────────────────────────────────

export const TOOL_BUNDLE_GROUPS: ToolBundleGroup[] = [
  {
    id: 'code-files',
    label: 'Code & Files',
    bundles: [
      {
        id: 'file-operations',
        name: 'File Operations',
        description: 'Read, write, and edit files; search by content and path.',
        tools: ['Read', 'Write', 'Edit', 'Grep', 'Glob'],
        suggestedCapabilities: 'developer',
      },
      {
        id: 'code-analysis',
        name: 'Code Analysis',
        description: 'Read and search the codebase without making any changes.',
        tools: ['Read', 'Grep', 'Glob'],
        suggestedCapabilities: 'reviewer',
      },
    ],
  },
  {
    id: 'shell-system',
    label: 'Shell & System',
    bundles: [
      {
        id: 'shell-access',
        name: 'Shell Access',
        description: 'Execute arbitrary shell and process commands.',
        tools: ['Bash', 'exec'],
        suggestedCapabilities: 'developer',
      },
      {
        id: 'git-operations',
        name: 'Git Operations',
        description: 'Run git commands, open and merge pull requests.',
        tools: ['git', 'CreatePR', 'MergePR'],
      },
    ],
  },
  {
    id: 'ai-agents',
    label: 'AI & Agents',
    bundles: [
      {
        id: 'agent-management',
        name: 'Agent Management',
        description: 'Spawn sub-agents and coordinate tasks across them.',
        tools: ['Agent', 'SendMessage', 'TaskCreate', 'TaskUpdate'],
      },
      {
        id: 'planning',
        name: 'Planning',
        description: 'Enter and exit plan mode; create structured task plans.',
        tools: ['EnterPlanMode', 'ExitPlanMode', 'TaskCreate'],
      },
    ],
  },
  {
    id: 'web-network',
    label: 'Web & Network',
    bundles: [
      {
        id: 'web-access',
        name: 'Web Access',
        description: 'Search the web and fetch remote URLs.',
        tools: ['WebSearch', 'WebFetch'],
      },
      {
        id: 'mcp-tools',
        name: 'MCP Tools',
        description: 'Tools provided by connected MCP servers.',
        tools: ['mcp__'],
      },
    ],
  },
  {
    id: 'utilities',
    label: 'Utilities',
    bundles: [
      {
        id: 'notebook',
        name: 'Notebook',
        description: 'Edit Jupyter-style notebook cells.',
        tools: ['NotebookEdit'],
      },
      {
        id: 'monitoring',
        name: 'Monitoring',
        description: 'Monitor processes and schedule recurring or deferred work.',
        tools: ['Monitor', 'CronCreate', 'CronList', 'ScheduleWakeup'],
      },
    ],
  },
];

// ── Helper functions ──────────────────────────────────────────────────────────

/**
 * Flattens all tool names across the given bundles into a unique set.
 */
export function getAllToolNames(bundles: ToolBundle[]): string[] {
  return [...new Set(bundles.flatMap((b) => b.tools))];
}

/**
 * Returns every bundle (across all groups) that contains the given tool name.
 * MCP tools are matched by prefix (`mcp__`).
 */
export function getBundlesForTool(toolName: string, groups: ToolBundleGroup[]): ToolBundle[] {
  const allBundles = groups.flatMap((g) => g.bundles);
  return allBundles.filter((bundle) =>
    bundle.tools.some((t) => (t.endsWith('__') ? toolName.startsWith(t) : t === toolName))
  );
}

/**
 * Splits a tool list into:
 * - `bundled`: Map<bundleId, Tool[]> — tools that belong to at least one bundle
 * - `unbundled`: Tool[] — tools with no matching bundle
 */
export function categorizeTools(
  tools: Tool[],
  groups: ToolBundleGroup[]
): { bundled: Map<string, Tool[]>; unbundled: Tool[] } {
  const bundled = new Map<string, Tool[]>();
  const unbundled: Tool[] = [];

  for (const tool of tools) {
    const matchingBundles = getBundlesForTool(tool.name, groups);
    if (matchingBundles.length === 0) {
      unbundled.push(tool);
    } else {
      for (const bundle of matchingBundles) {
        const existing = bundled.get(bundle.id) ?? [];
        existing.push(tool);
        bundled.set(bundle.id, existing);
      }
    }
  }

  return { bundled, unbundled };
}
