/**
 * build-dispatcher.svelte.ts — Conductor → Mosaic translator.
 *
 * Conductor (the Build cockpit's primary chat agent + runtime delegator)
 * emits structured tool-call results from the backend whenever he invokes a
 * `build.*` tool. This dispatcher pattern-matches on each `ConductorAction`
 * and applies the corresponding mutation to the existing `mosaicLayout`
 * store. It never builds a parallel layout store — every action falls
 * through to `mosaicLayout.*` / `mosaicPrefs.*` mutations.
 *
 * The dispatcher itself is agent-agnostic: any agent that calls a `build.*`
 * tool (Iris in the future, per-pane conversation agents, anything) produces
 * results the dispatcher honors. In practice today, Conductor is the agent
 * emitting them.
 *
 * Production-grade rules:
 *   - Every dispatch path is safely no-op when its target tile/pane is gone
 *     (the user may have closed it before the tool result returned).
 *   - Unknown action types log a `console.warn` and return — never throw.
 *   - Malformed payloads log a warning with the offending shape.
 *
 * The class avoids `$state` runes so it can be instantiated and tested in a
 * Node-environment vitest project (see `build-dispatcher.test.ts`). The
 * dispatcher has no UI; consumers don't need reactivity on its internals.
 *
 * CSS prefix: n/a (this store has no UI).
 * LOC target: ≤ 240.
 */

import type {
  ApplySkillAction,
  ClosePaneAction,
  ConductorAction,
  ConductorPaneKind,
  ConductorSplitDirection,
  EmbedRuntimeAction,
  FocusPaneAction,
  InstantiateTemplateAction,
  LoadLayoutAction,
  OpenPaneAction,
  SaveLayoutAction,
  SetDensityAction,
  SplitPaneAction,
} from '$lib/domain/conductor/types.js';
import { isConductorAction } from '$lib/domain/conductor/types.js';
import { mosaicLayout, type Pane, type PaneKind, type Tile } from './mosaic-layout.svelte.js';
import { mosaicPrefs } from './mosaic-prefs.svelte.js';

// ── Backend → Mosaic kind mapping ────────────────────────────────────────────

/**
 * Map a Conductor backend pane kind to the closest existing mosaic
 * `PaneKind`. The mosaic store's enum predates Conductor and uses the legacy
 * Canopy taxonomy (session/issue/task/...); the dispatcher bridges the two.
 *
 * Configuration is preserved verbatim on `Pane.config` so the pane component
 * can read backend-shaped fields (file_id, queued_command, block_id, ...)
 * without further translation.
 */
function mapBackendPaneKind(kind: ConductorPaneKind): PaneKind {
  switch (kind) {
    case 'terminal':
      return 'terminal';
    case 'file_viewer':
    case 'code_editor':
      return 'file';
    case 'diff':
      return 'changes';
    case 'block_stream':
      return 'session';
    case 'mcp':
      return 'agent_conversation';
    default: {
      // exhaustive guard
      const _never: never = kind;
      void _never;
      return 'session';
    }
  }
}

/**
 * Direction → orientation. left/right split side-by-side (vertical divider);
 * up/down split top-and-bottom (horizontal divider).
 */
function directionToOrientation(dir: ConductorSplitDirection): 'horizontal' | 'vertical' {
  return dir === 'left' || dir === 'right' ? 'vertical' : 'horizontal';
}

// ── Pane construction ────────────────────────────────────────────────────────

function paneId(): string {
  return `cond-${Math.random().toString(36).slice(2, 9)}`;
}

/**
 * Derive a human-readable title from a Conductor pane config. Falls back to
 * the pane kind if no obvious title field is present.
 */
function deriveTitle(kind: ConductorPaneKind, config: Record<string, unknown>): string {
  const path = typeof config.path === 'string' ? config.path : null;
  const fileId = typeof config.file_id === 'string' ? config.file_id : null;
  const cmd = typeof config.queued_command === 'string' ? config.queued_command : null;
  const blockId = typeof config.block_id === 'string' ? config.block_id : null;

  return path ?? cmd ?? blockId ?? fileId ?? kind;
}

