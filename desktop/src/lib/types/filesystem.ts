// IPC return shape types — matches Rust structs in src-tauri/src/filesystem.rs
// All Rust structs use #[serde(rename_all = "camelCase")] so fields arrive as camelCase

export type IpcResult<T> =
  | { ok: true; data: T; error: null }
  | { ok: false; data: null; error: string };

/** Returned by scan_nodes_dir */
export interface NodeMeta {
  id: string;
  name: string;
  nodeType: string;
  health: string;
  owner: string;
  path: string;
  signalCount: number;
  lastUpdated: string;
}

/** Returned by read_markdown_file */
export interface MarkdownFile {
  frontmatter: Record<string, unknown>;
  content: string;
}

/** Returned by scan_rhythm_dir */
export interface RhythmFiles {
  today: string | null;
  weekPlan: string | null;
  energy: string | null;
}

/** Extended rhythm data used by the rhythm store */
export interface RhythmData {
  today: string | null;
  weekPlan: string | null;
  energy: string | null;
  files: RhythmFile[];
}

export interface RhythmFile {
  name: string;
  path: string;
  modified: string;
}

export type RhythmMode =
  | "BUILD"
  | "OPERATE"
  | "LEARN"
  | "SYNTHESIZE"
  | "EXTRACT";

/** Returned by list_signal_files */
export interface SignalMeta {
  /** Unique ID — derived from filename or path */
  id: string;
  nodeId: string;
  path: string;
  filename: string;
  date: string;
  title?: string;
}

/** Returned by run_engine_command */
export interface CommandResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

// === Derived types (used in stores, not directly from IPC) ===

export type NodeHealth = "green" | "yellow" | "red" | "unknown";

export interface Node {
  id: string;
  name: string;
  type: string;
  health: NodeHealth;
  owner: string;
  path: string;
  signalCount: number;
  lastUpdated: string;
  /** Parsed from folder prefix e.g. "02" → 2 */
  number: number;
  /** Precomputed route e.g. "/app/nodes/02-miosa" */
  href: string;
}

export interface Signal {
  id: string;
  title: string;
  nodeId: string;
  genre: string;
  mode: string;
  snRatio: number;
  date: string;
  content?: string;
  filePath: string;
}

export type RhythmModeValue =
  | "BUILD"
  | "OPERATE"
  | "LEARN"
  | "SYNTHESIZE"
  | "EXTRACT";

export interface TopologyEntity {
  id: string;
  name: string;
  type: string;
  children?: TopologyEntity[];
}

export interface Topology {
  entities: TopologyEntity[];
}

/** Full topology data from read_topology_yaml IPC */
export interface TopologyData {
  entities: TopologyEntity[];
  people: TopologyPerson[];
}

/** Person entry from topology.yaml */
export interface TopologyPerson {
  id: string;
  name: string;
  role: string;
  adapter: string;
  node?: string;
  status?: string;
}

/** Re-export for convenience */
export type TopologyEntry = TopologyEntity;

export interface TeamMember {
  slug: string;
  name: string;
  role: string;
  channels: string[];
  genreCompetence?: string[];
  constraint?: string;
}

export interface AIAgent {
  id: string;
  name: string;
  role: string;
  adapter: string;
  status: string;
  skills: string[];
  model?: string;
}

export interface Project {
  id: string;
  name: string;
  description?: string;
  status: string;
  progress: number;
  owner: string;
}
