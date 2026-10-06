import { browser } from "$app/environment";
import type {
  WorkbenchLayout,
  WorkbenchMode,
  WorkbenchTile,
  WorkbenchTileType,
  WorkbenchViewport,
} from "$lib/types/workbench";
import { WORKBENCH_TILE_DEFINITIONS } from "$lib/types/workbench";

const STORAGE_KEY_PREFIX = "canopy-workbench-layout-v1";

function defaultLayout(): WorkbenchLayout {
  return {
    version: 1,
    mode: "canvas",
    activeTileId: "tile-terminal",
    viewport: { x: 0, y: 0, scale: 1 },
    tiles: [
      {
        id: "tile-terminal",
        type: "terminal",
        title: WORKBENCH_TILE_DEFINITIONS.terminal.title,
        x: 24,
        y: 24,
        width: 620,
        height: 360,
        zIndex: 1,
      },
      {
        id: "tile-chat",
        type: "chat",
        title: WORKBENCH_TILE_DEFINITIONS.chat.title,
        x: 672,
        y: 24,
        width: 420,
        height: 520,
        zIndex: 2,
      },
      {
        id: "tile-sessions",
        type: "sessions",
        title: WORKBENCH_TILE_DEFINITIONS.sessions.title,
        x: 24,
        y: 412,
        width: 520,
        height: 420,
        zIndex: 3,
      },
      {
        id: "tile-files",
        type: "files",
        title: WORKBENCH_TILE_DEFINITIONS.files.title,
        x: 568,
        y: 572,
        width: 340,
        height: 420,
        zIndex: 4,
      },
      {
        id: "tile-tmux-ide",
        type: "tmux",
        title: WORKBENCH_TILE_DEFINITIONS.tmux.title,
        x: 1116,
        y: 24,
        width: 560,
        height: 520,
        zIndex: 5,
      },
    ],
  };
}

function isTileType(value: unknown): value is WorkbenchTileType {
  return (
    value === "terminal" ||
    value === "tmux" ||
    value === "chat" ||
    value === "sessions" ||
    value === "files"
  );
}

function sanitizeViewport(value: unknown): WorkbenchViewport {
  if (!value || typeof value !== "object") return { x: 0, y: 0, scale: 1 };
  const raw = value as Partial<WorkbenchViewport>;
  return {
    x: clampNumber(raw.x, -8000, 8000, 0),
    y: clampNumber(raw.y, -8000, 8000, 0),
    scale: clampFloat(raw.scale, 0.45, 1.5, 1),
  };
}

function sanitizeTile(value: unknown, fallbackZ: number): WorkbenchTile | null {
  if (!value || typeof value !== "object") return null;
  const raw = value as Partial<WorkbenchTile>;
  if (typeof raw.id !== "string" || !raw.id.trim()) return null;
  if (!isTileType(raw.type)) return null;

  const definition = WORKBENCH_TILE_DEFINITIONS[raw.type];
  return {
    id: raw.id,
    type: raw.type,
    title: typeof raw.title === "string" && raw.title.trim() ? raw.title : definition.title,
    x: clampNumber(raw.x, 0, 4000, 24),
    y: clampNumber(raw.y, 0, 4000, 24),
    width: clampNumber(raw.width, 280, 1400, definition.defaultWidth),
    height: clampNumber(raw.height, 220, 1000, definition.defaultHeight),
    zIndex: clampNumber(raw.zIndex, 1, 9999, fallbackZ),
    minimized: raw.minimized === true,
  };
}

function clampNumber(value: unknown, min: number, max: number, fallback: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  return Math.min(max, Math.max(min, Math.round(value)));
}

function clampFloat(value: unknown, min: number, max: number, fallback: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  return Math.min(max, Math.max(min, Number(value.toFixed(2))));
}

function sanitizeLayout(value: unknown): WorkbenchLayout {
  if (!value || typeof value !== "object") return defaultLayout();
  const raw = value as Partial<WorkbenchLayout>;
  const tiles = Array.isArray(raw.tiles)
    ? raw.tiles
        .map((tile, index) => sanitizeTile(tile, index + 1))
        .filter((tile): tile is WorkbenchTile => tile !== null)
    : [];

  if (tiles.length === 0) return defaultLayout();

  const activeTileId =
    typeof raw.activeTileId === "string" && tiles.some((tile) => tile.id === raw.activeTileId)
      ? raw.activeTileId
      : tiles[0]?.id ?? null;

  return {
    version: 1,
    mode: raw.mode === "split" ? "split" : "canvas",
    tiles,
    activeTileId,
    viewport: sanitizeViewport(raw.viewport),
  };
}

