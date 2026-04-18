<script lang="ts">
/**
 * Composer — primary prompt input surface (Cabinet pattern lift).
 * Features: autogrow textarea (13px mono), agent picker popover,
 * runtime picker popover, @mention trigger with live hired-agents list, ⌘↵ submit.
 * No focus ring — border darkens on focus (Cabinet detail).
 *
 * @mention wiring (Mission 4): on @ keypress, opens a popover seeded from
 * hiredAgentsQuery(). Filtered by text after @ up to next whitespace.
 * Selecting an agent inserts "@slug " chip and sets selectedAgent.
 */
import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
import { Bot, ChevronDown } from 'lucide-svelte';
import { hiredAgentsQuery } from '$lib/api/queries/agents.js';
import type { Agent } from '$lib/domain/agents/types.js';
import Kbd from './Kbd.svelte';

interface Props {
  onSubmit?: (prompt: string, agentSlug: string | null, runtime: string | null) => void;
  placeholder?: string;
  class?: string;
}

let { onSubmit, placeholder = 'What are we working on?', class: className = '' }: Props = $props();

// Hired agents from API — powers @mention dropdown
const hiredQ = createQuery<Agent[]>(hiredAgentsQuery() as CreateQueryOptions<Agent[]>);
const hiredAgents = $derived(($hiredQ.data ?? []) as Agent[]);

let prompt = $state('');
let selectedAgent = $state<string | null>(null);
let selectedRuntime = $state<string | null>(null);
let focused = $state(false);
let textareaEl = $state<HTMLTextAreaElement | null>(null);
let agentPickerOpen = $state(false);
let runtimePickerOpen = $state(false);
/** Text after the last @ for filtering the @mention dropdown. */
let mentionFilter = $state('');

// Filter hired agents by mentionFilter text
const filteredMentionAgents = $derived(
  mentionFilter
    ? hiredAgents.filter(
        (a) =>
          a.name.toLowerCase().includes(mentionFilter.toLowerCase()) ||
          a.slug.toLowerCase().includes(mentionFilter.toLowerCase())
      )
    : hiredAgents
);

/** Autogrow the textarea on each input event. */
function handleInput(): void {
  const el = textareaEl;
  if (!el) return;
  el.style.height = 'auto';
  el.style.height = `${el.scrollHeight}px`;

  // Handle @ trigger for agent mention dropdown
  const val = prompt;
  const cursor = el.selectionStart ?? 0;
  const beforeCursor = val.slice(0, cursor);
  const atIdx = beforeCursor.lastIndexOf('@');
  if (atIdx !== -1) {
    const afterAt = beforeCursor.slice(atIdx + 1);
    // Only open if no whitespace between @ and cursor (still typing the mention)
    if (!afterAt.includes(' ') && !afterAt.includes('\n')) {
      mentionFilter = afterAt;
      agentPickerOpen = true;
      return;
    }
  }
  agentPickerOpen = false;
  mentionFilter = '';
}

function handleKeydown(e: KeyboardEvent): void {
  if (e.key === 'Enter' && e.metaKey) {
    e.preventDefault();
    handleSubmit();
  }
  if (e.key === 'Escape') {
    agentPickerOpen = false;
    runtimePickerOpen = false;
  }
}

function handleSubmit(): void {
  const trimmed = prompt.trim();
  if (!trimmed) return;
  onSubmit?.(trimmed, selectedAgent, selectedRuntime);
  prompt = '';
  if (textareaEl) {
    textareaEl.style.height = 'auto';
  }
}

