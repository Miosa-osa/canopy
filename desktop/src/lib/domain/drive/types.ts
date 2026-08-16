/**
 * Drive domain types — match Elixir backend structs at /api/v1/drive/*.
 * Keys arrive camelCased via the client conversion layer.
 *
 * Drive is the unified shell of typed knowledge entries. An entry's `kind`
 * selects how to interpret `body` — for link kinds (workflow, notebook,
 * env_vars, mcp_server) the body is a foreign-key envelope to an existing
 * primitive; for `prompt` and `rule` the body holds the standalone content.
 */

export type DriveKind =
  | "folder"
  | "workflow"
  | "prompt"
  | "notebook"
  | "env_vars"
  | "mcp_server"
  | "rule";

export type DriveScope = "personal" | "team";

// ── Body shapes per kind ─────────────────────────────────────────────────────

export interface FolderBody {
  // Folders are pure organizational containers — body is empty.
  [key: string]: unknown;
}

export interface WorkflowBody {
  routine_id: string;
}

export interface PromptBody {
  body: string;
  variables?: Array<{ name: string; default?: string; description?: string }>;
}

export interface NotebookBody {
  session_id: string;
  block_ids?: string[];
}

export interface EnvVarsBody {
  vault_secret_ids: string[];
}

export interface MCPServerBody {
  mcp_server_id: string;
}

export interface RuleBody {
  body: string;
  applies_to?: string[];
}

export type DriveBody =
  | FolderBody
  | WorkflowBody
  | PromptBody
  | NotebookBody
  | EnvVarsBody
  | MCPServerBody
  | RuleBody;

// ── Entry ────────────────────────────────────────────────────────────────────

export interface DriveEntry {
  id: string;
  slug: string;
  name: string;
  kind: DriveKind;
  scope: DriveScope;
  parentId: string | null;
  body: Record<string, unknown>;
  ownerId: string | null;
  tags: string[];
  position: number;
  archivedAt: string | null;
  insertedAt: string;
  updatedAt: string;
}

export interface DriveTreeNode {
  entry: DriveEntry;
  children: DriveTreeNode[];
}

export interface DriveTree {
  scope: DriveScope;
  data: DriveTreeNode[];
}

// ── Inputs ───────────────────────────────────────────────────────────────────

export interface DriveEntryCreate {
  slug: string;
  name: string;
  kind: DriveKind;
  scope: DriveScope;
  parentId?: string | null;
  body?: Record<string, unknown>;
  tags?: string[];
}

export interface DriveEntryUpdate {
  name?: string;
  body?: Record<string, unknown>;
  tags?: string[];
}

export interface DriveListQuery {
  scope?: DriveScope;
  parentId?: string | "root";
  kind?: DriveKind;
  archived?: "true" | "false" | "all";
  limit?: number;
}

export interface DriveSearchQuery {
  scope?: DriveScope;
  kind?: DriveKind;
  limit?: number;
}
