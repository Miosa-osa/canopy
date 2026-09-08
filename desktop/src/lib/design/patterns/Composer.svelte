<script lang="ts">
/**
 * Composer — primary prompt input surface.
 * Features: autogrow MentionInput (13px mono), agent picker popover,
 * runtime picker popover, cross-entity @mention with live dropdown, ⌘↵ submit.
 * No focus ring — border darkens on focus.
 *
 * @mention wiring: MentionInput handles the full dropdown lifecycle
 * (agents + workspaces + tasks + channels). Selecting an item inserts "@slug ".
 * The agent picker button still lets users pre-select an agent without typing @.
 */
import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
import { Bot, ChevronDown } from 'lucide-svelte';
import { hiredAgentsQuery } from '$lib/api/queries/agents.js';
import { runtimesQuery } from '$lib/api/queries/runtimes.js';
import type { Agent } from '$lib/domain/agents/types.js';
import type { Runtime } from '$lib/domain/runtimes/types.js';
import Kbd from './Kbd.svelte';
import MentionInput from './MentionInput.svelte';

interface Props {
  onSubmit?: (
    prompt: string,
    agentSlug: string | null,
    runtime: string | null,
    mentions?: string[]
  ) => void;
  placeholder?: string;
  value?: string;
  class?: string;
}

let {
  onSubmit,
  placeholder = 'What are we working on?',
  value = $bindable(''),
  class: className = '',
}: Props = $props();

// Hired agents from API — powers the agent picker button
const hiredQ = createQuery<Agent[]>(hiredAgentsQuery() as CreateQueryOptions<Agent[]>);
const hiredAgents = $derived(($hiredQ.data ?? []) as Agent[]);
const runtimesQ = createQuery<Runtime[]>(runtimesQuery() as CreateQueryOptions<Runtime[]>);
const runtimeOptions = $derived(
  dedupeRuntimes((($runtimesQ.data ?? []) as Runtime[]).filter((runtime) => runtime.kind === 'cli'))
);

let selectedAgent = $state<string | null>(null);
let selectedRuntime = $state<string | null>(null);
let agentPickerOpen = $state(false);
let runtimePickerOpen = $state(false);

/** Called by MentionInput on ⌘Enter or submit click. */
function handleMentionSubmit(text: string, mentions: string[]): void {
  const trimmed = text.trim();
  if (!trimmed) return;
  // If a mention in the text matches a hired agent, auto-select it
  const firstAgentMention = mentions.find((slug) => hiredAgents.some((a) => a.slug === slug));
  onSubmit?.(trimmed, selectedAgent ?? firstAgentMention ?? null, selectedRuntime, mentions);
  value = '';
}

/** Open agent picker button (distinct from @mention inline). */
function openAgentPicker(): void {
  agentPickerOpen = !agentPickerOpen;
  runtimePickerOpen = false;
}

/** Select an agent from the explicit agent picker button. */
function selectAgentFromPicker(agent: Agent): void {
  selectedAgent = agent.slug;
  agentPickerOpen = false;
}

function isRuntimeInstalled(runtime: Runtime): boolean {
  return (
    runtime.status === 'installed' ||
    (runtime as Runtime & { installed?: boolean }).installed === true
  );
}

function runtimeSubLabel(runtime: Runtime): string {
  if (!isRuntimeInstalled(runtime)) return 'not installed';
  return runtime.version || runtime.type;
}

function runtimeGroupKey(runtime: Runtime): string {
  if (runtime.binaryPath) return runtime.binaryPath;
  return runtime.type.replace(/-local$/, '');
}

function runtimeRank(runtime: Runtime): number {
  const priority = ['claude-local', 'codex-local', 'opencode-local', 'aider-local', 'gemini-local'];
  const priorityIndex = priority.indexOf(runtime.type);
  const priorityScore = priorityIndex === -1 ? 0 : 100 - priorityIndex;
  return (
    priorityScore +
    (isRuntimeInstalled(runtime) ? 20 : 0) +
    (runtime.type.endsWith('-local') ? 10 : 0) +
    (runtime.authProfile ? 2 : 0)
  );
}

function dedupeRuntimes(runtimes: Runtime[]): Runtime[] {
  const best = new Map<string, Runtime>();
  for (const runtime of runtimes) {
    const key = runtimeGroupKey(runtime);
    const existing = best.get(key);
    if (!existing || runtimeRank(runtime) > runtimeRank(existing)) {
      best.set(key, runtime);
    }
  }
  return [...best.values()].sort(
    (a, b) =>
      Number(isRuntimeInstalled(b)) - Number(isRuntimeInstalled(a)) ||
      runtimeRank(b) - runtimeRank(a) ||
      a.name.localeCompare(b.name)
  );
}
</script>