class WorkbenchStore {
  layout = $state<WorkbenchLayout>(defaultLayout());
  loaded = $state(false);
  error = $state<string | null>(null);
  private storageKey = `${STORAGE_KEY_PREFIX}:default`;

  get tiles(): WorkbenchTile[] {
    return [...this.layout.tiles].sort((a, b) => a.zIndex - b.zIndex);
  }

  get activeTile(): WorkbenchTile | null {
    return this.layout.tiles.find((tile) => tile.id === this.layout.activeTileId) ?? null;
  }

  load(workspaceKey = "default"): void {
    if (!browser) return;
    this.storageKey = `${STORAGE_KEY_PREFIX}:${workspaceKey || "default"}`;
    try {
      const raw = localStorage.getItem(this.storageKey);
      this.layout = raw ? sanitizeLayout(JSON.parse(raw)) : defaultLayout();
      this.error = null;
    } catch (e) {
      this.layout = defaultLayout();
      this.error = (e as Error).message;
    } finally {
      this.loaded = true;
    }
  }

  save(): void {
    if (!browser) return;
    try {
      localStorage.setItem(this.storageKey, JSON.stringify(this.layout));
      this.error = null;
    } catch (e) {
      this.error = (e as Error).message;
    }
  }

  setMode(mode: WorkbenchMode): void {
    this.layout = { ...this.layout, mode };
    this.save();
  }

  setViewport(viewport: WorkbenchViewport): void {
    this.layout = {
      ...this.layout,
      viewport: sanitizeViewport(viewport),
    };
  }

  commitViewport(): void {
    this.save();
  }

  resetViewport(): void {
    this.layout = {
      ...this.layout,
      viewport: { x: 0, y: 0, scale: 1 },
    };
    this.save();
  }

  addTile(type: WorkbenchTileType): void {
    const definition = WORKBENCH_TILE_DEFINITIONS[type];
    const nextZ = Math.max(0, ...this.layout.tiles.map((tile) => tile.zIndex)) + 1;
    const offset = this.layout.tiles.length * 28;
    const id = `tile-${type}-${Date.now()}`;
    const tile: WorkbenchTile = {
      id,
      type,
      title: definition.title,
      x: Math.max(24, Math.round((120 - this.layout.viewport.x) / this.layout.viewport.scale + offset)),
      y: Math.max(24, Math.round((80 - this.layout.viewport.y) / this.layout.viewport.scale + offset)),
      width: definition.defaultWidth,
      height: definition.defaultHeight,
      zIndex: nextZ,
    };
    this.layout = {
      ...this.layout,
      activeTileId: id,
      tiles: [...this.layout.tiles, tile],
    };
    this.save();
  }

  reset(): void {
    this.layout = defaultLayout();
    this.save();
  }

  focusTile(tileId: string): void {
    const nextZ = Math.max(0, ...this.layout.tiles.map((tile) => tile.zIndex)) + 1;
    this.layout = {
      ...this.layout,
      activeTileId: tileId,
      tiles: this.layout.tiles.map((tile) =>
        tile.id === tileId ? { ...tile, zIndex: nextZ } : tile,
      ),
    };
    this.save();
  }

  moveTile(tileId: string, x: number, y: number): void {
    this.layout = {
      ...this.layout,
      tiles: this.layout.tiles.map((tile) =>
        tile.id === tileId
          ? { ...tile, x: Math.max(0, Math.round(x)), y: Math.max(0, Math.round(y)) }
          : tile,
      ),
    };
  }

  commitPosition(): void {
    this.save();
  }

  toggleMinimized(tileId: string): void {
    this.layout = {
      ...this.layout,
      tiles: this.layout.tiles.map((tile) =>
        tile.id === tileId ? { ...tile, minimized: !tile.minimized } : tile,
      ),
    };
    this.save();
  }
}

export const workbenchStore = new WorkbenchStore();
