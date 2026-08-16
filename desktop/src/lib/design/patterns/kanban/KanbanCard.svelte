<script lang="ts">
  /**
   * KanbanCard — single kanban card with inline edit and context menu.
   * CSS prefix: kb- (shared with KanbanBoard).
   */
  import { goto } from '$app/navigation';
  import { MoreHorizontal, Terminal, Trash2, Zap } from 'lucide-svelte';
  import type { Task } from '$lib/domain/tasks/types.js';

  interface Props {
    task: Task;
    isEditing: boolean;
    editingTitle: string;
    menuOpen: boolean;
    onStartEdit: (task: Task) => void;
    onCommitEdit: (task: Task) => void;
    onCancelEdit: () => void;
    onEditKeydown: (e: KeyboardEvent, task: Task) => void;
    onEditTitleChange: (value: string) => void;
    onToggleMenu: (id: string) => void;
    onDelete: (task: Task) => void;
    onDispatch: (task: Task) => void;
  }

  let {
    task,
    isEditing,
    editingTitle,
    menuOpen,
    onStartEdit,
    onCommitEdit,
    onCancelEdit,
    onEditKeydown,
    onEditTitleChange,
    onToggleMenu,
    onDelete,
    onDispatch,
  }: Props = $props();

  const PRIORITY_COLORS: Record<number, string> = {
    0: 'var(--fg-subtle)',
    1: 'var(--success)',
    2: 'var(--priority)',
    3: 'var(--destructive)',
  };

  function priorityColor(p: number): string {
    return PRIORITY_COLORS[p] ?? PRIORITY_COLORS[0];
  }

  function formatRelativeDue(iso: string | null): string | null {
    if (!iso) return null;
    const diff = new Date(iso).getTime() - Date.now();
    const days = Math.ceil(diff / 86_400_000);
    if (days < 0) return `${Math.abs(days)}d overdue`;
    if (days === 0) return 'Today';
    if (days === 1) return 'Tomorrow';
    if (days < 7) return `${days}d`;
    return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
  }

  function agentInitial(id: string | null): string {
    if (!id) return '?';
    return id.slice(0, 2).toUpperCase();
  }
</script>