<div class="cnp-composer {className}">
  <!-- MentionInput replaces the raw textarea — handles @mention autocomplete + ⌘Enter -->
  <MentionInput
    bind:value
    {placeholder}
    onSubmit={handleMentionSubmit}
    class="cnp-composer__mention-input"
  />

  <!-- Bottom bar: agent picker | runtime picker | submit -->
  <div class="cnp-composer__bar">
    <div class="cnp-composer__pickers">
      <!-- Agent picker — explicit pre-selection; complements @mention inline -->
      <div class="cnp-picker-anchor">
        <button
          class="btn-compact btn-compact-secondary cnp-picker-btn"
          onclick={openAgentPicker}
          aria-expanded={agentPickerOpen}
          aria-label="Select agent"
        >
          <Bot size={12} aria-hidden="true" />
          {selectedAgent
            ? (hiredAgents.find((a) => a.slug === selectedAgent)?.name ?? selectedAgent)
            : '@agent'}
          <ChevronDown size={10} aria-hidden="true" />
        </button>

        {#if agentPickerOpen}
          <div class="cnp-picker-dropdown glass" role="listbox" aria-label="Select agent">
            {#if hiredAgents.length === 0}
              <p class="cnp-picker-empty">No hired agents yet.</p>
            {:else}
              {#each hiredAgents as a (a.slug)}
                <button
                  class="cnp-picker-option"
                  role="option"
                  aria-selected={selectedAgent === a.slug}
                  onclick={() => selectAgentFromPicker(a)}
                >
                  <span>{a.emoji}</span>
                  <span class="cnp-picker-option__name">{a.name}</span>
                  <span class="cnp-picker-option__sub">{a.category}</span>
                </button>
              {/each}
            {/if}
          </div>
        {/if}
      </div>

      <!-- Runtime picker -->
      <div class="cnp-picker-anchor">
        <button
          class="btn-compact btn-compact-secondary cnp-picker-btn"
          onclick={() => { runtimePickerOpen = !runtimePickerOpen; agentPickerOpen = false; }}
          aria-expanded={runtimePickerOpen}
          aria-label="Select runtime"
        >
          {selectedRuntime ? runtimeOptions.find((r) => r.type === selectedRuntime)?.name ?? selectedRuntime : '⚙ runtime'}
          <ChevronDown size={10} aria-hidden="true" />
        </button>

        {#if runtimePickerOpen}
          <div class="cnp-picker-dropdown glass" role="listbox" aria-label="Select runtime">
            {#if $runtimesQ.isLoading}
              <p class="cnp-picker-empty">Loading runtimes…</p>
            {:else if runtimeOptions.length === 0}
              <p class="cnp-picker-empty">No runtimes registered.</p>
            {:else}
              {#each runtimeOptions as r (r.type)}
                <button
                  class="cnp-picker-option"
                  role="option"
                  aria-selected={selectedRuntime === r.type}
                  disabled={!isRuntimeInstalled(r)}
                  onclick={() => { if (isRuntimeInstalled(r)) { selectedRuntime = r.type; runtimePickerOpen = false; } }}
                >
                  <span class="cnp-picker-option__name">{r.name}</span>
                  <span class="cnp-picker-option__sub">{runtimeSubLabel(r)}</span>
                </button>
              {/each}
            {/if}
          </div>
        {/if}
      </div>
    </div>

    <!-- Submit -->
    <button
      class="btn-pill btn-pill-primary btn-pill-sm cnp-composer__submit"
      onclick={() => handleMentionSubmit(value, [])}
      disabled={!value.trim()}
      aria-label="Submit prompt (⌘↵)"
    >
      Submit <Kbd chord="⌘↵" />
    </button>
  </div>
</div>

<!-- Click outside to close pickers -->
<svelte:document onclick={(e) => {
  if (!(e.target as Element).closest('.cnp-picker-anchor')) {
    agentPickerOpen = false;
    runtimePickerOpen = false;
  }
}} />


<style>
  .cnp-composer {
    display: flex;
    flex-direction: column;
  }

  /* MentionInput inherits its own border/bg; strip wrapper border so border
     isn't doubled. The MentionInput component itself handles focus styling. */
  :global(.cnp-composer .cnp-composer__mention-input) {
    border-radius: var(--radius-2xl) var(--radius-2xl) 0 0;
    border-bottom: none;
  }

  .cnp-composer__bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-2) var(--space-3);
    border-top: 1px solid var(--border);
    gap: var(--space-2);
  }

  .cnp-composer__pickers {
    display: flex;
    gap: var(--space-2);
    align-items: center;
  }

  .cnp-picker-anchor {
    position: relative;
  }

  .cnp-picker-btn {
    gap: 4px;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
  }

  .cnp-picker-dropdown {
    position: absolute;
    bottom: calc(100% + var(--space-2));
    left: 0;
    z-index: 100;
    min-width: 180px;
    border-radius: var(--radius-lg);
    padding: var(--space-1);
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .cnp-picker-option {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-3);
    border: none;
    background: transparent;
    border-radius: var(--radius-md);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    text-align: left;
    width: 100%;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .cnp-picker-option:hover,
  .cnp-picker-option[aria-selected='true'] {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
  }

  .cnp-picker-option:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  .cnp-picker-option:disabled:hover {
    background: transparent;
  }

  .cnp-picker-option__name {
    font-weight: 500;
  }

  .cnp-picker-option__sub {
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    margin-left: auto;
  }

  .cnp-picker-filter-label {
    margin: 0;
    padding: var(--space-1) var(--space-3);
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 500;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .cnp-picker-empty {
    margin: 0;
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    font-style: italic;
    text-align: center;
  }

  .cnp-composer__submit {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
  }
</style>
