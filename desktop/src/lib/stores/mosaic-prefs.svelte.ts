/**
 * mosaic-prefs.svelte.ts — Mosaic shell user preferences.
 * Svelte 5 runes class store, persisted to localStorage `canopy.mosaic.prefs`.
 * Drives MosaicSettings popover + tab strip density / title format / hover card.
 *
 * Backward compatibility:
 *   If the `canopy.mosaic.prefs` key is missing or malformed, defaults are used.
 *   The Mosaic tree (`canopy.mosaic.<slug>`) is independent and unaffected.
 *
 * LOC target: ≤ 160.
 */

export type MosaicViewMode = "panes" | "tabs";
export type MosaicDensity = "compact" | "comfortable" | "roomy";
export type MosaicTitleFormat = "command" | "working_directory" | "branch";
export type MosaicMetadataField =
  | "branch"
  | "working_directory"
  | "agent"
  | "runtime"
  | "model";

export interface MosaicPrefs {
  /** Where the Mosaic shows its content. `panes` = tiled split view (current). `tabs` = single tile, all panes as tabs. */
  view_mode: MosaicViewMode;
  /** Tab density. Affects vertical/horizontal tab padding and metadata visibility. */
  density: MosaicDensity;
  /** What the tab title text shows. */
  pane_title_format: MosaicTitleFormat;
  /** Which extra metadata fields render under the title (in `roomy` density) and inside the hover card. */
  metadata_fields: MosaicMetadataField[];
  /** When true, hovering a tab reveals a `TabHoverCard` with full pane metadata. */
  show_details_on_hover: boolean;
}

const LS_KEY = "canopy.mosaic.prefs";

export const defaultPrefs: MosaicPrefs = {
  view_mode: "panes",
  density: "comfortable",
  pane_title_format: "command",
  metadata_fields: ["branch"],
  show_details_on_hover: true,
};

const VIEW_MODES: readonly MosaicViewMode[] = ["panes", "tabs"];
const DENSITIES: readonly MosaicDensity[] = ["compact", "comfortable", "roomy"];
const TITLE_FORMATS: readonly MosaicTitleFormat[] = [
  "command",
  "working_directory",
  "branch",
];
const METADATA_FIELDS: readonly MosaicMetadataField[] = [
  "branch",
  "working_directory",
  "agent",
  "runtime",
  "model",
];

// ── Pure helpers (exported for tests) ─────────────────────────────────────────

/**
 * Validate + coerce a possibly-malformed parsed object into a safe MosaicPrefs.
 * Unknown values fall back to defaults — never throw.
 */
export function sanitize(raw: unknown): MosaicPrefs {
  if (!raw || typeof raw !== "object") return { ...defaultPrefs };
  const r = raw as Partial<Record<keyof MosaicPrefs, unknown>>;

  const view_mode = (VIEW_MODES as readonly string[]).includes(
    r.view_mode as string,
  )
    ? (r.view_mode as MosaicViewMode)
    : defaultPrefs.view_mode;

  const density = (DENSITIES as readonly string[]).includes(r.density as string)
    ? (r.density as MosaicDensity)
    : defaultPrefs.density;

  const pane_title_format = (TITLE_FORMATS as readonly string[]).includes(
    r.pane_title_format as string,
  )
    ? (r.pane_title_format as MosaicTitleFormat)
    : defaultPrefs.pane_title_format;

  const fields: MosaicMetadataField[] = Array.isArray(r.metadata_fields)
    ? (r.metadata_fields as unknown[]).filter((f): f is MosaicMetadataField =>
        (METADATA_FIELDS as readonly string[]).includes(f as string),
      )
    : [...defaultPrefs.metadata_fields];

  const show_details_on_hover =
    typeof r.show_details_on_hover === "boolean"
      ? r.show_details_on_hover
      : defaultPrefs.show_details_on_hover;

  return {
    view_mode,
    density,
    pane_title_format,
    metadata_fields: fields,
    show_details_on_hover,
  };
}

export function loadPrefs(): MosaicPrefs {
  try {
    if (typeof localStorage === "undefined") return { ...defaultPrefs };
    const raw = localStorage.getItem(LS_KEY);
    if (!raw) return { ...defaultPrefs };
    return sanitize(JSON.parse(raw));
  } catch {
    return { ...defaultPrefs };
  }
}

export function savePrefs(prefs: MosaicPrefs): void {
  try {
    if (typeof localStorage === "undefined") return;
    localStorage.setItem(LS_KEY, JSON.stringify(prefs));
  } catch {
    // Quota exceeded or private mode — silently ignore.
  }
}

export function resetPrefs(): void {
  try {
    if (typeof localStorage === "undefined") return;
    localStorage.removeItem(LS_KEY);
  } catch {
    // ignore
  }
}

// ── Store class ───────────────────────────────────────────────────────────────

class MosaicPrefsStore {
  prefs = $state<MosaicPrefs>({ ...defaultPrefs });

  constructor() {
    if (typeof localStorage !== "undefined") {
      this.prefs = loadPrefs();
    }
  }

  setViewMode(mode: MosaicViewMode): void {
    this.prefs.view_mode = mode;
    savePrefs(this.prefs);
  }

  setDensity(density: MosaicDensity): void {
    this.prefs.density = density;
    savePrefs(this.prefs);
  }

  setTitleFormat(format: MosaicTitleFormat): void {
    this.prefs.pane_title_format = format;
    savePrefs(this.prefs);
  }

  toggleMetadataField(field: MosaicMetadataField): void {
    const exists = this.prefs.metadata_fields.includes(field);
    this.prefs.metadata_fields = exists
      ? this.prefs.metadata_fields.filter((f) => f !== field)
      : [...this.prefs.metadata_fields, field];
    savePrefs(this.prefs);
  }

  setShowDetailsOnHover(show: boolean): void {
    this.prefs.show_details_on_hover = show;
    savePrefs(this.prefs);
  }

  reset(): void {
    this.prefs = { ...defaultPrefs };
    resetPrefs();
  }
}

export const mosaicPrefs = new MosaicPrefsStore();
