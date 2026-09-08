<script lang="ts">
/**
 * PersonaEditor — system prompt textarea + category picker + trait tags.
 * CSS prefix: pe- (PersonaEditor)
 */
import type { AgentCategory, AgentDetail } from '$lib/domain/agents/types.js';
import { renderMarkdown } from '$lib/utils/markdown.js';

interface Props {
  agent: AgentDetail;
  onSave: (systemPrompt: string, traits: string[]) => void;
  isSaving: boolean;
}

let { agent, onSave, isSaving }: Props = $props();

let editText = $state('');
let traitInput = $state('');
let traits = $state<string[]>([]);
let viewMode = $state<'edit' | 'preview'>('edit');

// Sync editText with agent prop reactively
$effect(() => {
  editText = agent.personaMarkdown ?? '';
});

const isDirty = $derived(editText !== (agent.personaMarkdown ?? ''));
const renderedHtml = $derived(viewMode === 'preview' && editText ? renderMarkdown(editText) : '');

function handleKeydown(e: KeyboardEvent) {
  if ((e.metaKey || e.ctrlKey) && e.key === 's') {
    e.preventDefault();
    if (isDirty) onSave(editText, traits);
  }
}

function addTrait(e: KeyboardEvent) {
  if (e.key === 'Enter' && traitInput.trim()) {
    e.preventDefault();
    const next = traitInput.trim().toLowerCase().replace(/\s+/g, '-');
    if (!traits.includes(next)) traits = [...traits, next];
    traitInput = '';
  }
}

function removeTrait(t: string) {
  traits = traits.filter((x) => x !== t);
}

const CATEGORIES: Array<{ value: AgentCategory; label: string }> = [
  { value: 'academic', label: 'Academic' },
  { value: 'creative-content', label: 'Creative Content' },
  { value: 'design', label: 'Design' },
  { value: 'engineering', label: 'Engineering' },
  { value: 'executive', label: 'Executive' },
  { value: 'game-development', label: 'Game Development' },
  { value: 'growth', label: 'Growth' },
  { value: 'marketing', label: 'Marketing' },
  { value: 'operations', label: 'Operations' },
  { value: 'paid-media', label: 'Paid Media' },
  { value: 'product', label: 'Product' },
  { value: 'project-management', label: 'Project Management' },
  { value: 'revenue', label: 'Revenue' },
  { value: 'sales', label: 'Sales' },
  { value: 'spatial-computing', label: 'Spatial Computing' },
  { value: 'specialized', label: 'Specialized' },
  { value: 'support', label: 'Support' },
  { value: 'technology', label: 'Technology' },
  { value: 'testing', label: 'Testing' },
];

let selectedCategory = $state<AgentCategory>('engineering');
$effect(() => {
  selectedCategory = agent.category;
});
</script>

