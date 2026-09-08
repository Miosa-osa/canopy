<script lang="ts">
import {
  Bot,
  Crosshair,
  GitPullRequest,
  Grid2X2,
  Hand,
  LayoutPanelTop,
  Maximize,
  Minus,
  MousePointer2,
  PanelsTopLeft,
  Plus,
  RotateCcw,
  Settings2,
  Terminal,
} from 'lucide-svelte';
import { onMount } from 'svelte';
import { activeWorkspace } from '$lib/stores/active-workspace.svelte.js';
import { defaultConfig } from '$lib/stores/sidebar-config.svelte.js';
import WorkbenchTile, {
  type WorkbenchTileKind,
  type WorkbenchTileModel,
} from './WorkbenchTile.svelte';

const STORAGE_KEY = 'canopy.workbench.spatial.v1';
const WORKBENCHES_KEY = 'canopy.workbench.canvases.v1';
const SETTINGS_KEY = 'canopy.workbench.settings.v1';
const MIN_SCALE = 0.18;
const MAX_SCALE = 2.2;
const MAX_STORED_BYTES = 600_000;
const MAX_TILES = 80;
const WORLD_LIMIT = 20_000;
const MAX_BACKGROUND_SOURCE_BYTES = 12 * 1024 * 1024;
const MAX_BACKGROUND_DATA_URL_BYTES = 2_800_000;
const MAX_BACKGROUND_DIMENSION = 2600;

const MODULES = defaultConfig.groups.flatMap((group) =>
  group.items
    .filter((item) => item.path !== '/workbench' && !item.comingSoon)
    .map((item) => ({
      label: item.label,
      route: item.path,
      subtitle: `${group.label.toLowerCase()} module`,
    }))
);

interface CanvasState {
  x: number;
  y: number;
  scale: number;
  tiles: WorkbenchTileModel[];
}

interface WorkbenchCanvas {
  id: string;
  name: string;
  state: CanvasState;
}

interface WorkbenchSettings {
  background: 'dots' | 'grid' | 'paper' | 'lines' | 'cross' | 'clean' | 'custom';
  backgroundColor: string;
  backgroundImage: string;
  backgroundImageOpacity: number;
  backgroundImageScale: number;
  backgroundScale: number;
  density: 'comfortable' | 'compact';
  tool: 'select' | 'pan';
  snap: boolean;
  showMinimap: boolean;
  terminalRuntime: string;
  terminalCwd: string;
}

const defaultTiles: WorkbenchTileModel[] = [
  {
    id: 'terminal-main',
    kind: 'terminal',
    title: 'Desktop Terminal',
    subtitle: 'local shell surface',
    x: 40,
    y: 40,
    w: 760,
    h: 460,
    z: 1,
  },
  {
    id: 'agent-team',
    kind: 'agent',
    title: 'Agent Team',
    subtitle: 'parallel workers and sub-agents',
    x: 840,
    y: 40,
    w: 680,
    h: 460,
    z: 2,
  },
  {
    id: 'git-review',
    kind: 'git',
    title: 'Git Review',
    subtitle: 'staged, unstaged, inline diff',
    x: 40,
    y: 540,
    w: 680,
    h: 440,
    z: 3,
  },
  {
    id: 'mission',
    kind: 'mission',
    title: 'Mission Control',
    subtitle: 'milestones, gates, wrap-up',
    x: 760,
    y: 540,
    w: 560,
    h: 380,
    z: 4,
  },
  {
    id: 'tmux-layout',
    kind: 'tmux',
    title: 'Tmux Layout',
    subtitle: 'split canvas template',
    x: 1360,
    y: 540,
    w: 760,
    h: 480,
    z: 5,
    panes: [],
  },
];

function cloneState(value: CanvasState): CanvasState {
  return {
    x: value.x,
    y: value.y,
    scale: value.scale,
    tiles: value.tiles.map((tile) => ({
      ...tile,
      restore: tile.restore ? { ...tile.restore } : undefined,
      panes: tile.panes?.map((pane) => ({ ...pane })),
    })),
  };
}

const initialState: CanvasState = {
  x: 72,
  y: 56,
  scale: 1,
  tiles: defaultTiles.map((tile) => ({ ...tile })),
};
let viewportEl: HTMLDivElement | null = $state(null);
let canvasState: CanvasState = $state(initialState);
let canvases: WorkbenchCanvas[] = $state([
  { id: 'main', name: 'Main', state: cloneState(initialState) },
]);
let activeCanvasId = $state('main');
let selectedId: string = $state('terminal-main');
let panStart: { pointerId: number; px: number; py: number; x: number; y: number } | null =
  $state(null);
let modulePickerOpen = $state(false);
let settingsOpen = $state(false);
let backgroundError = $state('');
let spacePanning = $state(false);
let saveTimer: number | null = null;
let settings: WorkbenchSettings = $state({
  background: 'dots',
  backgroundColor: '',
  backgroundImage: '',
  backgroundImageOpacity: 0.28,
  backgroundImageScale: 100,
  backgroundScale: 100,
  density: 'comfortable',
  tool: 'select',
  snap: true,
  showMinimap: true,
  terminalRuntime: 'claude-local',
  terminalCwd: '',
});
const activeWorkspaceSlug = $derived(activeWorkspace.slug ?? 'default');
const activeRootPath = $derived(activeWorkspace.rootPath ?? '~');
const panMode = $derived(settings.tool === 'pan' || spacePanning);

function loadState(): void {
  try {
    const rawCanvases = localStorage.getItem(WORKBENCHES_KEY);
    const rawSettings = localStorage.getItem(SETTINGS_KEY);
    if (rawSettings)
      settings = sanitizeSettings(JSON.parse(rawSettings) as Partial<WorkbenchSettings>);
    if (rawCanvases) {
      if (rawCanvases.length > MAX_STORED_BYTES) {
        clearStoredWorkbenchState();
        return;
      }
      const parsed = JSON.parse(rawCanvases) as { activeId?: string; canvases?: WorkbenchCanvas[] };
      const valid = (parsed.canvases ?? []).filter(
        (canvas) => canvas.id && canvas.name && canvas.state?.tiles
      );
      if (valid.length > 0) {
        canvases = valid.map((canvas) => ({ ...canvas, state: sanitizeState(canvas.state) }));
        activeCanvasId =
          parsed.activeId && valid.some((canvas) => canvas.id === parsed.activeId)
            ? parsed.activeId
            : valid[0].id;
        canvasState = cloneState(canvases.find((canvas) => canvas.id === activeCanvasId)!.state);
        return;
      }
    }

    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return;
    if (raw.length > MAX_STORED_BYTES) {
      clearStoredWorkbenchState();
      return;
    }
    canvasState = sanitizeState(JSON.parse(raw) as Partial<CanvasState>);
    canvases = [{ id: 'main', name: 'Main', state: cloneState(canvasState) }];
  } catch {
    clearStoredWorkbenchState();
  }
}

