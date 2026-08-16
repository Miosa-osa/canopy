/**
 * keybindings.svelte.ts — Editable keybindings store.
 * Svelte 5 runes class store, persisted to localStorage `canopy:keybindings`.
 *
 * Chord format: sorted modifiers + key, e.g. "Meta+Shift+d", "Meta+k".
 * Modifiers are always sorted: Alt < Ctrl < Meta < Shift.
 *
 * LOC target: ≤ 300.
 */

export interface KeyBinding {
  id: string;
  label: string;
  category: string;
  defaultChord: string;
  custom?: string;
}

/** Returns the active chord for a binding (custom overrides default). */
function activeChord(b: KeyBinding): string {
  return b.custom ?? b.defaultChord;
}

// ── Default bindings ──────────────────────────────────────────────────────────

const DEFAULT_BINDINGS: Omit<KeyBinding, "custom">[] = [
  // Global
  {
    id: "global.commandPalette",
    label: "Open command palette",
    category: "Global",
    defaultChord: "Meta+k",
  },
  {
    id: "global.openSettings",
    label: "Open settings",
    category: "Global",
    defaultChord: "Meta+,",
  },
  {
    id: "global.toggleTheme",
    label: "Toggle dark / light mode",
    category: "Global",
    defaultChord: "Meta+Shift+d",
  },
  {
    id: "global.toggleSidebar",
    label: "Toggle sidebar",
    category: "Global",
    defaultChord: "Meta+Shift+l",
  },
  {
    id: "global.dismiss",
    label: "Close / dismiss overlay",
    category: "Global",
    defaultChord: "Escape",
  },

  // Navigation
  {
    id: "nav.dashboard",
    label: "Go to Dashboard",
    category: "Navigation",
    defaultChord: "Meta+1",
  },
  {
    id: "nav.runtimes",
    label: "Go to Runtimes",
    category: "Navigation",
    defaultChord: "Meta+2",
  },
  {
    id: "nav.sessions",
    label: "Go to Sessions",
    category: "Navigation",
    defaultChord: "Meta+3",
  },
  {
    id: "nav.agents",
    label: "Go to Agents",
    category: "Navigation",
    defaultChord: "Meta+4",
  },
  {
    id: "nav.workspaces",
    label: "Go to Workspaces",
    category: "Navigation",
    defaultChord: "Meta+5",
  },

  // Mosaic
  {
    id: "mosaic.newPane",
    label: "Open new pane picker",
    category: "Mosaic",
    defaultChord: "Meta+t",
  },
  {
    id: "mosaic.closePane",
    label: "Close active pane",
    category: "Mosaic",
    defaultChord: "Meta+w",
  },
  {
    id: "mosaic.splitRight",
    label: "Split pane right",
    category: "Mosaic",
    defaultChord: "Meta+d",
  },
  {
    id: "mosaic.splitDown",
    label: "Split pane down",
    category: "Mosaic",
    defaultChord: "Meta+Shift+d",
  },
  {
    id: "mosaic.splitVertical",
    label: "Split tile vertically",
    category: "Mosaic",
    defaultChord: "Meta+\\",
  },
  {
    id: "mosaic.splitHorizontal",
    label: "Split tile horizontally",
    category: "Mosaic",
    defaultChord: "Meta+Shift+|",
  },
  {
    id: "mosaic.nextPane",
    label: "Next pane in tile",
    category: "Mosaic",
    defaultChord: "Meta+Shift+]",
  },
  {
    id: "mosaic.prevPane",
    label: "Previous pane in tile",
    category: "Mosaic",
    defaultChord: "Meta+Shift+[",
  },
  {
    id: "mosaic.nextTile",
    label: "Focus next tile",
    category: "Mosaic",
    defaultChord: "Meta+Shift+ArrowRight",
  },
  {
    id: "mosaic.prevTile",
    label: "Focus previous tile",
    category: "Mosaic",
    defaultChord: "Meta+Shift+ArrowLeft",
  },
  {
    id: "mosaic.cycleNextTab",
    label: "Cycle to next tab",
    category: "Mosaic",
    defaultChord: "Meta+Tab",
  },
  {
    id: "mosaic.cyclePrevTab",
    label: "Cycle to previous tab",
    category: "Mosaic",
    defaultChord: "Meta+Shift+Tab",
  },

  // Editor
  {
    id: "editor.save",
    label: "Save changes",
    category: "Editor",
    defaultChord: "Meta+s",
  },
  {
    id: "editor.undo",
    label: "Undo",
    category: "Editor",
    defaultChord: "Meta+z",
  },
  {
    id: "editor.redo",
    label: "Redo",
    category: "Editor",
    defaultChord: "Meta+Shift+z",
  },
  {
    id: "editor.toggleComment",
    label: "Toggle comment",
    category: "Editor",
    defaultChord: "Meta+/",
  },

  // Sessions
  {
    id: "sessions.new",
    label: "New session",
    category: "Sessions",
    defaultChord: "Meta+n",
  },
  {
    id: "sessions.close",
    label: "Close active session",
    category: "Sessions",
    defaultChord: "Meta+Shift+w",
  },
];

