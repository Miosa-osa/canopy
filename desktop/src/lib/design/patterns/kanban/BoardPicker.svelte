<script lang="ts">
/**
 * BoardPicker — active board selector + board management menu.
 * CSS prefix: bp- (BoardPicker)
 */
import { kanbanBoards } from '$lib/stores/kanban-boards.svelte.js';

interface Props {
  onEdit?: () => void;
  onNew?: () => void;
}

let { onEdit, onNew }: Props = $props();

let menuOpen = $state(false);

function toggleMenu() {
  menuOpen = !menuOpen;
}

function closeMenu() {
  menuOpen = false;
}

function selectBoard(id: string) {
  kanbanBoards.setActive(id);
  closeMenu();
}

function handleNew() {
  closeMenu();
  onNew?.();
}

function handleEdit() {
  closeMenu();
  onEdit?.();
}

function handleDelete() {
  closeMenu();
  const id = kanbanBoards.activeBoardId;
  if (kanbanBoards.boards.length <= 1) return; // never delete the last board
  kanbanBoards.deleteBoard(id);
}

function handleKeydown(e: KeyboardEvent) {
  if (e.key === 'Escape') closeMenu();
}
</script>

<svelte:window onkeydown={handleKeydown} />

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="bp-wrap" class:bp-wrap--open={menuOpen}>
  <button
    class="bp-trigger"
    onclick={toggleMenu}
    aria-haspopup="menu"
    aria-expanded={menuOpen}
    aria-label="Select board"
  >
    <span class="bp-trigger-name">{kanbanBoards.activeBoard?.name ?? 'Select board'}</span>
    <span class="bp-caret" aria-hidden="true">{menuOpen ? '▲' : '▼'}</span>
  </button>

  {#if menuOpen}
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="bp-backdrop" onclick={closeMenu} aria-hidden="true"></div>
    <div class="bp-menu" role="menu" aria-label="Board selector">
      <div class="bp-menu-section" role="group" aria-label="Your boards">
        {#each kanbanBoards.boards as board (board.id)}
          <button
            class="bp-item"
            class:bp-item--active={board.id === kanbanBoards.activeBoardId}
            role="menuitem"
            onclick={() => selectBoard(board.id)}
          >
            {#if board.id === kanbanBoards.activeBoardId}
              <span class="bp-active-dot" aria-hidden="true"></span>
            {:else}
              <span class="bp-empty-dot" aria-hidden="true"></span>
            {/if}
            {board.name}
          </button>
        {/each}
      </div>

      <div class="bp-separator" role="separator" aria-hidden="true"></div>

      <div class="bp-menu-section" role="group" aria-label="Board actions">
        <button class="bp-item" role="menuitem" onclick={handleNew}>
          + New board
        </button>
        <button class="bp-item" role="menuitem" onclick={handleEdit} disabled={!kanbanBoards.activeBoard}>
          Edit current board
        </button>
        <button
          class="bp-item bp-item--danger"
          role="menuitem"
          onclick={handleDelete}
          disabled={kanbanBoards.boards.length <= 1}
          aria-label="Delete current board (unavailable when only one board remains)"
        >
          Delete current board
        </button>
      </div>
    </div>
  {/if}
</div>

<style>
  .bp-wrap {
    position: relative;
    display: inline-block;
    font-family: var(--font-mono);
    font-size: 13px;
  }

  .bp-trigger {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 10px;
    border-radius: 4px;
    border: 1px solid var(--border);
    background: var(--bg-inset);
    color: var(--fg);
    cursor: pointer;
    font-family: inherit;
    font-size: inherit;
    transition: border-color 0.1s ease, background 0.1s ease;
    white-space: nowrap;
  }

  .bp-trigger:hover {
    border-color: color-mix(in oklch, var(--fg) 30%, transparent);
    background: color-mix(in oklch, var(--fg) 6%, transparent);
  }

  .bp-trigger:focus-visible {
    outline: 2px solid var(--cnp-accent, oklch(0.78 0.18 145));
    outline-offset: 2px;
  }

  .bp-wrap--open .bp-trigger {
    border-color: color-mix(in oklch, var(--fg) 30%, transparent);
  }

  .bp-trigger-name {
    max-width: 200px;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .bp-caret {
    font-size: 9px;
    color: var(--fg-muted);
    flex-shrink: 0;
  }

  .bp-backdrop {
    position: fixed;
    inset: 0;
    z-index: 49;
  }

  .bp-menu {
    position: absolute;
    top: calc(100% + 4px);
    left: 0;
    z-index: 50;
    min-width: 220px;
    border-radius: 4px;
    border: 1px solid var(--border);
    background: var(--bg);
    box-shadow: 0 4px 16px color-mix(in oklch, var(--fg) 12%, transparent);
    padding: 4px 0;
  }

  .bp-menu-section {
    display: flex;
    flex-direction: column;
  }

  .bp-separator {
    height: 1px;
    background: var(--border);
    margin: 4px 0;
  }

  .bp-item {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    padding: 6px 12px;
    background: transparent;
    border: none;
    border-radius: 0;
    font-family: var(--font-mono);
    font-size: 13px;
    color: var(--fg);
    cursor: pointer;
    text-align: left;
    transition: background 0.08s ease;
  }

  .bp-item:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 6%, transparent);
  }

  .bp-item:disabled {
    color: var(--fg-subtle);
    cursor: not-allowed;
  }

  .bp-item--active {
    color: var(--fg);
    font-weight: 600;
  }

  .bp-item--danger {
    color: var(--signal-error, oklch(0.65 0.22 25));
  }

  .bp-item--danger:hover:not(:disabled) {
    background: color-mix(in oklch, var(--signal-error, oklch(0.65 0.22 25)) 8%, transparent);
  }

  .bp-active-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--cnp-accent, oklch(0.78 0.18 145));
    flex-shrink: 0;
  }

  .bp-empty-dot {
    width: 6px;
    height: 6px;
    flex-shrink: 0;
  }
</style>