function clearStoredWorkbenchState(): void {
  try {
    localStorage.removeItem(STORAGE_KEY);
    localStorage.removeItem(WORKBENCHES_KEY);
  } catch {
    /* localStorage unavailable */
  }
  canvasState = cloneState(initialState);
  canvases = [{ id: 'main', name: 'Main', state: cloneState(initialState) }];
  activeCanvasId = 'main';
  selectedId = 'terminal-main';
}

function saveState(): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(canvasState));
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
    canvases = canvases.map((canvas) =>
      canvas.id === activeCanvasId ? { ...canvas, state: cloneState(canvasState) } : canvas
    );
    localStorage.setItem(WORKBENCHES_KEY, JSON.stringify({ activeId: activeCanvasId, canvases }));
  } catch {
    /* localStorage unavailable */
  }
}

function scheduleSave(): void {
  if (saveTimer !== null) window.clearTimeout(saveTimer);
  saveTimer = window.setTimeout(() => {
    saveTimer = null;
    saveState();
  }, 180);
}

function sanitizeState(raw: Partial<CanvasState>): CanvasState {
  if (Array.isArray(raw.tiles) && raw.tiles.some(isUnrecoverableTile)) {
    return cloneState(initialState);
  }
  const tiles = Array.isArray(raw.tiles)
    ? raw.tiles.filter(isTile).slice(0, MAX_TILES).map(sanitizeTile)
    : defaultTiles.map((tile) => ({ ...tile }));
  return {
    x: clampNumber(raw.x, -WORLD_LIMIT, WORLD_LIMIT, 72),
    y: clampNumber(raw.y, -WORLD_LIMIT, WORLD_LIMIT, 56),
    scale: clampScale(typeof raw.scale === 'number' ? raw.scale : 1),
    tiles,
  };
}

function sanitizeTile(tile: WorkbenchTileModel): WorkbenchTileModel {
  const minSize = defaultSizeFor(tile.kind, tile.route);
  return {
    ...tile,
    x: clampNumber(tile.x, -WORLD_LIMIT, WORLD_LIMIT, 0),
    y: clampNumber(tile.y, -WORLD_LIMIT, WORLD_LIMIT, 0),
    w: clampNumber(tile.w, 260, 2400, Math.min(minSize.w, 900)),
    h: clampNumber(tile.h, 180, 1600, Math.min(minSize.h, 700)),
    z: clampNumber(tile.z, 0, 10_000, 0),
    restore: tile.restore
      ? {
          x: clampNumber(tile.restore.x, -WORLD_LIMIT, WORLD_LIMIT, 0),
          y: clampNumber(tile.restore.y, -WORLD_LIMIT, WORLD_LIMIT, 0),
          w: clampNumber(tile.restore.w, 260, 2400, minSize.w),
          h: clampNumber(tile.restore.h, 180, 1600, minSize.h),
        }
      : undefined,
    panes: tile.panes?.slice(0, 24).map((pane) => ({ ...pane })),
  };
}

function clampNumber(value: unknown, min: number, max: number, fallback: number): number {
  return typeof value === 'number' && Number.isFinite(value)
    ? Math.min(max, Math.max(min, value))
    : fallback;
}

function sanitizeSettings(raw: Partial<WorkbenchSettings>): WorkbenchSettings {
  const background = ['dots', 'grid', 'paper', 'lines', 'cross', 'clean', 'custom'].includes(
    String(raw.background)
  )
    ? (raw.background as WorkbenchSettings['background'])
    : 'dots';
  return {
    background,
    backgroundColor: typeof raw.backgroundColor === 'string' ? raw.backgroundColor : '',
    backgroundImage:
      typeof raw.backgroundImage === 'string' &&
      raw.backgroundImage.length < MAX_BACKGROUND_DATA_URL_BYTES
        ? raw.backgroundImage
        : '',
    backgroundImageOpacity: clampNumber(raw.backgroundImageOpacity, 0.05, 0.9, 0.28),
    backgroundImageScale: clampNumber(raw.backgroundImageScale, 25, 300, 100),
    backgroundScale: clampNumber(raw.backgroundScale, 40, 240, 100),
    density: raw.density === 'compact' ? 'compact' : 'comfortable',
    tool: raw.tool === 'pan' ? 'pan' : 'select',
    snap: typeof raw.snap === 'boolean' ? raw.snap : true,
    showMinimap: typeof raw.showMinimap === 'boolean' ? raw.showMinimap : true,
    terminalRuntime:
      typeof raw.terminalRuntime === 'string' && raw.terminalRuntime
        ? raw.terminalRuntime
        : 'claude-local',
    terminalCwd: typeof raw.terminalCwd === 'string' ? raw.terminalCwd : '',
  };
}

function isTile(value: unknown): value is WorkbenchTileModel {
  const tile = value as WorkbenchTileModel;
  return (
    !!tile &&
    typeof tile.id === 'string' &&
    typeof tile.x === 'number' &&
    typeof tile.y === 'number'
  );
}

function isUnrecoverableTile(value: unknown): boolean {
  const tile = value as Partial<WorkbenchTileModel>;
  return (
    !tile ||
    typeof tile.id !== 'string' ||
    typeof tile.x !== 'number' ||
    typeof tile.y !== 'number' ||
    typeof tile.w !== 'number' ||
    typeof tile.h !== 'number' ||
    !Number.isFinite(tile.x) ||
    !Number.isFinite(tile.y) ||
    !Number.isFinite(tile.w) ||
    !Number.isFinite(tile.h) ||
    Math.abs(tile.x) > WORLD_LIMIT ||
    Math.abs(tile.y) > WORLD_LIMIT ||
    tile.w > 4000 ||
    tile.h > 3000 ||
    tile.w < 100 ||
    tile.h < 100
  );
}