<div class="kb-card-wrap">
  {#if isEditing}
    <!-- Inline edit mode -->
    <div class="kb-card kb-card--editing" role="group" aria-label="Edit task {task.shortId}">
      <p class="kb-card__id">{task.shortId}</p>
      <!-- svelte-ignore a11y_autofocus -->
      <input
        class="kb-edit-input"
        type="text"
        value={editingTitle}
        oninput={(e) => onEditTitleChange((e.currentTarget as HTMLInputElement).value)}
        onkeydown={(e) => onEditKeydown(e, task)}
        onblur={() => onCommitEdit(task)}
        autofocus
        aria-label="Edit task title"
      />
      <p class="kb-edit-hint">Enter to save · Esc to cancel</p>
    </div>
  {:else}
    <!-- Normal card -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div
      class="kb-card"
      role="button"
      tabindex="0"
      onclick={(e) => { e.stopPropagation(); goto(`/tasks/${task.shortId}`); }}
      ondblclick={(e) => { e.stopPropagation(); onStartEdit(task); }}
      onkeydown={(e) => { if (e.key === 'Enter') goto(`/tasks/${task.shortId}`); }}
      aria-label="Open task {task.shortId}: {task.title}. Double-click to edit."
    >
      <p class="kb-card__id">{task.shortId}</p>
      <p class="kb-card__title">{task.title}</p>

      <div class="kb-card__footer">
        <span
          class="kb-card__priority-dot"
          style="background: {priorityColor(task.priority)};"
          aria-label="Priority {task.priority}"
        ></span>

        {#if task.assigneeType === 'agent' && task.assigneeId}
          <button
            class="kb-card__agent"
            onclick={(e) => { e.stopPropagation(); goto(`/agents/${task.assigneeId}`); }}
            title="Agent: {task.assigneeId}"
            aria-label="Go to agent {task.assigneeId}"
          >
            {agentInitial(task.assigneeId)}
          </button>
        {:else if task.assigneeType && task.assigneeId}
          <span class="kb-card__assignee" title="{task.assigneeType}: {task.assigneeId}">
            {task.assigneeType === 'user' ? task.assigneeId.slice(0, 2).toUpperCase() : '?'}
          </span>
        {/if}

        {#if (task as Task & { sessionId?: string }).sessionId}
          <button
            class="kb-card__session"
            onclick={(e) => {
              e.stopPropagation();
              goto(`/sessions/${(task as Task & { sessionId?: string }).sessionId}`);
            }}
            title="Bound session"
            aria-label="Open bound session"
          >
            <Terminal size={10} aria-hidden="true" />
          </button>
        {/if}

        {#if task.dueAt}
          {@const rel = formatRelativeDue(task.dueAt)}
          {#if rel}
            <span
              class="kb-card__due"
              class:kb-card__due--overdue={rel.endsWith('overdue')}
            >{rel}</span>
          {/if}
        {/if}
      </div>
    </div>

    <!-- Menu button -->
    <div class="kb-menu-wrap">
      <button
        class="kb-menu-btn"
        onclick={(e) => { e.stopPropagation(); onToggleMenu(task.id); }}
        aria-label="Task menu for {task.shortId}"
        aria-expanded={menuOpen}
        aria-haspopup="menu"
      >
        <MoreHorizontal size={12} aria-hidden="true" />
      </button>

      {#if menuOpen}
        <div class="kb-menu" role="menu" aria-label="Task actions">
          <button
            class="kb-menu-item"
            role="menuitem"
            onclick={(e) => { e.stopPropagation(); onToggleMenu(task.id); onStartEdit(task); }}
          >
            Edit title
          </button>
          <button
            class="kb-menu-item"
            role="menuitem"
            onclick={(e) => { e.stopPropagation(); onDispatch(task); }}
          >
            <Zap size={11} aria-hidden="true" />
            Dispatch to agent
          </button>
          <div class="kb-menu-sep" role="separator"></div>
          <button
            class="kb-menu-item kb-menu-item--danger"
            role="menuitem"
            onclick={(e) => { e.stopPropagation(); onDelete(task); }}
          >
            <Trash2 size={11} aria-hidden="true" />
            Delete
          </button>
        </div>
      {/if}
    </div>
  {/if}
</div>

<style>
  /* ── Card wrapper ─────────────────────────────────────────────────────── */
  .kb-card-wrap {
    position: relative;
  }

  .kb-card-wrap:hover .kb-menu-btn {
    opacity: 1;
  }

  /* ── Card ─────────────────────────────────────────────────────────────── */
  .kb-card {
    display: flex;
    flex-direction: column;
    gap: var(--space-1, 0.25rem);
    padding: var(--space-2, 0.5rem) var(--space-3, 0.75rem);
    background: var(--bg-elevated, rgba(255, 255, 255, 0.04));
    border: 1px solid var(--border, rgba(255, 255, 255, 0.08));
    border-radius: var(--radius-lg, 8px);
    box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.06);
    cursor: grab;
    text-align: left;
    width: 100%;
    transition:
      box-shadow var(--dur-fast, 160ms) var(--ease-out, cubic-bezier(0.16, 1, 0.3, 1)),
      transform var(--dur-fast, 160ms) var(--ease-out, cubic-bezier(0.16, 1, 0.3, 1));
    font-family: var(--font-sans);
  }

  .kb-card:hover {
    box-shadow: 0 3px 10px 0 rgba(0, 0, 0, 0.12);
    transform: translateY(-1px);
    border-color: color-mix(in oklch, var(--fg) 20%, transparent);
  }

  .kb-card:focus-visible {
    outline: 2px solid var(--cnp-accent, oklch(0.78 0.18 145));
    outline-offset: 2px;
  }

  .kb-card:active {
    cursor: grabbing;
  }

  .kb-card--editing {
    cursor: default;
  }

  .kb-card--editing:hover {
    transform: none;
    box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.06);
  }

  .kb-card__id {
    margin: 0;
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    letter-spacing: 0.02em;
  }

  .kb-card__title {
    margin: 0;
    font-size: var(--text-sm, 0.875rem);
    font-weight: 500;
    color: var(--fg);
    line-height: 1.35;
    display: -webkit-box;
    -webkit-box-orient: vertical;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    overflow: hidden;
  }

  .kb-card__footer {
    display: flex;
    align-items: center;
    gap: var(--space-2, 0.5rem);
    margin-top: var(--space-1, 0.25rem);
  }

  .kb-card__priority-dot {
    width: 7px;
    height: 7px;
    border-radius: 9999px;
    flex-shrink: 0;
  }

  /* ── Agent chip ───────────────────────────────────────────────────────── */
  .kb-card__agent {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 18px;
    height: 18px;
    border-radius: 9999px;
    background: color-mix(in oklch, var(--fg) 15%, transparent);
    border: 1px solid var(--border);
    font-family: var(--font-mono);
    font-size: 8px;
    font-weight: 700;
    color: var(--fg-muted);
    cursor: pointer;
    flex-shrink: 0;
    padding: 0;
    transition: background var(--dur-instant) ease;
  }

  .kb-card__agent:hover {
    background: color-mix(in oklch, var(--fg) 25%, transparent);
    color: var(--fg);
  }

  .kb-card__agent:focus-visible {
    outline: 2px solid var(--fg-muted);
    outline-offset: 1px;
  }

  .kb-card__assignee {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 18px;
    height: 18px;
    border-radius: 9999px;
    background: color-mix(in oklch, var(--fg) 10%, transparent);
    border: 1px solid var(--border);
    font-family: var(--font-mono);
    font-size: 8px;
    font-weight: 700;
    color: var(--fg-subtle);
    flex-shrink: 0;
  }

  /* ── Session link ─────────────────────────────────────────────────────── */
  .kb-card__session {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 16px;
    height: 16px;
    border-radius: var(--radius-sm);
    background: transparent;
    border: 1px solid var(--border);
    color: var(--fg-subtle);
    cursor: pointer;
    padding: 0;
    flex-shrink: 0;
    transition: color var(--dur-instant) ease, background var(--dur-instant) ease;
  }

  .kb-card__session:hover {
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
  }

  .kb-card__session:focus-visible {
    outline: 2px solid var(--fg-muted);
    outline-offset: 1px;
  }

  .kb-card__due {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-muted);
    margin-left: auto;
    white-space: nowrap;
  }

  .kb-card__due--overdue {
    color: var(--signal-error, oklch(0.65 0.20 25));
  }

  /* ── Inline edit ──────────────────────────────────────────────────────── */
  .kb-edit-input {
    width: 100%;
    padding: 4px 6px;
    border-radius: var(--radius-sm);
    border: 1px solid color-mix(in oklch, var(--fg) 30%, transparent);
    background: var(--bg-inset);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
    outline: none;
    box-sizing: border-box;
  }

  .kb-edit-input:focus {
    border-color: var(--cnp-accent, oklch(0.78 0.18 145));
  }

  .kb-edit-hint {
    margin: 0;
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  /* ── Card menu ────────────────────────────────────────────────────────── */
  .kb-menu-wrap {
    position: absolute;
    top: var(--space-1);
    right: var(--space-1);
  }

  .kb-menu-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 22px;
    height: 22px;
    border-radius: var(--radius-sm);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    cursor: pointer;
    color: var(--fg-muted);
    padding: 0;
    opacity: 0;
    transition: opacity var(--dur-instant) ease, background var(--dur-instant) ease;
  }

  .kb-menu-btn:hover {
    background: color-mix(in oklch, var(--fg) 10%, transparent);
    color: var(--fg);
  }

  .kb-menu-btn:focus-visible {
    opacity: 1;
    outline: 2px solid var(--fg-muted);
    outline-offset: 1px;
  }

  .kb-menu {
    position: absolute;
    top: calc(100% + 4px);
    right: 0;
    z-index: 100;
    background: var(--bg-elevated, rgba(20, 20, 20, 0.96));
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.25);
    padding: 4px;
    min-width: 160px;
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .kb-menu-item {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    width: 100%;
    padding: 6px var(--space-2);
    border-radius: var(--radius-sm);
    border: none;
    background: transparent;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg);
    cursor: pointer;
    text-align: left;
    transition: background var(--dur-instant) ease;
  }

  .kb-menu-item:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
  }

  .kb-menu-item:focus-visible {
    outline: 2px solid var(--fg-muted);
    outline-offset: 1px;
  }

  .kb-menu-item--danger {
    color: var(--signal-error, oklch(0.65 0.20 25));
  }

  .kb-menu-item--danger:hover {
    background: color-mix(in oklch, var(--signal-error, oklch(0.65 0.20 25)) 10%, transparent);
  }

  .kb-menu-sep {
    height: 1px;
    background: var(--border);
    margin: 2px 0;
  }
</style>
