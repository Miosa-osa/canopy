export type WorkbenchMode = "canvas" | "split";

export type WorkbenchTileType =
  | "terminal"
  | "tmux"
  | "chat"
  | "sessions"
  | "files";

export interface WorkbenchTile {
  id: string;
  type: WorkbenchTileType;
  title: string;
  x: number;
  y: number;
  width: number;
  height: number;
  zIndex: number;
  minimized?: boolean;
}

export interface WorkbenchLayout {
  version: 1;
  mode: WorkbenchMode;
  tiles: WorkbenchTile[];
  activeTileId: string | null;
  viewport: WorkbenchViewport;
}

export interface WorkbenchViewport {
  x: number;
  y: number;
  scale: number;
}

export interface WorkbenchTileDefinition {
  type: WorkbenchTileType;
  title: string;
  defaultWidth: number;
  defaultHeight: number;
}

export const WORKBENCH_TILE_DEFINITIONS: Record<WorkbenchTileType, WorkbenchTileDefinition> = {
  terminal: {
    type: "terminal",
    title: "Terminal",
    defaultWidth: 620,
    defaultHeight: 360,
  },
  tmux: {
    type: "tmux",
    title: "Tmux IDE",
    defaultWidth: 560,
    defaultHeight: 520,
  },
  chat: {
    type: "chat",
    title: "Agent Chat",
    defaultWidth: 420,
    defaultHeight: 520,
  },
  sessions: {
    type: "sessions",
    title: "Sessions",
    defaultWidth: 520,
    defaultHeight: 420,
  },
  files: {
    type: "files",
    title: "Files",
    defaultWidth: 340,
    defaultHeight: 420,
  },
};