function clampScale(value: number): number {
  return Math.min(MAX_SCALE, Math.max(MIN_SCALE, value));
}

function setScale(next: number, anchor?: { x: number; y: number }): void {
  const previous = canvasState.scale;
  const scale = clampScale(next);
  if (anchor && previous !== scale) {
    const worldX = (anchor.x - canvasState.x) / previous;
    const worldY = (anchor.y - canvasState.y) / previous;
    canvasState.x = Math.round(anchor.x - worldX * scale);
    canvasState.y = Math.round(anchor.y - worldY * scale);
  }
  canvasState.scale = scale;
  scheduleSave();
}

function resetCanvas(): void {
  canvasState = { x: 72, y: 56, scale: 1, tiles: defaultTiles.map((tile) => ({ ...tile })) };
  selectedId = 'terminal-main';
  saveState();
}

function renameWorkbench(name: string): void {
  const nextName = name.trim() || 'Untitled workbench';
  canvases = canvases.map((canvas) =>
    canvas.id === activeCanvasId ? { ...canvas, name: nextName } : canvas
  );
  saveState();
}

function activeCanvasName(): string {
  return canvases.find((canvas) => canvas.id === activeCanvasId)?.name ?? 'Workbench';
}

function createWorkbench(): void {
  saveState();
  const id = `workbench-${Math.random().toString(36).slice(2, 8)}`;
  const next: WorkbenchCanvas = {
    id,
    name: `Workbench ${canvases.length + 1}`,
    state: { x: 72, y: 56, scale: 1, tiles: [] },
  };
  canvases = [...canvases, next];
  activeCanvasId = id;
  canvasState = cloneState(next.state);
  selectedId = '';
  saveState();
}

function switchWorkbench(id: string): void {
  if (id === activeCanvasId) return;
  saveState();
  const next = canvases.find((canvas) => canvas.id === id);
  if (!next) return;
  activeCanvasId = id;
  canvasState = cloneState(next.state);
  selectedId = next.state.tiles[0]?.id ?? '';
  saveState();
}

function focusCanvas(): void {
  canvasState.x = 72;
  canvasState.y = 56;
  canvasState.scale = 1;
  saveState();
}

function resetView(): void {
  canvasState.x = 72;
  canvasState.y = 56;
  canvasState.scale = 1;
  saveState();
}

function addTile(kind: WorkbenchTileKind, patch: Partial<WorkbenchTileModel> = {}): void {
  const id = `${kind}-${Math.random().toString(36).slice(2, 8)}`;
  const title =
    kind === 'terminal'
      ? 'Terminal'
      : kind === 'agent'
        ? 'Agent Console'
        : kind === 'git'
          ? 'Git Review'
          : kind === 'files'
            ? 'Files'
            : kind === 'mission'
              ? 'Mission'
              : kind === 'module'
                ? 'Module'
                : 'Tmux Layout';
  const sessionId =
    kind === 'git'
      ? canvasState.tiles.find((tile) => tile.kind === 'terminal' && tile.sessionId)?.sessionId
      : undefined;
  const size = defaultSizeFor(kind, patch.route);
  canvasState.tiles = [
    ...canvasState.tiles,
    {
      id,
      kind,
      title,
      subtitle: kind === 'terminal' ? 'new shell tile' : 'canvas module',
      x: snapValue(Math.round((80 - canvasState.x) / canvasState.scale)),
      y: snapValue(Math.round((70 - canvasState.y) / canvasState.scale)),
      w: size.w,
      h: size.h,
      z: nextZ(),
      panes: kind === 'tmux' ? [] : undefined,
      sessionId,
      ...patch,
    },
  ];
  selectedId = id;
  saveState();
}

function patchTile(id: string, patch: Partial<WorkbenchTileModel>): void {
  canvasState.tiles = canvasState.tiles.map((tile) =>
    tile.id === id ? { ...tile, ...patch } : tile
  );
  saveState();
}

function selectTile(id: string): void {
  selectedId = id;
  canvasState.tiles = canvasState.tiles.map((tile) =>
    tile.id === id ? { ...tile, z: nextZ() } : tile
  );
  saveState();
}

function moveTile(id: string, x: number, y: number): void {
  canvasState.tiles = canvasState.tiles.map((tile) =>
    tile.id === id ? { ...tile, x: snapValue(x), y: snapValue(y) } : tile
  );
  scheduleSave();
}

function resizeTile(id: string, x: number, y: number, w: number, h: number): void {
  canvasState.tiles = canvasState.tiles.map((tile) =>
    tile.id === id
      ? {
          ...tile,
          x: snapValue(x),
          y: snapValue(y),
          w: snapValue(w),
          h: snapValue(h),
          restore: undefined,
        }
      : tile
  );
  scheduleSave();
}

function toggleMaximizeTile(id: string): void {
  const rect = viewportEl?.getBoundingClientRect();
  const visibleW = rect ? Math.max(420, rect.width - 56) : 1180;
  const visibleH = rect ? Math.max(300, rect.height - 56) : 760;
  const worldX = Math.round((28 - canvasState.x) / canvasState.scale);
  const worldY = Math.round((28 - canvasState.y) / canvasState.scale);
  canvasState.tiles = canvasState.tiles.map((tile) => {
    if (tile.id !== id) return tile;
    if (tile.restore) {
      return { ...tile, ...tile.restore, restore: undefined, z: nextZ() };
    }
    return {
      ...tile,
      restore: { x: tile.x, y: tile.y, w: tile.w, h: tile.h },
      x: snapValue(worldX),
      y: snapValue(worldY),
      w: snapValue(Math.round(visibleW / canvasState.scale)),
      h: snapValue(Math.round(visibleH / canvasState.scale)),
      z: nextZ(),
    };
  });
  selectedId = id;
  saveState();
}

function removeTile(id: string): void {
  canvasState.tiles = canvasState.tiles.filter((tile) => tile.id !== id);
  if (selectedId === id) selectedId = canvasState.tiles[0]?.id ?? '';
  saveState();
}

