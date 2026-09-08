/**
 * MCP Tools pane domain types.
 *
 * Reuses the existing `/api/v1/tools` endpoint (backed by
 * `Canopy.Tools.Registry`). The Tool shape here mirrors the controller's
 * `serialize_tool/1` payload more fully than `domain/tools/types.ts`
 * (which only exposes name/description/inputSchema for older callers).
 *
 * No parallel registry is introduced — all data flows through the existing
 * registry, agent tool dispatcher, and ToolCalls audit context.
 */

/**
 * JSON Schema fragment for a tool's parameters. Always an `object` schema with
 * a `properties` map and optional `required` list.
 */
export interface ToolParametersSchema {
  type?: string;
  properties?: Record<string, ToolParam>;
  required?: string[];
  [key: string]: unknown;
}

/** Single property entry inside a tool's `parameters.properties` map. */
export interface ToolParam {
  type?: string;
  description?: string;
  enum?: string[];
  default?: unknown;
  format?: string;
  items?: ToolParam;
  [key: string]: unknown;
}

/** Registered tool — matches CanopyWeb.ToolsController serialize_tool/1. */
export interface RegisteredTool {
  name: string;
  description: string | null;
  parameters: ToolParametersSchema | null;
  requires: string[];
  mcpExposed: boolean;
  promptExposed: boolean;
}

/** Stub MCP server entry. Phase B: replaced by real connection records. */
export interface McpServer {
  id: string;
  name: string;
  url: string | null;
  status: 'connected' | 'disconnected' | 'error';
  toolCount: number;
}

/**
 * One row from `Canopy.Agents.ToolCalls.list/1` — persistent invocation log.
 * This is the source of truth for the InvocationLog feed (cross-session,
 * cross-agent). Per-run breadcrumbs remain available via the Analytics pane.
 */
export interface ToolInvocation {
  id: string;
  sessionId: string | null;
  runId: string | null;
  agentId: string | null;
  toolName: string;
  params: Record<string, unknown>;
  result: Record<string, unknown> | null;
  status: 'ok' | 'error' | 'pending_review';
  error: string | null;
  reviewId: string | null;
  insertedAt: string;
}

/** Body for POST /api/v1/agents/tools/:tool_name (existing endpoint). */
export interface ToolDispatchRequest {
  sessionId: string;
  params: Record<string, unknown>;
}

/** Response shape from POST /api/v1/agents/tools/:tool_name. */
export interface ToolDispatchResponse {
  ok: boolean;
  result?: unknown;
  error?: string;
  pendingReview?: boolean;
  reviewId?: string;
}

/** Group of tools sharing the same dot-prefix namespace. */
export interface ToolGroup {
  namespace: string;
  tools: RegisteredTool[];
}