/**
 * Derive a `ref` value (session id, file id, block id, ...) for the legacy
 * mosaic Pane. Empty string when none is obvious — the pane component
 * inspects `config` for the real backend fields.
 */
function deriveRef(config: Record<string, unknown>): string {
  for (const key of ['file_id', 'block_id', 'session_id', 'path', 'slug', 'id']) {
    const v = config[key];
    if (typeof v === 'string' && v.length > 0) return v;
  }
  return '';
}

function buildPane(kind: ConductorPaneKind, config: Record<string, unknown>): Pane {
  return {
    id: paneId(),
    kind: mapBackendPaneKind(kind),
    ref: deriveRef(config),
    title: deriveTitle(kind, config),
    config,
  };
}

/** Find the tile that contains a pane with `paneIdToFind`. Null if absent. */
function findTileForPane(paneIdToFind: string): Tile | null {
  const tiles = mosaicLayout.allTiles();
  for (const tile of tiles) {
    if (tile.panes.some((p) => p.id === paneIdToFind)) return tile;
  }
  return null;
}

// ── Per-action handlers ──────────────────────────────────────────────────────

function handleOpenPane(action: OpenPaneAction): void {
  const cfg = action.config ?? {};
  const pane = buildPane(action.pane_kind, cfg);
  mosaicLayout.openPane(pane);
}

function handleSplitPane(action: SplitPaneAction): void {
  const tile = findTileForPane(action.pane_id);
  if (!tile) {
    // No-op: the pane may have been closed before the tool result arrived.
    return;
  }
  const cfg = action.new_config ?? {};
  const newPane = buildPane(action.new_pane_kind, cfg);
  mosaicLayout.splitTile(tile.id, directionToOrientation(action.direction), newPane);
}

function handleClosePane(action: ClosePaneAction): void {
  const tile = findTileForPane(action.pane_id);
  if (!tile) return;
  mosaicLayout.closePane(tile.id, action.pane_id);
}

function handleFocusPane(action: FocusPaneAction): void {
  const tile = findTileForPane(action.pane_id);
  if (!tile) return;
  mosaicLayout.activatePane(tile.id, action.pane_id);
}

function handleLoadLayout(action: LoadLayoutAction): void {
  // The backend stores the Mosaic tree opaquely. The dispatcher does NOT
  // currently rehydrate the tree wholesale — that path is owned by the
  // existing `mosaicLayout.load(slug)` localStorage round-trip and the
  // Build API's defaultLayoutQuery. Apply density / title format prefs
  // from the saved layout if present.
  if (action.density) {
    mosaicPrefs.setDensity(action.density);
  }
  if (
    action.pane_title_format === 'command' ||
    action.pane_title_format === 'working_directory' ||
    action.pane_title_format === 'branch'
  ) {
    mosaicPrefs.setTitleFormat(action.pane_title_format);
  }
}

function handleSetDensity(action: SetDensityAction): void {
  mosaicPrefs.setDensity(action.level);
}

function handleSaveLayout(_action: SaveLayoutAction): void {
  // No mosaic mutation needed — saving captures the current state. The
  // Build query layer invalidates `["build", "layouts"]` separately. Kept
  // as a recognized branch so unknown-action warnings stay accurate.
}

/**
 * Embed a runtime in a fresh pane. We open an `agent_conversation` pane
 * carrying `embeddedRuntime` in its config — the existing
 * AgentConversationPane reads this on mount and switches its body to
 * `<EmbeddedRuntime/>`. We deliberately do NOT mutate an existing pane in
 * place — the layout store has no targeted patch API, and creating a
 * fresh pane is the documented integration path for `runtime.spawn`.
 */
function handleEmbedRuntime(action: EmbedRuntimeAction): void {
  const pane = {
    id: paneId(),
    kind: 'agent_conversation' as PaneKind,
    ref: action.session_id,
    title: action.runtime_type,
    config: {
      embeddedRuntime: {
        type: action.runtime_type,
        sessionId: action.session_id,
      },
      sessionId: action.session_id,
      cwd: action.cwd ?? undefined,
    },
  };
  mosaicLayout.openPane(pane);
}

