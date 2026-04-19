/**
 * Tool domain types — matches the Elixir backend at /api/v1/tools.
 * Backend endpoints:
 *   GET  /api/v1/tools           — list all registered tools
 *   GET  /api/v1/tools/:name     — tool detail
 *   POST /api/v1/tools/:name/dispatch — execute a tool
 */

/** A registered tool available to agents. */
export interface Tool {
  name: string;
  description: string | null;
  /** Input schema JSON — describes expected args shape. */
  inputSchema: Record<string, unknown> | null;
}

/** Body for POST /api/v1/tools/:name/dispatch */
export interface ToolDispatchBody {
  /** Arguments to pass to the tool. Shape validated against inputSchema. */
  args: Record<string, unknown>;
  /** Optional session context for the dispatch. */
  sessionId?: string;
}

/** Response from POST /api/v1/tools/:name/dispatch */
export interface ToolDispatchResult {
  output: string;
  isError: boolean;
}