/** Select an agent from the @mention dropdown. Replaces the @… fragment with @slug chip. */
function selectMentionAgent(agent: Agent): void {
  const el = textareaEl;
  if (!el) return;
  const cursor = el.selectionStart ?? 0;
  const beforeCursor = prompt.slice(0, cursor);
  const atIdx = beforeCursor.lastIndexOf('@');
  const afterCursor = prompt.slice(cursor);
  // Replace @<filter> with @slug followed by a space
  const replacement = `@${agent.slug} `;
  prompt = beforeCursor.slice(0, atIdx) + replacement + afterCursor;
  selectedAgent = agent.slug;
  agentPickerOpen = false;
  mentionFilter = '';
  // Restore focus + move cursor after the inserted chip
  setTimeout(() => {
    el.focus();
    const newPos = atIdx + replacement.length;
    el.setSelectionRange(newPos, newPos);
  }, 0);
}

/** Open agent picker button (distinct from @mention inline). */
function openAgentPicker(): void {
  agentPickerOpen = !agentPickerOpen;
  runtimePickerOpen = false;
  mentionFilter = '';
}

const runtimeOptions = [
  { slug: 'claude-code', name: 'Claude Code', model: 'claude-3-5-sonnet' },
  { slug: 'codex', name: 'Codex', model: 'o3' },
  { slug: 'gemini', name: 'Gemini', model: 'gemini-2.0-pro' },
];
</script>

<div class="cnp-composer {className}" class:cnp-composer--focused={focused}>
  <!-- Prompt textarea -->
  <textarea
    bind:this={textareaEl}
    bind:value={prompt}
    class="cnp-composer__input"
    {placeholder}
    rows="3"
    oninput={handleInput}
    onkeydown={handleKeydown}
    onfocus={() => { focused = true; }}
    onblur={() => { focused = false; }}
    aria-label="Prompt composer"
    autocomplete="off"
    spellcheck="true"
  ></textarea>

  <!-- Bottom bar: agent picker | runtime picker | submit -->
  <div class="cnp-composer__bar">
    <div class="cnp-composer__pickers">
      <!-- Agent picker — seeds from hiredAgentsQuery; also used by @mention -->
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
            {#if mentionFilter}
              <p class="cnp-picker-filter-label">Agents matching "{mentionFilter}"</p>
            {/if}
            {#if filteredMentionAgents.length === 0}
              <p class="cnp-picker-empty">
                {hiredAgents.length === 0 ? 'No hired agents yet.' : 'No matches.'}
              </p>
            {:else}
              {#each filteredMentionAgents as a (a.slug)}
                <button
                  class="cnp-picker-option"
                  role="option"
                  aria-selected={selectedAgent === a.slug}
                  onclick={() => selectMentionAgent(a)}
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
          {selectedRuntime ? runtimeOptions.find((r) => r.slug === selectedRuntime)?.name ?? 'Runtime' : '⚙ runtime'}
          <ChevronDown size={10} aria-hidden="true" />
        </button>

        {#if runtimePickerOpen}
          <div class="cnp-picker-dropdown glass" role="listbox" aria-label="Select runtime">
            {#each runtimeOptions as r (r.slug)}
              <button
                class="cnp-picker-option"
                role="option"
                aria-selected={selectedRuntime === r.slug}
                onclick={() => { selectedRuntime = r.slug; runtimePickerOpen = false; }}
              >
                <span class="cnp-picker-option__name">{r.name}</span>
                <span class="cnp-picker-option__sub">{r.model}</span>
              </button>
            {/each}
          </div>
        {/if}
      </div>
    </div>

    <!-- Submit -->
    <button
      class="btn-pill btn-pill-primary btn-pill-sm cnp-composer__submit"
      onclick={handleSubmit}
      disabled={!prompt.trim()}
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
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: var(--radius-2xl);
    transition: border-color var(--dur-instant) var(--ease-out);
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .cnp-composer--focused {
    border-color: var(--border-strong);
  }

  .cnp-composer__input {
    font-family: var(--font-mono);
    font-size: 13px;
    line-height: 1.6;
    color: var(--fg);
    background: transparent;
    border: none;
    outline: none;
    resize: none;
    padding: var(--space-4);
    min-height: 80px;
    max-height: 320px;
    width: 100%;
    box-sizing: border-box;
  }

  .cnp-composer__input::placeholder {
    color: var(--fg-subtle);
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
