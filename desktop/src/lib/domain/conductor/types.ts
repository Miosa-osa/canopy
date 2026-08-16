/**
 * Conductor domain types — match the structured tool-call results emitted by
 * `Canopy.Tools.Build` when invoked by Conductor (the Build cockpit's
 * primary chat agent + runtime delegator).
 *
 * Every Build tool returns a JSON-serializable map whose `action` field
 * tells the frontend which Mosaic mutation to apply. The types below are a
 * discriminated union on the `action` field, so the `BuildDispatcher` can
 * pattern-match exhaustively and TS narrows each branch automatically.
 *
 * The dispatcher itself is agent-agnostic — any agent that invokes a
 * `build.*` tool produces results the dispatcher honors — but in practice
 * Conductor is the agent emitting them, hence the naming.
 *
 * Source of truth — handlers in `backend/lib/canopy/tools/build.ex`:
 *   open_pane, split_pane, close_pane, focus_pane,
 *   suggest_layout, save_layout, load_layout,
 *   open_file (returns open_pane), open_block (returns open_pane),
 *   run_command (returns open_pane), set_density, list_layouts.
 *
 * Note: `open_file`, `open_block`, and `run_command` are emitters that
 * produce `{ action: "open_pane", pane_kind: ..., config: ... }` — they do
 * NOT have their own action variants. Same for `suggest_layout` /
 * `list_layouts` which return query results, not layout mutations; the
 * dispatcher ignores them.
 */

import type { Density } from "$lib/domain/build/types.js";

// ── Pane kinds emitted by Conductor ──────────────────────────────────────────

/**
 * Pane kinds produced by Conductor's tool surface (backend taxonomy).
 *
 * The frontend Mosaic store (`mosaic-layout.svelte.ts`) uses a slightly
 * different `PaneKind` enum (legacy: session/issue/task/doc/...). The
 * dispatcher maps backend kinds to the closest mosaic kind via
 * `mapBackendPaneKind` — see `build-dispatcher.svelte.ts`.
 */
export type ConductorPaneKind =
  | "terminal"
  | "block_stream"
  | "code_editor"
  | "file_viewer"
  | "diff"
  | "mcp";

export type ConductorSplitDirection = "left" | "right" | "up" | "down";

// ── Action discriminated union ───────────────────────────────────────────────

/**
 * Open a new pane in the active tile. Emitted by `build.open_pane`,
 * `build.open_file`, `build.open_block`, `build.run_command`.
 */
export interface OpenPaneAction {
  action: "open_pane";
  pane_kind: ConductorPaneKind;
  config: Record<string, unknown>;
}

/**
 * Split an existing pane into two. Emitted by `build.split_pane`. The new
 * pane goes on the side indicated by `direction`.
 */
export interface SplitPaneAction {
  action: "split_pane";
  pane_id: string;
  direction: ConductorSplitDirection;
  new_pane_kind: ConductorPaneKind;
  new_config: Record<string, unknown>;
}

/** Close a pane in the active layout. Emitted by `build.close_pane`. */
export interface ClosePaneAction {
  action: "close_pane";
  pane_id: string;
}

/** Move focus to a specific pane. Emitted by `build.focus_pane`. */
export interface FocusPaneAction {
  action: "focus_pane";
  pane_id: string;
}

/**
 * Replace the active layout with the provided saved layout JSON. Emitted by
 * `build.load_layout`. The frontend dispatcher applies density / title
 * format prefs from the saved layout if present; the layout tree itself is
 * loaded via the existing `mosaicLayout.load(slug)` localStorage path.
 */
export interface LoadLayoutAction {
  action: "load_layout";
  slug: string;
  scope: string;
  /** Opaque Mosaic tree — same shape the frontend persists to localStorage. */
  layout_json: Record<string, unknown>;
  density: Density | null;
  pane_title_format: string | null;
}

/**
 * Acknowledgement that a layout was saved. Emitted by `build.save_layout`.
 * The dispatcher does not mutate the Mosaic store on save — the user's
 * current layout is already correct — but it's a recognized action for
 * toasts / telemetry.
 */
export interface SaveLayoutAction {
  action: "save_layout";
  slug: string;
  scope: string;
  id: string;
}

/** Set the active pane density preference. Emitted by `build.set_density`. */
export interface SetDensityAction {
  action: "set_density";
  level: Density;
}

/**
 * Embed a runtime (Claude Code, Codex, Gemini, ...) into the active pane.
 * Emitted by `runtime.spawn`. The dispatcher writes
 * `pane.config.embeddedRuntime` so the existing EmbeddedRuntime pane
 * picks the session up — no new component path.
 */
export interface EmbedRuntimeAction {
  action: "embed_runtime";
  runtime_type: string;
  session_id: string;
  embed_into_pane: true;
  cwd?: string | null;
}

/**
 * Apply a skill to the active conversation. Emitted by the Skills picker
 * chip. The dispatcher relays this to the active pane's conversation
 * context — no Mosaic mutation required.
 */
export interface ApplySkillAction {
  action: "apply_skill";
  skill_slug: string;
  /** Optional session id when the dispatch site already knows it. */
  session_id?: string | null;
}

/**
 * Instantiate a template into the active workspace. Emitted by the
 * Templates picker chip. The dispatcher emits a navigation request the
 * SvelteKit router honors — actual instantiation runs through the
 * Templates super-module's existing endpoints.
 */
export interface InstantiateTemplateAction {
  action: "instantiate_template";
  template_slug: string;
  workspace_slug?: string | null;
}

/**
 * Discriminated union of every action Conductor can emit that the frontend
 * dispatcher knows how to apply. Anything outside this union is logged as a
 * warning by the dispatcher and ignored.
 */
export type ConductorAction =
  | OpenPaneAction
  | SplitPaneAction
  | ClosePaneAction
  | FocusPaneAction
  | LoadLayoutAction
  | SaveLayoutAction
  | SetDensityAction
  | EmbedRuntimeAction
  | ApplySkillAction
  | InstantiateTemplateAction;

/**
 * Top-level wrapper for a Conductor tool-call result that arrives via SSE
 * or a direct tool dispatch response.
 */
export interface ConductorToolResult {
  /** Optional tool name for logging — e.g. "build.split_pane". */
  tool?: string;
  /** Optional run id from the orchestrator. */
  run_id?: string;
  /** The action payload emitted by the tool handler. */
  result: ConductorAction;
}

// ── Type guards ──────────────────────────────────────────────────────────────

/**
 * Loose runtime check that `value` is a plausible Conductor action — has a
 * string `action` field. The dispatcher's per-action branches do their own
 * field validation; this guard only protects against `null`/`undefined` /
 * non-objects being passed in from the wire.
 */
export function isConductorAction(value: unknown): value is ConductorAction {
  return (
    typeof value === "object" &&
    value !== null &&
    typeof (value as { action?: unknown }).action === "string"
  );
}
