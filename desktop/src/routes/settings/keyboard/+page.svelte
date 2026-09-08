<script lang="ts">
/**
 * Settings › Keyboard Shortcuts — editable keybindings grid.
 * Groups bindings by category, inline chord capture, conflict detection.
 * CSS prefix: kbd-
 */

import type { KeyBinding } from '$lib/stores/keybindings.svelte.js';
import { captureChord, chordToDisplayTokens, keybindings } from '$lib/stores/keybindings.svelte.js';

// ── Search ────────────────────────────────────────────────────────────────────

let searchQuery = $state('');

const filteredBindings = $derived(() => {
  const q = searchQuery.trim().toLowerCase();
  if (!q) return keybindings.bindings;
  return keybindings.bindings.filter(
    (b) =>
      b.label.toLowerCase().includes(q) ||
      (b.custom ?? b.defaultChord).toLowerCase().includes(q) ||
      b.category.toLowerCase().includes(q)
  );
});

// ── Categories (ordered, deduped from filtered set) ───────────────────────────

const categories = $derived(() => {
  const seen = new Set<string>();
  const order: string[] = [];
  for (const b of filteredBindings()) {
    if (!seen.has(b.category)) {
      seen.add(b.category);
      order.push(b.category);
    }
  }
  return order;
});

function bindingsForCategory(cat: string): KeyBinding[] {
  return filteredBindings().filter((b) => b.category === cat);
}

// ── Collapsed state per category ─────────────────────────────────────────────

let collapsed = $state<Record<string, boolean>>({});

function toggleCollapse(cat: string): void {
  collapsed[cat] = !collapsed[cat];
}

// ── Edit / capture state ──────────────────────────────────────────────────────

let editingId = $state<string | null>(null);
let capturedChord = $state<string | null>(null);

function startEdit(id: string): void {
  editingId = id;
  capturedChord = null;
}

function cancelEdit(): void {
  editingId = null;
  capturedChord = null;
}

function confirmEdit(): void {
  if (editingId && capturedChord) {
    keybindings.setChord(editingId, capturedChord);
  }
  editingId = null;
  capturedChord = null;
}

function handleWindowKeydown(e: KeyboardEvent): void {
  if (!editingId) return;

  if (e.key === 'Escape') {
    e.preventDefault();
    cancelEdit();
    return;
  }

  if (e.key === 'Enter' && capturedChord) {
    e.preventDefault();
    confirmEdit();
    return;
  }

  const chord = captureChord(e);
  if (chord) {
    e.preventDefault();
    capturedChord = chord;
  }
}

// Conflict: binding that already uses the captured chord (excluding current)
const conflict = $derived(
  editingId && capturedChord ? keybindings.hasConflict(capturedChord, editingId) : null
);

// ── Reset all ─────────────────────────────────────────────────────────────────

function resetAll(): void {
  keybindings.resetAll();
  editingId = null;
  capturedChord = null;
}

// ── Display helpers ───────────────────────────────────────────────────────────

function hasCustom(b: KeyBinding): boolean {
  return b.custom !== undefined;
}

function displayChord(b: KeyBinding): string {
  return b.custom ?? b.defaultChord;
}

const customCount = $derived(keybindings.bindings.filter((b) => b.custom !== undefined).length);
</script>

<svelte:window onkeydown={handleWindowKeydown} />

