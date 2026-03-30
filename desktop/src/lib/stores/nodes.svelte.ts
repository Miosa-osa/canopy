// src/lib/stores/nodes.svelte.ts
// Filesystem-backed nodes store — reads from nodes/ directory via Tauri IPC
import { isTauri } from "$lib/utils/platform";
import type { Node, NodeMeta } from "$lib/types/filesystem";

function mapNodeMeta(meta: NodeMeta): Node {
  const match = meta.id.match(/^(\d+)-/);
  return {
    id: meta.id,
    name: meta.name,
    type: meta.nodeType,
    health: (meta.health as Node["health"]) || "unknown",
    owner: meta.owner,
    path: meta.path,
    signalCount: meta.signalCount,
    lastUpdated: meta.lastUpdated,
    number: match ? parseInt(match[1], 10) : 0,
    href: `/app/nodes/${meta.id}`,
  };
}

let nodes = $state<Node[]>([]);
let loading = $state(false);
let error = $state<string | null>(null);

const nodeById = $derived(new Map(nodes.map((n) => [n.id, n])));
const sortedNodes = $derived([...nodes].sort((a, b) => a.number - b.number));

async function load(workspacePath: string): Promise<void> {
  if (!isTauri()) return;
  loading = true;
  error = null;
  try {
    const { invoke } = await import("@tauri-apps/api/core");
    const result = await invoke<NodeMeta[]>("scan_nodes_dir", {
      path: workspacePath + "/nodes",
    });
    // Tauri commands return Result<T, String> — on success we get T directly
    // On error, invoke() throws with the error string
    nodes = (Array.isArray(result) ? result : []).map(mapNodeMeta);
  } catch (e) {
    error = e instanceof Error ? e.message : String(e);
    nodes = [];
  }
  loading = false;
}

function reset(): void {
  nodes = [];
  loading = false;
  error = null;
}

export const nodesStore = {
  get nodes() {
    return nodes;
  },
  get sortedNodes() {
    return sortedNodes;
  },
  get loading() {
    return loading;
  },
  get error() {
    return error;
  },
  get nodeById() {
    return nodeById;
  },
  load,
  reset,
};