<div class="pe-root">
  <!-- Toolbar -->
  <div class="pe-toolbar">
    <div class="pe-mode-toggle" role="group" aria-label="Editor mode">
      <button
        class="pe-mode-btn"
        class:pe-mode-btn--active={viewMode === 'edit'}
        onclick={() => (viewMode = 'edit')}
        aria-pressed={viewMode === 'edit'}
      >
        Edit
      </button>
      <button
        class="pe-mode-btn"
        class:pe-mode-btn--active={viewMode === 'preview'}
        onclick={() => (viewMode = 'preview')}
        aria-pressed={viewMode === 'preview'}
      >
        Preview
      </button>
    </div>

    <div class="pe-toolbar-right">
      {#if isDirty}
        <span class="pe-dirty-badge" aria-live="polite">Unsaved changes</span>
      {/if}
      <button
        class="btn-pill btn-pill-primary btn-pill-sm"
        onclick={() => onSave(editText, traits)}
        disabled={!isDirty || isSaving}
        aria-busy={isSaving}
      >
        {isSaving ? 'Saving…' : 'Save'}
      </button>
    </div>
  </div>

  <!-- System prompt -->
  <div class="pe-field">
    <label class="pe-label" for="pe-prompt">System prompt</label>
    {#if viewMode === 'preview'}
      <div class="pe-preview">
        <!-- eslint-disable-next-line svelte/no-at-html-tags -->
        {@html renderedHtml}
      </div>
    {:else}
      <textarea
        id="pe-prompt"
        class="pe-textarea"
        bind:value={editText}
        onkeydown={handleKeydown}
        rows={20}
        placeholder="Describe what this agent does and how it should behave…"
        aria-label="System prompt editor"
        spellcheck="false"
      ></textarea>
      <span class="pe-hint">⌘S to save</span>
    {/if}
  </div>

  <!-- Category -->
  <div class="pe-field">
    <label class="pe-label" for="pe-category">Category</label>
    <select id="pe-category" class="pe-select" bind:value={selectedCategory}>
      {#each CATEGORIES as cat (cat.value)}
        <option value={cat.value}>{cat.label}</option>
      {/each}
    </select>
  </div>

  <!-- Trait tags -->
  <div class="pe-field">
    <label class="pe-label" for="pe-trait-input">Personality traits</label>
    <div class="pe-traits">
      {#each traits as t (t)}
        <span class="pe-trait">
          {t}
          <button
            class="pe-trait-remove"
            onclick={() => removeTrait(t)}
            aria-label="Remove trait {t}"
          >×</button>
        </span>
      {/each}
      <input
        id="pe-trait-input"
        class="pe-trait-input"
        type="text"
        placeholder="Add trait…"
        bind:value={traitInput}
        onkeydown={addTrait}
        aria-label="Add personality trait (press Enter)"
      />
    </div>
    <span class="pe-hint">Press Enter to add a trait tag (e.g. concise, empathetic, direct)</span>
  </div>
</div>

<style>
  .pe-root {
    display: flex;
    flex-direction: column;
    gap: var(--space-5);
    padding: var(--space-6);
    max-width: 800px;
  }

  .pe-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
  }

  .pe-toolbar-right {
    display: flex;
    align-items: center;
    gap: var(--space-3);
  }

  .pe-mode-toggle {
    display: flex;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    overflow: hidden;
  }

  .pe-mode-btn {
    padding: var(--space-1) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    background: transparent;
    border: none;
    cursor: pointer;
    transition: background 0.1s, color 0.1s;
  }

  .pe-mode-btn:hover {
    color: var(--fg);
  }

  .pe-mode-btn--active {
    background: color-mix(in oklch, var(--fg) 10%, transparent);
    color: var(--fg);
  }

  .pe-dirty-badge {
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-muted);
    padding: 2px 8px;
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    border: 1px solid var(--border);
    border-radius: 9999px;
  }

  .pe-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .pe-label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 500;
    letter-spacing: 0.05em;
    text-transform: uppercase;
    color: var(--fg-muted);
  }

  .pe-textarea {
    width: 100%;
    min-height: 400px;
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    line-height: 1.7;
    color: var(--fg);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-4);
    resize: vertical;
    outline: none;
    box-sizing: border-box;
    transition: border-color 0.1s;
  }

  .pe-textarea:focus {
    border-color: var(--cnp-accent, oklch(0.55 0.18 250));
    box-shadow: 0 0 0 2px color-mix(in oklch, var(--cnp-accent, oklch(0.55 0.18 250)) 12%, transparent);
  }

  .pe-preview {
    min-height: 200px;
    padding: var(--space-4);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    line-height: 1.7;
  }

  .pe-select {
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    width: 100%;
    max-width: 320px;
    box-sizing: border-box;
    appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%23888' d='M6 8L1 3h10z'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right var(--space-3) center;
    padding-right: calc(var(--space-3) + 20px);
    cursor: pointer;
    transition: border-color 0.1s;
  }

  .pe-select:focus {
    border-color: var(--cnp-accent, oklch(0.55 0.18 250));
  }

  .pe-hint {
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
  }

  /* Trait tags */
  .pe-traits {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-1);
    align-items: center;
    padding: var(--space-2) var(--space-3);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    min-height: 38px;
    transition: border-color 0.1s;
  }

  .pe-traits:focus-within {
    border-color: var(--cnp-accent, oklch(0.55 0.18 250));
  }

  .pe-trait {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 2px 8px;
    background: color-mix(in oklch, var(--fg) 10%, transparent);
    border: 1px solid var(--border);
    border-radius: 9999px;
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg);
  }

  .pe-trait-remove {
    background: none;
    border: none;
    padding: 0;
    cursor: pointer;
    color: var(--fg-subtle);
    font-size: 14px;
    line-height: 1;
    display: flex;
    align-items: center;
    transition: color 0.1s;
  }

  .pe-trait-remove:hover {
    color: var(--fg);
  }

  .pe-trait-input {
    flex: 1;
    min-width: 100px;
    background: transparent;
    border: none;
    outline: none;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
  }

  .pe-trait-input::placeholder {
    color: var(--fg-subtle);
  }
</style>
