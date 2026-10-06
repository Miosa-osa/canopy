/**
 * palette-setup.ts
 *
 * Registers all command palette built-ins and dynamic search sources.
 * Call once from the app layout's onMount after stores are available.
 */

import { paletteStore } from "$lib/stores/palette.svelte";
import { nodesStore } from "$lib/stores/nodes.svelte";
import { topologyStore } from "$lib/stores/topology.svelte";

export function setupPalette(goto: (path: string) => Promise<void>): void {
  paletteStore.registerBuiltins(goto, {
    restartBackend: () => void goto("/app/system"),
  });

  paletteStore.registerSearchSources([
    {
      type: "Node",
      icon: "folder-tree",
      items: () =>
        nodesStore.sortedNodes.map((n) => ({
          id: n.id,
          name: n.name,
          description: n.type,
        })),
      action: (item) => void goto(`/app/nodes/${item.id}`),
    },
    {
      type: "Team",
      icon: "user",
      items: () =>
        topologyStore.humanPeople.map((p) => ({
          id: p.id,
          name: p.name,
          description: p.role,
        })),
      action: (item) => void goto(`/app/team/${item.id}`),
    },
    {
      type: "AI Agent",
      icon: "cpu",
      items: () =>
        topologyStore.aiAgents.map((a) => ({
          id: a.id,
          name: a.name,
          description: a.role,
        })),
      action: (item) => void goto(`/app/agents/${item.id}`),
    },
  ]);
}
