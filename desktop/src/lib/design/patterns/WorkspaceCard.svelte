<script lang="ts">
/**
 * WorkspaceCard — glass card for one workspace in the list grid.
 * Props: workspace + onDelete callback.
 * CSS prefix: wc- (WorkspaceCard)
 * LOC target: ≤ 100
 */
import { goto } from '$app/navigation';
import type { Workspace } from '$lib/domain/workspaces/types.js';

interface Props {
  workspace: Workspace;
  onDelete?: () => void;
  class?: string;
}

let { workspace, onDelete, class: className = '' }: Props = $props();

const TEMPLATE_EMOJI: Record<string, string> = {
  blank: '📄',
  'sales-engine': '💼',
  'dev-shop': '⚙️',
  'content-factory': '🎬',
};

const emoji = $derived(workspace.template ? (TEMPLATE_EMOJI[workspace.template] ?? '📁') : '📁');

let menuOpen = $state(false);
let confirmDelete = $state(false);

function handleOpen(e: MouseEvent | KeyboardEvent): void {
  if (e instanceof KeyboardEvent && e.key !== 'Enter' && e.key !== ' ') return;
  void goto(`/workspaces/${workspace.slug}`);
}

function handleMenuToggle(e: MouseEvent): void {
  e.stopPropagation();
  menuOpen = !menuOpen;
  confirmDelete = false;
}

function handleDeleteRequest(e: MouseEvent): void {
  e.stopPropagation();
  confirmDelete = true;
}

function handleDeleteConfirm(e: MouseEvent): void {
  e.stopPropagation();
  menuOpen = false;
  confirmDelete = false;
  onDelete?.();
}

function handleDeleteCancel(e: MouseEvent): void {
  e.stopPropagation();
  confirmDelete = false;
}
</script>

<div
  class="wc-card glass-card {className}"
  role="link"
  tabindex="0"
  aria-label="Open workspace {workspace.name}"
  onclick={handleOpen}
  onkeydown={handleOpen}
>
  <div class="wc-top">
    <span class="wc-emoji" aria-hidden="true">{emoji}</span>
    <button
      class="btn-compact btn-compact-ghost wc-menu-btn"
      aria-label="Workspace options"
      aria-expanded={menuOpen}
      onclick={handleMenuToggle}
    >
      ···
    </button>
  </div>

  <div class="wc-meta">
    <p class="wc-name">{workspace.name}</p>
    {#if workspace.description}
      <p class="wc-desc">{workspace.description}</p>
    {/if}
    <p class="wc-path" title={workspace.rootPath}>{workspace.rootPath}</p>
  </div>

  <a
    class="wc-open-link"
    href="/workspaces/{workspace.slug}"
    onclick={(e) => e.stopPropagation()}
    aria-label="Open {workspace.name}"
  >
    Open →
  </a>

  {#if menuOpen}
    <div class="wc-menu glass-panel" role="menu">
      {#if confirmDelete}
        <p class="wc-confirm-text">Delete this workspace?</p>
        <div class="wc-confirm-actions">
          <button class="btn-compact btn-compact-danger" onclick={handleDeleteConfirm}>
            Delete
          </button>
          <button class="btn-compact btn-compact-ghost" onclick={handleDeleteCancel}>
            Cancel
          </button>
        </div>
      {:else}
        <button class="wc-menu-item" role="menuitem" onclick={handleDeleteRequest}>
          Delete
        </button>
      {/if}
    </div>
  {/if}
</div>

<style>
  .wc-card {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-4);
    cursor: pointer;
    position: relative;
    outline: none;
    user-select: none;
  }

  .wc-card:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .wc-top {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
  }

  .wc-emoji {
    font-size: 28px;
    line-height: 1;
  }

  .wc-menu-btn {
    opacity: 0;
    transition: opacity 0.15s ease;
    font-size: 16px;
    letter-spacing: 1px;
    flex-shrink: 0;
  }

  .wc-card:hover .wc-menu-btn,
  .wc-card:focus-within .wc-menu-btn {
    opacity: 1;
  }

  .wc-meta {
    display: flex;
    flex-direction: column;
    gap: 2px;
    flex: 1;
  }

  .wc-name {
    font-family: var(--font-sans);
    font-size: var(--text-base);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
    letter-spacing: -0.015em;
    line-height: 1.3;
  }

  .wc-desc {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
    line-height: 1.4;
    overflow: hidden;
    display: -webkit-box;
    /* stylelint-disable-next-line */
    -webkit-line-clamp: 2;
    line-clamp: 2;
    -webkit-box-orient: vertical;
  }

  .wc-path {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    margin: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .wc-open-link {
    align-self: flex-start;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg-muted);
    text-decoration: none;
    margin-top: var(--space-1);
    transition: color 0.15s ease;
  }

  .wc-open-link:hover {
    color: var(--fg);
  }

  .wc-menu {
    position: absolute;
    top: var(--space-8);
    right: var(--space-3);
    min-width: 140px;
    padding: var(--space-2);
    z-index: 10;
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .wc-menu-item {
    display: block;
    width: 100%;
    padding: var(--space-1) var(--space-2);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--signal-error);
    background: transparent;
    border: none;
    border-radius: var(--radius-sm);
    cursor: pointer;
    text-align: left;
    transition: background 0.1s ease;
  }

  .wc-menu-item:hover {
    background: color-mix(in oklch, var(--signal-error) 10%, transparent 90%);
  }

  .wc-confirm-text {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    margin: 0 0 var(--space-2);
  }

  .wc-confirm-actions {
    display: flex;
    gap: var(--space-1);
  }
</style>