// ── Persistence ───────────────────────────────────────────────────────────────

const LS_KEY = "canopy:keybindings";

type PersistedOverrides = Record<string, string>;

function loadOverrides(): PersistedOverrides {
  try {
    if (typeof localStorage === "undefined") return {};
    const raw = localStorage.getItem(LS_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw) as unknown;
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
      return {};
    // Keep only string values
    return Object.fromEntries(
      Object.entries(parsed as Record<string, unknown>).filter(
        ([, v]) => typeof v === "string",
      ) as [string, string][],
    );
  } catch {
    return {};
  }
}

function saveOverrides(overrides: PersistedOverrides): void {
  try {
    if (typeof localStorage === "undefined") return;
    localStorage.setItem(LS_KEY, JSON.stringify(overrides));
  } catch {
    // Quota / private mode — silently ignore.
  }
}

// ── Store class ───────────────────────────────────────────────────────────────

class KeybindingsStore {
  bindings = $state<KeyBinding[]>([]);

  constructor() {
    const overrides = loadOverrides();
    this.bindings = DEFAULT_BINDINGS.map((b) => ({
      ...b,
      custom: overrides[b.id],
    }));
  }

  /** Returns the active chord for the given action id. */
  getChord(actionId: string): string {
    const b = this.bindings.find((x) => x.id === actionId);
    return b ? activeChord(b) : "";
  }

  /** Set a custom chord for the given action. Persists immediately. */
  setChord(actionId: string, chord: string): void {
    const b = this.bindings.find((x) => x.id === actionId);
    if (!b) return;
    b.custom = chord === b.defaultChord ? undefined : chord;
    this._persist();
  }

  /** Remove any custom override for the given action. */
  resetToDefault(actionId: string): void {
    const b = this.bindings.find((x) => x.id === actionId);
    if (!b) return;
    b.custom = undefined;
    this._persist();
  }

  /** Remove all custom overrides. */
  resetAll(): void {
    for (const b of this.bindings) b.custom = undefined;
    this._persist();
  }

  /**
   * Returns the binding that already uses `chord`, excluding `excludeId`.
   * Used for conflict detection during capture.
   */
  hasConflict(chord: string, excludeId?: string): KeyBinding | null {
    const normalised = chord.toLowerCase();
    return (
      this.bindings.find(
        (b) =>
          b.id !== excludeId && activeChord(b).toLowerCase() === normalised,
      ) ?? null
    );
  }

  private _persist(): void {
    const overrides: PersistedOverrides = {};
    for (const b of this.bindings) {
      if (b.custom !== undefined) overrides[b.id] = b.custom;
    }
    saveOverrides(overrides);
  }
}

export const keybindings = new KeybindingsStore();

// ── Chord capture utility (pure — no Svelte dependency) ──────────────────────

const MODIFIER_ORDER = ["Alt", "Ctrl", "Meta", "Shift"] as const;
const MODIFIER_KEYS = new Set(["Alt", "Control", "Meta", "Shift"]);

/** Maps KeyboardEvent.key values to canonical modifier names. */
function toModifierLabel(key: string): string | null {
  switch (key) {
    case "Control":
      return "Ctrl";
    case "Meta":
      return "Meta";
    case "Alt":
      return "Alt";
    case "Shift":
      return "Shift";
    default:
      return null;
  }
}

/**
 * Capture a KeyboardEvent into a canonical chord string.
 * Returns null if the event is a bare modifier keypress (no non-modifier key).
 *
 * Examples:
 *   Cmd+K       → "Meta+k"
 *   Cmd+Shift+D → "Meta+Shift+d"
 *   Escape      → "Escape"
 */
export function captureChord(e: KeyboardEvent): string | null {
  if (MODIFIER_KEYS.has(e.key)) return null; // bare modifier press — ignore

  const mods: string[] = [];
  if (e.altKey) mods.push("Alt");
  if (e.ctrlKey) mods.push("Ctrl");
  if (e.metaKey) mods.push("Meta");
  if (e.shiftKey) mods.push("Shift");

  // Sort modifiers into canonical order
  mods.sort(
    (a, b) =>
      MODIFIER_ORDER.indexOf(a as (typeof MODIFIER_ORDER)[number]) -
      MODIFIER_ORDER.indexOf(b as (typeof MODIFIER_ORDER)[number]),
  );

  // Normalise key: single chars lowercase, special keys keep their name
  const key = e.key.length === 1 ? e.key.toLowerCase() : e.key;

  return mods.length > 0 ? `${mods.join("+")}+${key}` : key;
}

/**
 * Format a chord string for display as an array of key token strings.
 * "Meta+Shift+d" → ["⌘", "⇧", "D"]
 */
export function chordToDisplayTokens(chord: string): string[] {
  return chord.split("+").map((part) => {
    switch (part) {
      case "Meta":
        return "⌘";
      case "Ctrl":
        return "⌃";
      case "Alt":
        return "⌥";
      case "Shift":
        return "⇧";
      default:
        return part.length === 1 ? part.toUpperCase() : part;
    }
  });
}