function addModuleTile(mod: (typeof MODULES)[number]): void {
  const size = defaultSizeFor('module', mod.route);
  addTile('module', {
    title: mod.label,
    subtitle: mod.subtitle,
    route: mod.route,
    w: size.w,
    h: size.h,
  });
  modulePickerOpen = false;
}

function defaultSizeFor(kind: WorkbenchTileKind, route?: string): { w: number; h: number } {
  if (kind === 'terminal') return { w: 760, h: 460 };
  if (kind === 'agent') return { w: 720, h: 520 };
  if (kind === 'git') return { w: 720, h: 520 };
  if (kind === 'tmux') return { w: 860, h: 560 };
  if (kind === 'files') return { w: 760, h: 500 };
  if (kind === 'mission') return { w: 720, h: 460 };
  if (route === '/sessions' || route === '/agents' || route === '/runtimes')
    return { w: 680, h: 460 };
  if (route === '/files' || route === '/docs' || route === '/workspaces') return { w: 760, h: 520 };
  return { w: 680, h: 440 };
}

function snapValue(value: number): number {
  return settings.snap ? Math.round(value / 10) * 10 : value;
}

function nextZ(): number {
  return Math.max(0, ...canvasState.tiles.map((tile) => tile.z ?? 0)) + 1;
}

function patchSettings(patch: Partial<WorkbenchSettings>): void {
  settings = { ...settings, ...patch };
  saveState();
}

async function handleBackgroundFile(event: Event): Promise<void> {
  backgroundError = '';
  const input = event.currentTarget as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) return;
  if (!file.type.startsWith('image/')) {
    backgroundError = 'Choose an image file.';
    return;
  }
  if (file.size > MAX_BACKGROUND_SOURCE_BYTES) {
    backgroundError = 'Use an image under 12 MB.';
    return;
  }
  try {
    const result = await compressBackgroundImage(file);
    if (!result) {
      backgroundError = 'Could not prepare that image.';
      return;
    }
    if (result.length > MAX_BACKGROUND_DATA_URL_BYTES) {
      backgroundError = 'That image is still too large after compression.';
      return;
    }
    patchSettings({ background: 'custom', backgroundImage: result });
  } catch {
    backgroundError = 'Could not read that image.';
  }
}

async function compressBackgroundImage(file: File): Promise<string> {
  const dataUrl = await readFileAsDataUrl(file);
  if (file.type === 'image/gif' && dataUrl.length <= MAX_BACKGROUND_DATA_URL_BYTES) {
    return dataUrl;
  }
  const image = await loadImage(dataUrl);
  const scale = Math.min(
    1,
    MAX_BACKGROUND_DIMENSION / Math.max(image.naturalWidth, image.naturalHeight)
  );
  const width = Math.max(1, Math.round(image.naturalWidth * scale));
  const height = Math.max(1, Math.round(image.naturalHeight * scale));
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext('2d');
  if (!context) return dataUrl;
  context.drawImage(image, 0, 0, width, height);
  for (const quality of [0.86, 0.74, 0.62, 0.5]) {
    const encoded = canvas.toDataURL('image/jpeg', quality);
    if (encoded.length <= MAX_BACKGROUND_DATA_URL_BYTES) return encoded;
  }
  return canvas.toDataURL('image/jpeg', 0.42);
}

function readFileAsDataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(typeof reader.result === 'string' ? reader.result : '');
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error('image load failed'));
    image.src = src;
  });
}

const linkedSessionId = $derived(
  canvasState.tiles.find((tile) => tile.kind === 'terminal' && tile.sessionId)?.sessionId ?? null
);

function beginPan(event: PointerEvent): void {
  if (event.button !== 0 && event.button !== 1) return;
  const target = event.target as HTMLElement | null;
  if (
    !target ||
    (!panMode && target.closest('.wbt-tile')) ||
    target.closest('.sw-toolbar, .sw-minimap')
  )
    return;
  event.preventDefault();
  viewportEl?.setPointerCapture(event.pointerId);
  panStart = {
    pointerId: event.pointerId,
    px: event.clientX,
    py: event.clientY,
    x: canvasState.x,
    y: canvasState.y,
  };
}

function movePan(event: PointerEvent): void {
  if (!panStart || event.pointerId !== panStart.pointerId) return;
  canvasState.x = Math.round(panStart.x + event.clientX - panStart.px);
  canvasState.y = Math.round(panStart.y + event.clientY - panStart.py);
  scheduleSave();
}

function endPan(event: PointerEvent): void {
  if (!panStart || event.pointerId !== panStart.pointerId) return;
  viewportEl?.releasePointerCapture(event.pointerId);
  panStart = null;
  saveState();
}

function beginNativePan(event: PointerEvent): void {
  if (!viewportEl || (event.button !== 0 && event.button !== 1)) return;
  const target = event.target as HTMLElement | null;
  if (!target || target.closest('.sw-toolbar, .sw-minimap')) return;
  const overTile = Boolean(target.closest('.wbt-tile'));
  const shouldPan = panMode || event.button === 1 || !overTile;
  if (!shouldPan) return;
  event.preventDefault();
  event.stopPropagation();
  if (typeof event.stopImmediatePropagation === 'function') event.stopImmediatePropagation();
  viewportEl.setPointerCapture(event.pointerId);
  panStart = {
    pointerId: event.pointerId,
    px: event.clientX,
    py: event.clientY,
    x: canvasState.x,
    y: canvasState.y,
  };
}

function handleWheel(event: WheelEvent): void {
  event.preventDefault();
  event.stopPropagation();
  if (event.metaKey || event.ctrlKey) {
    const rect = viewportEl?.getBoundingClientRect();
    setScale(
      canvasState.scale + (event.deltaY > 0 ? -0.08 : 0.08),
      rect ? { x: event.clientX - rect.left, y: event.clientY - rect.top } : undefined
    );
    return;
  }
  canvasState.x = Math.round(canvasState.x - (event.shiftKey ? event.deltaY : event.deltaX));
  canvasState.y = Math.round(canvasState.y - (event.shiftKey ? 0 : event.deltaY));
  scheduleSave();
}

