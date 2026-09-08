/**
 * TanStack Query factories for the MCP Tools pane.
 *
 * All endpoints already exist in the Phoenix router — this module is a thin
 * read layer:
 *   GET  /api/v1/tools                         — registered tool list
 *   GET  /api/v1/tools/:name                   — tool detail
 *   POST /api/v1/agents/tools/:tool_name       — dispatch (test invocation)
 *   GET  /api/v1/mcp/tool-calls                — global invocation log (added)
 *   GET  /api/v1/mcp/servers                   — connected MCP servers (stub, added)
 *
 * The dispatch helper here intentionally targets the *agent* dispatcher, not
 * the registry-only `/tools/:name/dispatch`, so test invocations flow through
 * the same governance/budget/audit pipeline as production agent calls.
 */

import { apiGet, apiPost } from '$lib/api/client.js';
import type {
  McpServer,
  RegisteredTool,
  ToolDispatchRequest,
  ToolDispatchResponse,
  ToolInvocation,
} from '$lib/domain/mcp/types.js';

// ── Raw API calls ────────────────────────────────────────────────────────────

/** GET /api/v1/tools — full registered tool list. */
export function listRegisteredTools(opts?: {
  mcpExposed?: boolean;
  promptExposed?: boolean;
}): Promise<RegisteredTool[]> {
  const qs = buildQuery(opts ?? {});
  return apiGet<{ data: RegisteredTool[] }>(`/tools${qs}`).then((r) => r.data);
}

/** GET /api/v1/tools/:name — single tool detail. */
export function getRegisteredTool(name: string): Promise<RegisteredTool> {
  return apiGet<RegisteredTool>(`/tools/${encodeURIComponent(name)}`);
}

/** POST /api/v1/agents/tools/:tool_name — dispatch via the agent path. */
export function dispatchToolCall(
  toolName: string,
  body: ToolDispatchRequest
): Promise<ToolDispatchResponse> {
  return apiPost<ToolDispatchResponse>(`/agents/tools/${encodeURIComponent(toolName)}`, body);
}

/** GET /api/v1/mcp/tool-calls — global invocation log (cross-agent). */
export function listToolInvocations(opts?: {
  status?: 'ok' | 'error' | 'pending_review';
  limit?: number;
}): Promise<ToolInvocation[]> {
  const qs = buildQuery(opts ?? {});
  return apiGet<{ data: ToolInvocation[] }>(`/mcp/tool-calls${qs}`).then((r) => r.data);
}

/** GET /api/v1/mcp/servers — Phase A stub returns empty list. */
export function listMcpServers(): Promise<McpServer[]> {
  return apiGet<{ data: McpServer[] }>(`/mcp/servers`).then((r) => r.data);
}

// ── TanStack Query option factories ─────────────────────────────────────────

/** Query options for the registered tool list. */
export function registeredToolsQuery(opts?: { mcpExposed?: boolean; promptExposed?: boolean }) {
  return {
    queryKey: ['mcp', 'tools', opts ?? {}] as const,
    queryFn: () => listRegisteredTools(opts),
    staleTime: 60_000,
  };
}

/** Query options for a single tool by name. */
export function registeredToolQuery(name: string) {
  return {
    queryKey: ['mcp', 'tools', name] as const,
    queryFn: () => getRegisteredTool(name),
    staleTime: 60_000,
    enabled: Boolean(name),
  };
}

/** Query options for the global tool-call invocation log. Polled every 5s. */
export function toolInvocationsQuery(opts?: {
  status?: 'ok' | 'error' | 'pending_review';
  limit?: number;
}) {
  return {
    queryKey: ['mcp', 'tool-calls', opts ?? {}] as const,
    queryFn: () => listToolInvocations(opts),
    staleTime: 2_000,
    refetchInterval: 5_000,
  };
}

/** Query options for the MCP server list. */
export function mcpServersQuery() {
  return {
    queryKey: ['mcp', 'servers'] as const,
    queryFn: () => listMcpServers(),
    staleTime: 30_000,
  };
}

/** Mutation options for dispatching a tool call (test invocation). */
export function dispatchToolMutation() {
  return {
    mutationKey: ['mcp', 'tools', 'dispatch'] as const,
    mutationFn: ({ toolName, body }: { toolName: string; body: ToolDispatchRequest }) =>
      dispatchToolCall(toolName, body),
  };
}

// ── Helpers ─────────────────────────────────────────────────────────────────

function buildQuery(opts: Record<string, unknown>): string {
  const params = new URLSearchParams();
  for (const [k, v] of Object.entries(opts)) {
    if (v === undefined || v === null || v === '') continue;
    // Cap limit at 1000 to match backend convention.
    if (k === 'limit' && typeof v === 'number') {
      params.set(k, String(Math.min(Math.max(1, Math.floor(v)), 1000)));
      continue;
    }
    params.set(toSnake(k), String(v));
  }
  const qs = params.toString();
  return qs ? `?${qs}` : '';
}

function toSnake(s: string): string {
  return s.replace(/[A-Z]/g, (c) => `_${c.toLowerCase()}`);
}
