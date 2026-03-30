// src/lib/stores/topology.svelte.ts
// Filesystem-backed topology store — reads topology.yaml via Tauri IPC
import { isTauri } from "$lib/utils/platform";
import type {
  TopologyData,
  TopologyPerson,
  TopologyEntity,
} from "$lib/types/filesystem";

/**
 * Minimal topology.yaml parser.
 * topology.yaml uses a flat structure with nodes and people sections.
 * Full YAML parsing deferred to Sprint 02 (js-yaml dependency).
 * For now, extract people entries using regex patterns.
 */
function parseTopologyYaml(raw: string): TopologyData {
  const entities: TopologyEntity[] = [];
  const people: TopologyPerson[] = [];

  // Extract people/team members: look for lines with "adapter:" field
  const lines = raw.split("\n");
  let currentPerson: Partial<TopologyPerson> | null = null;

  for (const line of lines) {
    const trimmed = line.trim();

    // Detect a new person entry (indented id with colon)
    const idMatch = trimmed.match(/^([a-z][\w-]+):$/);
    if (idMatch && currentPerson) {
      // Flush previous person
      if (currentPerson.id && currentPerson.name) {
        people.push(currentPerson as TopologyPerson);
      }
      currentPerson = { id: idMatch[1], name: "", role: "", adapter: "human" };
      continue;
    }
    if (idMatch && !currentPerson) {
      currentPerson = { id: idMatch[1], name: "", role: "", adapter: "human" };
      continue;
    }

    if (currentPerson) {
      const kvMatch = trimmed.match(/^(\w+):\s*"?([^"]*)"?$/);
      if (kvMatch) {
        const [, key, value] = kvMatch;
        if (key === "name") currentPerson.name = value;
        else if (key === "role") currentPerson.role = value;
        else if (key === "adapter") currentPerson.adapter = value;
        else if (key === "node") currentPerson.node = value;
        else if (key === "status") currentPerson.status = value;
      }
    }
  }

  // Flush last person
  if (currentPerson?.id && currentPerson?.name) {
    people.push(currentPerson as TopologyPerson);
  }

  return { entities, people };
}

let topology = $state<TopologyData | null>(null);
let loading = $state(false);
let error = $state<string | null>(null);

const people = $derived(topology?.people ?? []);
const entities = $derived(topology?.entities ?? []);
const humanPeople = $derived(people.filter((p) => p.adapter === "human"));
const aiAgents = $derived(people.filter((p) => p.adapter !== "human"));

async function load(workspacePath: string): Promise<void> {
  if (!isTauri()) return;
  loading = true;
  error = null;
  try {
    const { invoke } = await import("@tauri-apps/api/core");
    const raw = await invoke<string>("read_topology_yaml", {
      workspacePath,
    });
    // read_topology_yaml returns raw YAML string — parse minimally
    const result = parseTopologyYaml(raw);
    topology = result;
  } catch (e) {
    error = e instanceof Error ? e.message : String(e);
    topology = null;
  }
  loading = false;
}

function reset(): void {
  topology = null;
  loading = false;
  error = null;
}

export const topologyStore = {
  get topology() {
    return topology;
  },
  get people() {
    return people;
  },
  get entities() {
    return entities;
  },
  get humanPeople() {
    return humanPeople;
  },
  get aiAgents() {
    return aiAgents;
  },
  get loading() {
    return loading;
  },
  get error() {
    return error;
  },
  load,
  reset,
};