function fitAllTiles(): void {
  const rect = viewportEl?.getBoundingClientRect();
  if (!rect || canvasState.tiles.length === 0) {
    focusCanvas();
    return;
  }
  const padding = 72;
  const minX = Math.min(...canvasState.tiles.map((tile) => tile.x));
  const minY = Math.min(...canvasState.tiles.map((tile) => tile.y));
  const maxX = Math.max(...canvasState.tiles.map((tile) => tile.x + tile.w));
  const maxY = Math.max(...canvasState.tiles.map((tile) => tile.y + tile.h));
  const contentW = Math.max(1, maxX - minX);
  const contentH = Math.max(1, maxY - minY);
  const nextScale = clampScale(
    Math.min((rect.width - padding * 2) / contentW, (rect.height - padding * 2) / contentH, 1)
  );
  canvasState.scale = nextScale;
  canvasState.x = Math.round((rect.width - contentW * nextScale) / 2 - minX * nextScale);
  canvasState.y = Math.round((rect.height - contentH * nextScale) / 2 - minY * nextScale);
  saveState();
}

function viewLooksRecoverable(): boolean {
  return (
    Number.isFinite(canvasState.x) &&
    Number.isFinite(canvasState.y) &&
    Number.isFinite(canvasState.scale) &&
    Math.abs(canvasState.x) < WORLD_LIMIT &&
    Math.abs(canvasState.y) < WORLD_LIMIT &&
    canvasState.scale >= MIN_SCALE &&
    canvasState.scale <= MAX_SCALE
  );
}

onMount(() => {
  loadState();
  if (!viewLooksRecoverable()) resetView();
  saveState();
});

$effect(() => {
  if (!viewportEl) return;
  const currentViewport = viewportEl;
  const pointerDown = (event: PointerEvent) => beginNativePan(event);
  const pointerMove = (event: PointerEvent) => movePan(event);
  const pointerUp = (event: PointerEvent) => endPan(event);
  const wheel = (event: WheelEvent) => handleWheel(event);
  currentViewport.addEventListener('pointerdown', pointerDown, { capture: true });
  currentViewport.addEventListener('wheel', wheel, { capture: true, passive: false });
  window.addEventListener('pointermove', pointerMove, { capture: true });
  window.addEventListener('pointerup', pointerUp, { capture: true });
  window.addEventListener('pointercancel', pointerUp, { capture: true });
  return () => {
    currentViewport.removeEventListener('pointerdown', pointerDown, { capture: true });
    currentViewport.removeEventListener('wheel', wheel, { capture: true });
    window.removeEventListener('pointermove', pointerMove, { capture: true });
    window.removeEventListener('pointerup', pointerUp, { capture: true });
    window.removeEventListener('pointercancel', pointerUp, { capture: true });
  };
});
</script>

<svelte:window
  onkeydown={(event) => {
    if (event.code === 'Space' && !(event.target as HTMLElement | null)?.matches('input, textarea, select, [contenteditable="true"]')) {
      event.preventDefault();
      spacePanning = true;
    }
  }}
  onkeyup={(event) => {
    if (event.code === 'Space') spacePanning = false;
  }}
  onblur={() => { spacePanning = false; }}
/>