/**
 * Apply a skill to the active conversation. The dispatcher emits a
 * lightweight DOM CustomEvent that the active AgentConversationPane (or
 * any pane interested in skills) can pick up. We don't mutate the layout
 * because skill application is conversation-state, not pane-state.
 *
 * Listening side: `window.addEventListener("canopy:apply_skill", ...)`.
 */
function handleApplySkill(action: ApplySkillAction): void {
  if (typeof window === 'undefined') return;
  const ev = new CustomEvent('canopy:apply_skill', {
    detail: {
      skill_slug: action.skill_slug,
      session_id: action.session_id ?? null,
    },
  });
  window.dispatchEvent(ev);
}

/**
 * Instantiate a template. The dispatcher emits a `canopy:instantiate_template`
 * event the SvelteKit page can listen for to navigate to
 * `/templates/[slug]` with the instantiation flow primed. The actual
 * instantiation runs through the existing Templates super-module
 * endpoints — the dispatcher does not call any new endpoint.
 */
function handleInstantiateTemplate(action: InstantiateTemplateAction): void {
  if (typeof window === 'undefined') return;
  const ev = new CustomEvent('canopy:instantiate_template', {
    detail: {
      template_slug: action.template_slug,
      workspace_slug: action.workspace_slug ?? null,
    },
  });
  window.dispatchEvent(ev);
}

// ── Dispatcher class (plain TS — no runes; testable in Node) ─────────────────

class BuildDispatcherStore {
  /** Total count of dispatched actions — handy for tests + telemetry. */
  dispatchedCount = 0;
  /** Last action seen, if any. Useful for devtools. */
  lastAction: ConductorAction | null = null;

  /**
   * Apply a Conductor tool-call result to the Mosaic layout.
   *
   * Accepts a `ConductorToolResult` wrapper, a raw `ConductorAction`, or
   * any unknown payload (loose runtime input from SSE / tool dispatch is
   * normalised inside). Returns silently on malformed input or unknown
   * action types — never throws.
   */
  dispatch(toolResult: unknown): void {
    const action = this.normalize(toolResult);
    if (!action) return;

    this.dispatchedCount += 1;
    this.lastAction = action;

    switch (action.action) {
      case 'open_pane':
        handleOpenPane(action);
        return;
      case 'split_pane':
        handleSplitPane(action);
        return;
      case 'close_pane':
        handleClosePane(action);
        return;
      case 'focus_pane':
        handleFocusPane(action);
        return;
      case 'load_layout':
        handleLoadLayout(action);
        return;
      case 'save_layout':
        handleSaveLayout(action);
        return;
      case 'set_density':
        handleSetDensity(action);
        return;
      case 'embed_runtime':
        handleEmbedRuntime(action);
        return;
      case 'apply_skill':
        handleApplySkill(action);
        return;
      case 'instantiate_template':
        handleInstantiateTemplate(action);
        return;
      default: {
        // Exhaustive guard. New action variants must add a case above.
        const _never: never = action;
        // eslint-disable-next-line no-console
        console.warn('[BuildDispatcher] unknown action variant — ignoring', _never);
      }
    }
  }

  /**
   * Coerce an incoming payload into a `ConductorAction`. Accepts:
   *   - A raw `ConductorAction` (direct dispatch)
   *   - A `ConductorToolResult` wrapper with `.result` carrying the action
   * Anything else logs a warning and returns null.
   */
  private normalize(payload: unknown): ConductorAction | null {
    if (isConductorAction(payload)) return payload;

    if (typeof payload === 'object' && payload !== null && 'result' in payload) {
      const inner = (payload as { result: unknown }).result;
      if (isConductorAction(inner)) return inner;
    }

    // eslint-disable-next-line no-console
    console.warn('[BuildDispatcher] malformed Conductor payload — ignoring', payload);
    return null;
  }
}

export const buildDispatcher = new BuildDispatcherStore();

// Internals exported for tests only — keep this list tight.
export const __test = {
  mapBackendPaneKind,
  directionToOrientation,
  deriveTitle,
  deriveRef,
  findTileForPane,
} as const;