<div class="kbd-page">
  <!-- Header row: description + search + reset all -->
  <div class="kbd-header">
    <p class="kbd-desc">Customize keyboard shortcuts. Click a binding to rebind it.</p>
    <div class="kbd-header-actions">
      <div class="kbd-search-wrap">
        <svg class="kbd-search-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
        </svg>
        <input
          class="kbd-search"
          type="search"
          placeholder="Filter shortcuts..."
          bind:value={searchQuery}
          aria-label="Filter keyboard shortcuts"
        />
      </div>
      {#if customCount > 0}
        <button class="kbd-reset-all" type="button" onclick={resetAll} aria-label="Reset all bindings to defaults">
          Reset all ({customCount})
        </button>
      {/if}
    </div>
  </div>

  <!-- Binding groups -->
  <div class="kbd-sections">
    {#each categories() as cat (cat)}
      {@const rows = bindingsForCategory(cat)}
      {@const isCollapsed = collapsed[cat] ?? false}
      <section class="kbd-section" aria-labelledby="kbd-cat-{cat}">
        <button
          class="kbd-section-header"
          type="button"
          id="kbd-cat-{cat}"
          aria-expanded={!isCollapsed}
          onclick={() => toggleCollapse(cat)}
        >
          <svg
            class="kbd-chevron"
            class:kbd-chevron--collapsed={isCollapsed}
            width="12" height="12" viewBox="0 0 24 24" fill="none"
            stroke="currentColor" stroke-width="2.5"
            stroke-linecap="round" stroke-linejoin="round"
            aria-hidden="true"
          >
            <polyline points="6 9 12 15 18 9"/>
          </svg>
          <span>{cat}</span>
          <span class="kbd-section-count">{rows.length}</span>
        </button>

        {#if !isCollapsed}
          <div class="kbd-grid" role="list">
            {#each rows as binding (binding.id)}
              {@const isEditing = editingId === binding.id}
              <div
                class="kbd-row"
                class:kbd-row--editing={isEditing}
                class:kbd-row--custom={hasCustom(binding)}
                role="listitem"
              >
                <!-- Action label -->
                <span class="kbd-label">{binding.label}</span>

                <!-- Chord display / capture -->
                <div class="kbd-chord-cell">
                  {#if isEditing}
                    <div class="kbd-capture" aria-live="polite">
                      {#if capturedChord}
                        <div class="kbd-keys">
                          {#each chordToDisplayTokens(capturedChord) as token, i (i)}
                            <kbd class="kbd-key kbd-key--captured">{token}</kbd>
                            {#if i < chordToDisplayTokens(capturedChord).length - 1}
                              <span class="kbd-plus" aria-hidden="true">+</span>
                            {/if}
                          {/each}
                        </div>
                        {#if conflict}
                          <span class="kbd-conflict" role="alert">
                            Conflicts with "{conflict.label}"
                          </span>
                        {/if}
                      {:else}
                        <span class="kbd-press-hint">Press keys…</span>
                      {/if}
                    </div>
                  {:else}
                    <!-- Normal display — double-click to edit -->
                    <button
                      class="kbd-chord-btn"
                      type="button"
                      title="Click to rebind"
                      aria-label="Rebind {binding.label}: currently {displayChord(binding)}"
                      ondblclick={() => startEdit(binding.id)}
                      onclick={() => startEdit(binding.id)}
                    >
                      <div class="kbd-keys">
                        {#each chordToDisplayTokens(displayChord(binding)) as token, i (i)}
                          <kbd class="kbd-key">{token}</kbd>
                          {#if i < chordToDisplayTokens(displayChord(binding)).length - 1}
                            <span class="kbd-plus" aria-hidden="true">+</span>
                          {/if}
                        {/each}
                      </div>
                      {#if hasCustom(binding)}
                        <span class="kbd-custom-badge" aria-label="Custom binding">•</span>
                      {/if}
                    </button>
                  {/if}
                </div>

                <!-- Actions -->
                <div class="kbd-actions">
                  {#if isEditing}
                    <button
                      class="kbd-action-btn kbd-action-btn--confirm"
                      type="button"
                      disabled={!capturedChord}
                      onclick={confirmEdit}
                      aria-label="Confirm new binding"
                    >Save</button>
                    <button
                      class="kbd-action-btn kbd-action-btn--cancel"
                      type="button"
                      onclick={cancelEdit}
                      aria-label="Cancel editing"
                    >Cancel</button>
                  {:else}
                    <button
                      class="kbd-action-btn kbd-action-btn--edit"
                      type="button"
                      onclick={() => startEdit(binding.id)}
                      aria-label="Edit binding for {binding.label}"
                    >Edit</button>
                    {#if hasCustom(binding)}
                      <button
                        class="kbd-action-btn kbd-action-btn--reset"
                        type="button"
                        onclick={() => keybindings.resetToDefault(binding.id)}
                        aria-label="Reset {binding.label} to default"
                        title="Reset to {binding.defaultChord}"
                      >Reset</button>
                    {/if}
                  {/if}
                </div>
              </div>
            {/each}
          </div>
        {/if}
      </section>
    {/each}

    {#if filteredBindings().length === 0}
      <p class="kbd-empty">No shortcuts match "{searchQuery}".</p>
    {/if}
  </div>
</div>

<style>
  /* ── Page shell ──────────────────────────────────────────────────────────── */

  .kbd-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-5);
    max-width: 780px;
  }

  /* ── Header ──────────────────────────────────────────────────────────────── */

  .kbd-header {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .kbd-desc {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
  }

  .kbd-header-actions {
    display: flex;
    align-items: center;
    gap: var(--space-3);
  }

  /* ── Search ──────────────────────────────────────────────────────────────── */

  .kbd-search-wrap {
    position: relative;
    flex: 1;
    max-width: 320px;
  }

  .kbd-search-icon {
    position: absolute;
    left: 9px;
    top: 50%;
    transform: translateY(-50%);
    color: var(--fg-subtle);
    pointer-events: none;
  }

  .kbd-search {
    width: 100%;
    padding: 5px 10px 5px 28px;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--bg-inset);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    box-sizing: border-box;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .kbd-search::placeholder { color: var(--fg-subtle); }

  .kbd-search:focus {
    border-color: var(--cnp-accent, oklch(0.72 0.18 145));
  }

  /* ── Reset all ───────────────────────────────────────────────────────────── */

  .kbd-reset-all {
    appearance: none;
    border: 1px solid var(--border);
    background: transparent;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    padding: 4px 10px;
    border-radius: var(--radius-sm);
    cursor: pointer;
    white-space: nowrap;
    transition:
      color var(--dur-instant) var(--ease-out),
      border-color var(--dur-instant) var(--ease-out),
      background var(--dur-instant) var(--ease-out);
  }

  .kbd-reset-all:hover {
    color: var(--fg);
    border-color: var(--fg-subtle);
    background: color-mix(in oklch, var(--fg) 5%, transparent);
  }

  /* ── Sections ────────────────────────────────────────────────────────────── */

  .kbd-sections {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }

  .kbd-section {
    display: flex;
    flex-direction: column;
  }

  .kbd-section-header {
    appearance: none;
    background: none;
    border: none;
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-1-5) var(--space-2);
    border-radius: var(--radius-sm);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--fg-subtle);
    text-align: left;
    border-bottom: 1px solid var(--border);
    transition: background var(--dur-instant) var(--ease-out);
    margin-bottom: var(--space-1);
  }

  .kbd-section-header:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }

  .kbd-chevron {
    flex-shrink: 0;
    transition: transform 0.15s var(--ease-out);
    color: var(--fg-subtle);
  }

  .kbd-chevron--collapsed {
    transform: rotate(-90deg);
  }

  .kbd-section-count {
    margin-left: auto;
    font-size: 10px;
    font-weight: 400;
    letter-spacing: 0;
    color: var(--fg-subtle);
  }

  /* ── Grid rows ───────────────────────────────────────────────────────────── */

  .kbd-grid {
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .kbd-row {
    display: grid;
    grid-template-columns: 1fr 180px 130px;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-1-5) var(--space-2);
    border-radius: var(--radius-sm);
    border: 1px solid transparent;
    transition:
      background var(--dur-instant) var(--ease-out),
      border-color var(--dur-instant) var(--ease-out);
  }

  .kbd-row:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }

  .kbd-row--editing {
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 6%, transparent);
    border-color: var(--cnp-accent, oklch(0.72 0.18 145));
  }

  .kbd-row--custom .kbd-label {
    color: var(--fg);
  }

  /* ── Label ───────────────────────────────────────────────────────────────── */

  .kbd-label {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  /* ── Chord cell ──────────────────────────────────────────────────────────── */

  .kbd-chord-cell {
    display: flex;
    align-items: center;
  }

  .kbd-chord-btn {
    appearance: none;
    background: none;
    border: none;
    padding: 0;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .kbd-keys {
    display: flex;
    align-items: center;
    gap: 3px;
    flex-wrap: nowrap;
  }

  .kbd-key {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 22px;
    height: 20px;
    padding: 0 5px;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: color-mix(in oklch, var(--fg) 5%, transparent);
    font-family: var(--font-mono);
    font-size: 11px;
    font-weight: 500;
    color: var(--fg-muted);
    white-space: nowrap;
    user-select: none;
  }

  .kbd-key--captured {
    border-color: var(--cnp-accent, oklch(0.72 0.18 145));
    color: var(--fg);
  }

  .kbd-plus {
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--fg-subtle);
    user-select: none;
  }

  .kbd-custom-badge {
    font-size: 16px;
    line-height: 1;
    color: var(--cnp-accent, oklch(0.72 0.18 145));
    flex-shrink: 0;
  }

  /* ── Capture mode ────────────────────────────────────────────────────────── */

  .kbd-capture {
    display: flex;
    flex-direction: column;
    gap: 3px;
  }

  .kbd-press-hint {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    font-style: italic;
  }

  .kbd-conflict {
    font-family: var(--font-sans);
    font-size: 10px;
    color: oklch(0.65 0.18 25);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 170px;
  }

  /* ── Action buttons ──────────────────────────────────────────────────────── */

  .kbd-actions {
    display: flex;
    align-items: center;
    gap: var(--space-1-5);
    justify-content: flex-end;
  }

  .kbd-action-btn {
    appearance: none;
    background: none;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    padding: 2px 8px;
    cursor: pointer;
    color: var(--fg-muted);
    transition:
      color var(--dur-instant) var(--ease-out),
      border-color var(--dur-instant) var(--ease-out),
      background var(--dur-instant) var(--ease-out),
      opacity var(--dur-instant) var(--ease-out);
    white-space: nowrap;
  }

  .kbd-action-btn:hover {
    color: var(--fg);
    border-color: var(--fg-subtle);
    background: color-mix(in oklch, var(--fg) 5%, transparent);
  }

  .kbd-action-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .kbd-action-btn--confirm {
    color: var(--cnp-accent, oklch(0.72 0.18 145));
    border-color: var(--cnp-accent, oklch(0.72 0.18 145));
  }

  .kbd-action-btn--confirm:hover:not(:disabled) {
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 10%, transparent);
    color: var(--cnp-accent, oklch(0.72 0.18 145));
    border-color: var(--cnp-accent, oklch(0.72 0.18 145));
  }

  .kbd-action-btn--reset {
    color: oklch(0.65 0.12 25);
    border-color: transparent;
  }

  .kbd-action-btn--reset:hover {
    border-color: oklch(0.65 0.12 25);
    background: color-mix(in oklch, oklch(0.65 0.12 25) 8%, transparent);
  }

  /* ── Empty state ─────────────────────────────────────────────────────────── */

  .kbd-empty {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    text-align: center;
    padding: var(--space-8) 0;
    margin: 0;
  }
</style>