<section class="sw-root" aria-label="Spatial workbench">
  <header class="sw-toolbar">
    <div class="sw-title">
      <span>Workbench</span>
      <h1>Spatial Canvas</h1>
    </div>

    <div class="sw-actions" aria-label="Canvas actions">
      <select
        class="sw-select"
        aria-label="Active workbench"
        value={activeCanvasId}
        onchange={(event) => switchWorkbench((event.currentTarget as HTMLSelectElement).value)}
      >
        {#each canvases as canvas (canvas.id)}
          <option value={canvas.id}>{canvas.name}</option>
        {/each}
      </select>
      <button type="button" class="sw-btn" onclick={createWorkbench}>
        <Plus size={13} aria-hidden="true" /> Workbench
      </button>
      <button type="button" class="sw-btn sw-btn--primary" onclick={() => addTile('terminal')}>
        <Terminal size={13} aria-hidden="true" /> Terminal
      </button>
      <button type="button" class="sw-btn" onclick={() => addTile('agent')}>
        <Bot size={13} aria-hidden="true" /> Agent
      </button>
      <button type="button" class="sw-btn" onclick={() => addTile('git')}>
        <GitPullRequest size={13} aria-hidden="true" /> Git
      </button>
      <button type="button" class="sw-btn" onclick={() => addTile('tmux')}>
        <Grid2X2 size={13} aria-hidden="true" /> Tmux
      </button>
      <button type="button" class="sw-btn" onclick={() => { modulePickerOpen = !modulePickerOpen; }}>
        <PanelsTopLeft size={13} aria-hidden="true" /> Modules
      </button>
      <button
        type="button"
        class="sw-icon-btn"
        class:sw-btn--active={settings.tool === 'select'}
        onclick={() => patchSettings({ tool: 'select' })}
        aria-label="Select tiles"
        title="Select tiles"
      >
        <MousePointer2 size={14} aria-hidden="true" />
      </button>
      <button
        type="button"
        class="sw-icon-btn"
        class:sw-btn--active={settings.tool === 'pan'}
        onclick={() => patchSettings({ tool: 'pan' })}
        aria-label="Pan canvas"
        title="Pan canvas"
      >
        <Hand size={14} aria-hidden="true" />
      </button>
      <button
        type="button"
        class="sw-btn"
        class:sw-btn--active={settingsOpen}
        onclick={() => { settingsOpen = !settingsOpen; modulePickerOpen = false; }}
      >
        <Settings2 size={13} aria-hidden="true" /> Settings
      </button>
      <button type="button" class="sw-icon-btn" onclick={focusCanvas} aria-label="Center canvas" title="Center canvas">
        <Crosshair size={14} aria-hidden="true" />
      </button>
      <button type="button" class="sw-btn" onclick={fitAllTiles} aria-label="Fit all tiles" title="Fit all tiles">
        <Maximize size={13} aria-hidden="true" /> Fit
      </button>
      <button type="button" class="sw-icon-btn" onclick={() => setScale(canvasState.scale - 0.1)} aria-label="Zoom out" title="Zoom out">
        <Minus size={14} aria-hidden="true" />
      </button>
      <button type="button" class="sw-zoom" onclick={() => setScale(1)} aria-label="Reset zoom">
        {Math.round(canvasState.scale * 100)}%
      </button>
      <button type="button" class="sw-icon-btn" onclick={() => setScale(canvasState.scale + 0.1)} aria-label="Zoom in" title="Zoom in">
        <Plus size={14} aria-hidden="true" />
      </button>
      <button type="button" class="sw-icon-btn" onclick={resetCanvas} aria-label="Reset workbench" title="Reset workbench">
        <RotateCcw size={14} aria-hidden="true" />
      </button>
    </div>
    {#if modulePickerOpen}
      <div class="sw-module-picker" role="menu" aria-label="Open module in workbench">
        {#each MODULES as mod (mod.route)}
          <button type="button" role="menuitem" onclick={() => addModuleTile(mod)}>
            <span>{mod.label}</span>
            <small>{mod.subtitle}</small>
          </button>
        {/each}
      </div>
    {/if}
    {#if settingsOpen}
      <aside class="sw-settings" aria-label="Workbench settings">
        <section>
          <h2>Workbench</h2>
          <label class="sw-field">
            <span>Name</span>
            <input
              value={activeCanvasName()}
              onblur={(event) => renameWorkbench(event.currentTarget.value)}
              onkeydown={(event) => {
                if (event.key === 'Enter') event.currentTarget.blur();
              }}
            />
          </label>
        </section>
        <section>
          <h2>Background</h2>
          <div class="sw-segments">
            <button type="button" class:sw-segment--active={settings.background === 'dots'} onclick={() => patchSettings({ background: 'dots' })}>Dots</button>
            <button type="button" class:sw-segment--active={settings.background === 'grid'} onclick={() => patchSettings({ background: 'grid' })}>Grid</button>
            <button type="button" class:sw-segment--active={settings.background === 'paper'} onclick={() => patchSettings({ background: 'paper' })}>Paper</button>
            <button type="button" class:sw-segment--active={settings.background === 'lines'} onclick={() => patchSettings({ background: 'lines' })}>Lines</button>
            <button type="button" class:sw-segment--active={settings.background === 'cross'} onclick={() => patchSettings({ background: 'cross' })}>Cross</button>
            <button type="button" class:sw-segment--active={settings.background === 'clean'} onclick={() => patchSettings({ background: 'clean' })}>Clean</button>
            <button type="button" class:sw-segment--active={settings.background === 'custom'} onclick={() => patchSettings({ background: 'custom' })}>Image</button>
          </div>
          <label class="sw-field">
            <span>Base color</span>
            <input
              type="color"
              value={settings.backgroundColor || '#f3eedc'}
              oninput={(event) => patchSettings({ backgroundColor: event.currentTarget.value })}
            />
          </label>
          <label class="sw-field">
            <span>Custom image</span>
            <input type="file" accept="image/*" onchange={handleBackgroundFile} />
          </label>
          <label class="sw-field">
            <span>Image URL</span>
            <input
              value={settings.backgroundImage.startsWith('data:') ? '' : settings.backgroundImage}
              placeholder="https://..."
              onchange={(event) => patchSettings({ background: 'custom', backgroundImage: event.currentTarget.value })}
            />
          </label>
          <label class="sw-field">
            <span>Image opacity {Math.round(settings.backgroundImageOpacity * 100)}%</span>
            <input
              type="range"
              min="5"
              max="90"
              value={Math.round(settings.backgroundImageOpacity * 100)}
              oninput={(event) => patchSettings({ backgroundImageOpacity: Number(event.currentTarget.value) / 100 })}
            />
          </label>
          <label class="sw-field">
            <span>Image zoom {settings.backgroundImageScale}%</span>
            <input
              type="range"
              min="25"
              max="300"
              value={settings.backgroundImageScale}
              oninput={(event) => patchSettings({ backgroundImageScale: Number(event.currentTarget.value) })}
            />
          </label>
          <label class="sw-field">
            <span>Pattern scale {settings.backgroundScale}%</span>
            <input
              type="range"
              min="40"
              max="240"
              value={settings.backgroundScale}
              oninput={(event) => patchSettings({ backgroundScale: Number(event.currentTarget.value) })}
            />
          </label>
          {#if backgroundError}
            <p class="sw-error">{backgroundError}</p>
          {/if}
        </section>
        <section>
          <h2>Density</h2>
          <div class="sw-segments">
            <button type="button" class:sw-segment--active={settings.density === 'comfortable'} onclick={() => patchSettings({ density: 'comfortable' })}>Comfort</button>
            <button type="button" class:sw-segment--active={settings.density === 'compact'} onclick={() => patchSettings({ density: 'compact' })}>Compact</button>
          </div>
        </section>
        <label>
          <input type="checkbox" checked={settings.snap} onchange={(event) => patchSettings({ snap: event.currentTarget.checked })} />
          Snap movement and resize
        </label>
        <label>
          <input type="checkbox" checked={settings.showMinimap} onchange={(event) => patchSettings({ showMinimap: event.currentTarget.checked })} />
          Show minimap
        </label>
        <section>
          <h2>Terminal defaults</h2>
          <label class="sw-field">
            <span>Runtime</span>
            <select
              value={settings.terminalRuntime}
              onchange={(event) => patchSettings({ terminalRuntime: event.currentTarget.value })}
            >
              <option value="claude-local">Claude local</option>
              <option value="codex-local">Codex local</option>
              <option value="gemini-local">Gemini local</option>
            </select>
          </label>
          <label class="sw-field">
            <span>Working directory</span>
            <input
              value={settings.terminalCwd}
              placeholder={activeRootPath}
              onchange={(event) => patchSettings({ terminalCwd: event.currentTarget.value })}
            />
          </label>
        </section>
      </aside>
    {/if}
  </header>

  <div
    class="sw-viewport"
    class:sw-viewport--panning={panStart !== null}
    class:sw-viewport--pan-tool={panMode}
    class:sw-viewport--grid={settings.background === 'grid'}
    class:sw-viewport--paper={settings.background === 'paper'}
    class:sw-viewport--lines={settings.background === 'lines'}
    class:sw-viewport--cross={settings.background === 'cross'}
    class:sw-viewport--clean={settings.background === 'clean'}
    class:sw-viewport--custom={settings.background === 'custom'}
    class:sw-viewport--compact={settings.density === 'compact'}
    bind:this={viewportEl}
    role="application"
    tabindex="0"
    style="
      --sw-bg-base: {settings.backgroundColor || 'var(--bg)'};
      --sw-bg-scale: {settings.backgroundScale / 100};
      --sw-bg-image: {settings.backgroundImage ? `url(${settings.backgroundImage})` : 'none'};
      --sw-bg-image-opacity: {settings.backgroundImageOpacity};
      --sw-bg-image-size: {settings.backgroundImageScale}%;
    "
  >
    <div
      class="sw-world"
      style="transform: translate3d({canvasState.x}px, {canvasState.y}px, 0) scale({canvasState.scale});"
    >
      {#each canvasState.tiles as tile (tile.id)}
        <WorkbenchTile
          {tile}
          scale={canvasState.scale}
          workspaceSlug={activeWorkspaceSlug}
          rootPath={settings.terminalCwd || activeRootPath}
          runtimeType={settings.terminalRuntime}
          {linkedSessionId}
          selected={selectedId === tile.id}
          onSelect={selectTile}
          onMove={moveTile}
          onResize={resizeTile}
          onRemove={removeTile}
          onToggleMaximize={toggleMaximizeTile}
          onPatch={patchTile}
          onAddTile={addTile}
        />
      {/each}
    </div>

    {#if settings.showMinimap}
    <div class="sw-minimap" aria-hidden="true">
      {#each canvasState.tiles as tile (tile.id)}
        <span
          class:sw-minimap-tile--selected={selectedId === tile.id}
          style="left: {tile.x / 12 + 12}px; top: {tile.y / 12 + 10}px; width: {Math.max(12, tile.w / 16)}px; height: {Math.max(8, tile.h / 18)}px;"
        ></span>
      {/each}
    </div>
    {/if}

    <div class="sw-hint">
      <Maximize size={13} aria-hidden="true" />
      <span>Drag empty canvas or scroll to pan</span>
      <LayoutPanelTop size={13} aria-hidden="true" />
      <span>Cmd/Ctrl-scroll zooms</span>
    </div>
  </div>
</section>

<style>
  .sw-root {
    display: grid;
    grid-template-rows: auto 1fr;
    height: 100%;
    min-height: 0;
    overflow: hidden;
    background: var(--bg);
  }

  .sw-toolbar {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    padding: 10px 12px;
    border-bottom: 1px solid var(--border);
    background: var(--surface, var(--bg));
  }

  .sw-title {
    min-width: 0;
  }

  .sw-title span {
    display: block;
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--fg-subtle);
  }

  .sw-title h1 {
    margin: 2px 0 0;
    font-size: 15px;
    line-height: 1.2;
    color: var(--fg);
  }

  .sw-actions {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 6px;
    flex-wrap: wrap;
  }

  .sw-btn,
  .sw-icon-btn,
  .sw-zoom,
  .sw-select {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    min-height: 28px;
    border: 1px solid var(--border);
    border-radius: 6px;
    background: transparent;
    color: var(--fg-muted);
    font: inherit;
    font-size: 12px;
    cursor: pointer;
  }

  .sw-btn { padding: 0 10px; }
  .sw-icon-btn { width: 30px; }
  .sw-zoom { min-width: 48px; padding: 0 8px; font-variant-numeric: tabular-nums; }
  .sw-select { padding: 0 28px 0 10px; min-width: 128px; }

  .sw-btn:hover,
  .sw-icon-btn:hover,
  .sw-zoom:hover,
  .sw-select:hover {
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 7%, transparent);
  }

  .sw-btn--primary,
  .sw-btn--active {
    color: var(--fg);
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 18%, transparent);
    border-color: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 48%, var(--border));
  }

  .sw-module-picker {
    position: absolute;
    top: calc(100% + 6px);
    right: 12px;
    z-index: 60;
    display: grid;
    grid-template-columns: repeat(2, minmax(180px, 1fr));
    gap: 4px;
    width: min(520px, calc(100vw - 320px));
    max-height: 440px;
    overflow: auto;
    padding: 8px;
    border: 1px solid var(--border);
    border-radius: 8px;
    background: color-mix(in oklch, var(--surface, var(--bg)) 96%, black 8%);
    box-shadow: 0 20px 60px color-mix(in oklch, black 36%, transparent);
  }

  .sw-module-picker button {
    display: grid;
    gap: 3px;
    min-height: 52px;
    padding: 8px 10px;
    border: 1px solid transparent;
    border-radius: 6px;
    background: transparent;
    color: var(--fg);
    text-align: left;
    font: inherit;
    cursor: pointer;
  }

  .sw-module-picker button:hover {
    border-color: var(--border);
    background: color-mix(in oklch, var(--fg) 7%, transparent);
  }

  .sw-module-picker span {
    font-size: 12px;
    font-weight: 650;
  }

  .sw-module-picker small {
    color: var(--fg-subtle);
    font-size: 11px;
  }

  .sw-settings {
    position: absolute;
    top: calc(100% + 6px);
    right: 12px;
    z-index: 70;
    display: grid;
    gap: 14px;
    width: 320px;
    max-height: min(720px, calc(100vh - 160px));
    overflow: auto;
    padding: 12px;
    border: 1px solid var(--border);
    border-radius: 8px;
    background: color-mix(in oklch, var(--surface, var(--bg)) 96%, black 8%);
    box-shadow: 0 20px 60px color-mix(in oklch, black 36%, transparent);
  }

  .sw-settings section {
    display: grid;
    gap: 8px;
  }

  .sw-settings h2 {
    margin: 0;
    color: var(--fg-subtle);
    font-size: 10px;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .sw-settings label {
    display: flex;
    align-items: center;
    gap: 8px;
    color: var(--fg-muted);
    font-size: 12px;
  }

  .sw-settings .sw-field {
    display: grid;
    align-items: stretch;
    gap: 6px;
  }

  .sw-field span {
    color: var(--fg-subtle);
    font-size: 11px;
  }

  .sw-field input,
  .sw-field select {
    min-height: 30px;
    padding: 0 8px;
    border: 1px solid var(--border);
    border-radius: 6px;
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    color: var(--fg);
    font: inherit;
    font-size: 12px;
  }

  .sw-field input[type="color"] {
    width: 100%;
    height: 32px;
    padding: 3px;
  }

  .sw-field input[type="file"] {
    padding: 5px 8px;
  }

  .sw-field input[type="range"] {
    padding: 0;
  }

  .sw-error {
    margin: 0;
    color: var(--destructive, oklch(0.65 0.22 25));
    font-size: 11px;
    line-height: 1.35;
  }

  .sw-segments {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 4px;
  }

  .sw-segments button {
    min-height: 28px;
    border: 1px solid var(--border);
    border-radius: 6px;
    background: transparent;
    color: var(--fg-muted);
    font: inherit;
    font-size: 12px;
    cursor: pointer;
  }

  .sw-segments .sw-segment--active {
    color: var(--fg);
    border-color: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 48%, var(--border));
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 16%, transparent);
  }

  .sw-viewport {
    position: relative;
    min-height: 0;
    overflow: hidden;
    cursor: grab;
    touch-action: none;
    isolation: isolate;
    background:
      radial-gradient(circle at 1px 1px, color-mix(in oklch, var(--fg) 12%, transparent) 1px, transparent 0) 0 0 / calc(28px * var(--sw-bg-scale, 1)) calc(28px * var(--sw-bg-scale, 1)),
      linear-gradient(135deg, color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 4%, transparent), transparent 42%),
      var(--sw-bg-base, var(--bg));
  }

  .sw-viewport::before {
    content: '';
    position: absolute;
    inset: 0;
    z-index: -1;
    background-image: var(--sw-bg-image);
    background-position: center;
    background-size: var(--sw-bg-image-size, 100%) auto;
    background-repeat: no-repeat;
    opacity: 0;
    pointer-events: none;
  }

  .sw-viewport--panning { cursor: grabbing; }
  .sw-viewport--pan-tool { cursor: grab; }
  .sw-viewport--pan-tool :global(.wbt-tile) { pointer-events: none; }

  .sw-viewport--grid {
    background:
      linear-gradient(color-mix(in oklch, var(--fg) 9%, transparent) 1px, transparent 1px) 0 0 / calc(40px * var(--sw-bg-scale, 1)) calc(40px * var(--sw-bg-scale, 1)),
      linear-gradient(90deg, color-mix(in oklch, var(--fg) 9%, transparent) 1px, transparent 1px) 0 0 / calc(40px * var(--sw-bg-scale, 1)) calc(40px * var(--sw-bg-scale, 1)),
      var(--sw-bg-base, var(--bg));
  }

  .sw-viewport--paper {
    background:
      radial-gradient(circle at 1px 1px, color-mix(in oklch, var(--fg) 10%, transparent) 1px, transparent 0) 0 0 / calc(18px * var(--sw-bg-scale, 1)) calc(18px * var(--sw-bg-scale, 1)),
      linear-gradient(90deg, color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 10%, transparent) 1px, transparent 1px) 0 0 / calc(96px * var(--sw-bg-scale, 1)) calc(96px * var(--sw-bg-scale, 1)),
      color-mix(in oklch, var(--sw-bg-base, #f3eedc) 92%, white 8%);
  }

  .sw-viewport--lines {
    background:
      linear-gradient(color-mix(in oklch, var(--fg) 9%, transparent) 1px, transparent 1px) 0 0 / 100% calc(30px * var(--sw-bg-scale, 1)),
      var(--sw-bg-base, var(--bg));
  }

  .sw-viewport--cross {
    background:
      radial-gradient(circle at center, color-mix(in oklch, var(--fg) 12%, transparent) 1.2px, transparent 1.4px) 0 0 / calc(34px * var(--sw-bg-scale, 1)) calc(34px * var(--sw-bg-scale, 1)),
      linear-gradient(color-mix(in oklch, var(--fg) 7%, transparent) 1px, transparent 1px) 0 0 / calc(170px * var(--sw-bg-scale, 1)) calc(170px * var(--sw-bg-scale, 1)),
      linear-gradient(90deg, color-mix(in oklch, var(--fg) 7%, transparent) 1px, transparent 1px) 0 0 / calc(170px * var(--sw-bg-scale, 1)) calc(170px * var(--sw-bg-scale, 1)),
      var(--sw-bg-base, var(--bg));
  }

  .sw-viewport--clean {
    background: var(--sw-bg-base, var(--bg));
  }

  .sw-viewport--custom::before {
    opacity: var(--sw-bg-image-opacity, 0.28);
  }

  .sw-viewport--compact :global(.wbt-head) { min-height: 28px; }
  .sw-viewport--compact :global(.wbt-body) { padding: 8px; }
  .sw-viewport--compact :global(.wbt-foot) { min-height: 24px; padding-block: 5px; }

  .sw-world {
    position: absolute;
    inset: 0;
    width: 5000px;
    height: 3200px;
    transform-origin: 0 0;
    pointer-events: none;
  }

  .sw-minimap {
    position: absolute;
    right: 12px;
    bottom: 12px;
    width: 170px;
    height: 112px;
    border: 1px solid var(--border);
    border-radius: 8px;
    background: color-mix(in oklch, var(--surface, var(--bg)) 88%, black 12%);
    box-shadow: 0 14px 40px color-mix(in oklch, black 28%, transparent);
  }

  .sw-minimap span {
    position: absolute;
    border-radius: 3px;
    background: color-mix(in oklch, var(--fg) 26%, transparent);
  }

  .sw-minimap .sw-minimap-tile--selected {
    background: var(--cnp-accent, oklch(0.72 0.18 145));
  }

  .sw-hint {
    position: absolute;
    left: 12px;
    bottom: 12px;
    display: inline-flex;
    align-items: center;
    gap: 7px;
    padding: 7px 9px;
    border: 1px solid var(--border);
    border-radius: 7px;
    background: color-mix(in oklch, var(--surface, var(--bg)) 88%, black 12%);
    color: var(--fg-subtle);
    font-size: 11px;
    pointer-events: none;
  }

  @media (max-width: 900px) {
    .sw-toolbar {
      align-items: flex-start;
      flex-direction: column;
    }

    .sw-actions {
      justify-content: flex-start;
    }

    .sw-minimap,
    .sw-hint {
      display: none;
    }

    .sw-module-picker {
      left: 12px;
      right: 12px;
      width: auto;
      grid-template-columns: 1fr;
    }
  }
</style>
