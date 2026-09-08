/**
 * TanStack Query factories for the /tools resource.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 *
 * Backend endpoints:
 *   GET  /api/v1/tools               — list all registered tools
 *   GET  /api/v1/tools/:name         — tool detail
 *   POST /api/v1/tools/:name/dispatch — execute a tool
 */

import { apiGet, apiPost } from '$lib/api/client.js';
import type { Tool, ToolDispatchBody, ToolDispatchResult } from '$lib/domain/tools/types.js';

// ── Raw API calls ────────────────────────────────────────────────────────────

export function listTools(): Promise<Tool[]> {
  return apiGet<Tool[]>('/tools');
}

export function getTool(name: string): Promise<Tool> {
  return apiGet<Tool>(`/tools/${name}`);
}

export function dispatchTool(name: string, body: ToolDispatchBody): Promise<ToolDispatchResult> {
  return apiPost<ToolDispatchResult>(`/tools/${name}/dispatch`, body);
}

// ── TanStack Query option factories ─────────────────────────────────────────

/** Query options for the full list of registered tools. */
export function toolsQuery() {
  return {
    queryKey: ['tools'] as const,
    queryFn: () => listTools(),
    staleTime: 60_000,
  };
}

/** Query options for a single tool by name. */
export function toolQuery(name: string) {
  return {
    queryKey: ['tools', name] as const,
    queryFn: () => getTool(name),
    staleTime: 60_000,
    enabled: Boolean(name),
  };
}

/** Mutation options to dispatch (execute) a tool. */
export function dispatchToolMutation() {
  return {
    mutationKey: ['tools', 'dispatch'] as const,
    mutationFn: ({ name, body }: { name: string; body: ToolDispatchBody }) =>
      dispatchTool(name, body),
  };
}
