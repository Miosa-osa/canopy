/**
 * Build domain types — match the Elixir backend at /api/v1/build/*.
 * Build is Canopy's agentic development cockpit at /build — it composes
 * Mosaic, Block Stream, Code Editor, File Viewer, Diff, Terminal, MCP, and
 * the Composer footer into one operational environment.
 *
 * Keys arrive camelCased via the client conversion layer.
 */

export type BuildLayoutScope = "personal" | "team" | "workspace";

export type Density = "compact" | "comfortable" | "roomy";

export type PaneTitleFormat = "command" | "cwd" | "branch";

export type BuildPaneKind =
  | "terminal"
  | "block_stream"
  | "code_editor"
  | "file_viewer"
  | "diff"
  | "mcp";

/**
 * The opaque Mosaic-tree shape persisted on a saved layout. The shape is
 * authored client-side (see `mosaic-layout.svelte.ts`); the backend stores
 * it verbatim as JSON. Treated as opaque here so the cockpit can evolve the
 * tree shape without forcing a backend migration.
 */
export type BuildLayoutTree = Record<string, unknown>;

export interface BuildLayout {
  id: string;
  slug: string;
  name: string;
  scope: BuildLayoutScope;
  ownerId: string | null;
  workspaceSlug: string | null;
  layoutJson: BuildLayoutTree;
  defaultPaneKind: BuildPaneKind | null;
  density: Density;
  paneTitleFormat: PaneTitleFormat;
  description: string | null;
  archivedAt: string | null;
  lastUsedAt: string | null;
  useCount: number;
  insertedAt: string;
  updatedAt: string;
}

export interface BuildLayoutCreate {
  slug: string;
  name: string;
  scope?: BuildLayoutScope;
  ownerId?: string;
  workspaceSlug?: string;
  layoutJson?: BuildLayoutTree;
  defaultPaneKind?: BuildPaneKind;
  density?: Density;
  paneTitleFormat?: PaneTitleFormat;
  description?: string;
}

export interface BuildLayoutUpdate {
  name?: string;
  layoutJson?: BuildLayoutTree;
  defaultPaneKind?: BuildPaneKind;
  density?: Density;
  paneTitleFormat?: PaneTitleFormat;
  description?: string;
}

export interface BuildSuggestionItem {
  slug: string;
  name: string;
  scope: BuildLayoutScope;
  description: string | null;
  useCount: number;
  score: number;
}

export interface BuildSuggestionResult {
  intent: string;
  count: number;
  suggestions: BuildSuggestionItem[];
}

/**
 * Conductor autonomy bound — controls when Conductor acts vs asks first.
 * Stored client-side under a settings store; not persisted to backend.
 */
export type ConductorAutonomy = "auto_open" | "ask_first" | "manual_only";
