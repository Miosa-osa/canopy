<script lang="ts">
/**
 * Composer — primary prompt input surface (Cabinet pattern lift).
 * Features: autogrow textarea (13px mono), agent picker popover,
 * runtime picker popover, @mention trigger, ⌘↵ submit.
 * No focus ring — border darkens on focus (Cabinet detail).
 * LOC target: ≤ 150.
 */
import { Bot, ChevronDown } from 'lucide-svelte';
import Kbd from './Kbd.svelte';

interface Props {
  onSubmit?: (prompt: string, agentSlug: string | null, runtime: string | null) => void;
  placeholder?: string;
  class?: string;
}

let { onSubmit, placeholder = 'What are we working on?', class: className = '' }: Props = $props();

let prompt = $state('');
let selectedAgent = $state<string | null>(null);
let selectedRuntime = $state<string | null>(null);
let focused = $state(false);
let textareaEl = $state<HTMLTextAreaElement | null>(null);
let agentPickerOpen = $state(false);
let runtimePickerOpen = $state(false);

/** Autogrow the textarea on each input event. */
function handleInput(): void {
  const el = textareaEl;
  if (!el) return;
  el.style.height = 'auto';
  el.style.height = `${el.scrollHeight}px`;

  // Handle @ trigger for agent picker
  const val = prompt;
  const cursor = el.selectionStart ?? 0;
  if (val[cursor - 1] === '@') {
    agentPickerOpen = true;
  }
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

/** Quick agent options for MVP — Week 1 uses static list; Day 3 seeds real data. */
const agentOptions = [
  { slug: 'sales-strategist', name: 'Sales Strategist', emoji: '📊' },
  { slug: 'architect', name: 'Architect', emoji: '🏗️' },
  { slug: 'copy-doctor', name: 'Copy Doctor', emoji: '✍️' },
];

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
      <!-- Agent picker -->
      <div class="cnp-picker-anchor">
        <button
          class="btn-compact btn-compact-secondary cnp-picker-btn"
          onclick={() => { agentPickerOpen = !agentPickerOpen; }}
          aria-expanded={agentPickerOpen}
          aria-label="Select agent"
        >
          <Bot size={12} aria-hidden="true" />
          {selectedAgent ? agentOptions.find(a => a.slug === selectedAgent)?.name ?? 'Agent' : '@agent'}
          <ChevronDown size={10} aria-hidden="true" />
        </button>

        {#if agentPickerOpen}
          <div class="cnp-picker-dropdown glass" role="listbox" aria-label="Select agent">
            {#each agentOptions as a (a.slug)}
              <button
                class="cnp-picker-option"
                role="option"
                aria-selected={selectedAgent === a.slug}
                onclick={() => { selectedAgent = a.slug; agentPickerOpen = false; }}
              >
                <span>{a.emoji}</span>
                <span>{a.name}</span>
              </button>
            {/each}
          </div>
        {/if}
      </div>

      <!-- Runtime picker -->
      <div class="cnp-picker-anchor">
        <button
          class="btn-compact btn-compact-secondary cnp-picker-btn"
          onclick={() => { runtimePickerOpen = !runtimePickerOpen; }}
          aria-expanded={runtimePickerOpen}
          aria-label="Select runtime"
        >
          {selectedRuntime ? runtimeOptions.find(r => r.slug === selectedRuntime)?.name ?? 'Runtime' : '⚙ runtime'}
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

  .cnp-composer__submit {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
  }
</style>
