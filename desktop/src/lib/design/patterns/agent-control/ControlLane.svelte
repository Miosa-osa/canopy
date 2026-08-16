<script lang="ts">
/**
 * ControlLane — a single swimlane dropzone in the Agent Control Center.
 * Wraps svelte-dnd-action, emits drop event with {agent, targetLane}.
 * CSS prefix: acl-
 * LOC target: ≤ 150.
 */
import { dndzone } from 'svelte-dnd-action';
import type { Agent } from '$lib/domain/agents/types.js';
import type { Session } from '$lib/domain/sessions/types.js';
import type { AgentLane } from './types.js';
import AgentControlCard from './AgentControlCard.svelte';

interface DndItem {
  id: string; // agent.slug
  agent: Agent;
}

interface Props {
  lane: AgentLane;
  label: string;
  color: string;
  agents: Agent[];
  scheduledSlugs: Set<string>;
  primarySessions: Map<string, Session>;
  selectedSlugs: Set<string>;
  onSelect: (slug: string, checked: boolean) => void;
  onPause: (sessionId: string) => void;
  onResume: (sessionId: string) => void;
  onDrop: (agent: Agent, targetLane: AgentLane) => void;
}

let {
  lane,
  label,
  color,
  agents,
  scheduledSlugs,
  primarySessions,
  selectedSlugs,
  onSelect,
  onPause,
  onResume,
  onDrop,
}: Props = $props();

// svelte-dnd-action needs items as objects with an `id` field.
let items = $state<DndItem[]>([]);

$effect(() => {
  items = agents.map((a) => ({ id: a.slug, agent: a }));
});

function handleConsider(e: CustomEvent<{ items: DndItem[] }>): void {
  items = e.detail.items;
}

function handleFinalize(e: CustomEvent<{ items: DndItem[]; info: { id: string } }>): void {
  items = e.detail.items;
  // Find the agent that was dropped into this lane.
  const movedSlug = e.detail.info.id;
  const movedItem = items.find((i) => i.id === movedSlug);
  if (movedItem) {
    onDrop(movedItem.agent, lane);
  }
}
</script>

<section class="acl-lane" aria-label="{label} lane">
  <header class="acl-header">
    <span class="acl-dot" style="background: {color};" aria-hidden="true"></span>
    <span class="acl-label">{label}</span>
    <span class="acl-count" aria-label="{agents.length} agents">{agents.length}</span>
  </header>

  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="acl-dropzone"
    use:dndzone={{ items, dropTargetStyle: {} }}
    onconsider={handleConsider}
    onfinalize={handleFinalize}
  >
    {#each items as item (item.id)}
      <AgentControlCard
        agent={item.agent}
        {lane}
        primarySession={primarySessions.get(item.agent.slug) ?? null}
        isScheduled={scheduledSlugs.has(item.agent.slug)}
        selected={selectedSlugs.has(item.agent.slug)}
        {onSelect}
        {onPause}
        {onResume}
      />
    {:else}
      <div class="acl-empty" aria-label="Nothing in {label} lane">
        <span class="acl-empty__text">Nothing here yet</span>
      </div>
    {/each}
  </div>
</section>

<style>
  .acl-lane {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    min-width: 220px;
    flex: 1;
  }

  .acl-header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-1) var(--space-1);
  }

  .acl-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .acl-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.07em;
    flex: 1;
  }

  .acl-count {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    padding: 1px 6px;
    border-radius: 999px;
    flex-shrink: 0;
  }

  .acl-dropzone {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    min-height: 80px;
    padding: var(--space-2);
    border: 1px dashed var(--border);
    border-radius: var(--radius-lg);
    background: color-mix(in oklch, var(--fg) 2%, transparent);
    flex: 1;
    transition: border-color var(--dur-instant) var(--ease-out),
      background var(--dur-instant) var(--ease-out);
  }

  .acl-dropzone:focus-within,
  .acl-dropzone[aria-dropeffect] {
    border-color: var(--cnp-accent, var(--fg-muted));
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }

  .acl-empty {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: var(--space-6) var(--space-2);
    flex: 1;
  }

  .acl-empty__text {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    font-style: italic;
  }
</style>
