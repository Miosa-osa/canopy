<script lang="ts">
/**
 * BoardEditor — modal for creating/editing a board config.
 * CSS prefix: be- (BoardEditor)
 */

import type { DndEvent } from 'svelte-dnd-action';
import { dndzone, SHADOW_PLACEHOLDER_ITEM_ID } from 'svelte-dnd-action';
import type { TaskStatus } from '$lib/domain/tasks/types.js';
import {
  type BoardConfig,
  type BoardScope,
  type ColumnConfig,
  inferVerb,
  kanbanBoards,
  type TransitionVerb,
} from '$lib/stores/kanban-boards.svelte.js';

const VERBS: TransitionVerb[] = ['noop', 'start', 'build', 'pause', 'resume', 'stop', 'done'];

interface Props {
  /** If provided, we're editing an existing board. If null, creating new. */
  board?: BoardConfig | null;
  onClose: () => void;
}

let { board = null, onClose }: Props = $props();

// ── Local state ───────────────────────────────────────────────────────────────

type ScopeType = 'workspace' | 'agent' | 'assignee_agent' | 'assignee_human';

let name = $state(board?.name ?? '');
let scopeType = $state<ScopeType>(deriveScopeType(board?.scope ?? null));
let agentId = $state(board?.scope?.type === 'agent' ? board.scope.agentId : '');

// Columns need an 'id' field for svelte-dnd-action
type DndColumn = ColumnConfig & { id: string };

let columns = $state<DndColumn[]>(
  (board?.columns ?? defaultColumns()).map((c, i) => ({ ...c, id: String(i) }))
);

const TASK_STATUSES: TaskStatus[] = ['todo', 'in_progress', 'done', 'cancelled'];

function defaultColumns(): ColumnConfig[] {
  return [
    { status: 'todo', label: 'Todo', wipLimit: 999 },
    { status: 'in_progress', label: 'In Progress', wipLimit: 5 },
    { status: 'done', label: 'Done', wipLimit: 999 },
    { status: 'cancelled', label: 'Cancelled', wipLimit: 999 },
  ];
}

function deriveScopeType(scope: BoardScope | null): ScopeType {
  if (!scope) return 'workspace';
  if (scope.type === 'agent') return 'agent';
  if (scope.type === 'assignee_type') {
    return scope.value === 'agent' ? 'assignee_agent' : 'assignee_human';
  }
  return 'workspace';
}

function buildScope(): BoardScope {
  switch (scopeType) {
    case 'agent':
      return { type: 'agent', agentId: agentId.trim() };
    case 'assignee_agent':
      return { type: 'assignee_type', value: 'agent' };
    case 'assignee_human':
      return { type: 'assignee_type', value: 'human' };
    default:
      return { type: 'workspace', slug: 'default' };
  }
}

// ── DnD ───────────────────────────────────────────────────────────────────────

function handleConsider(e: CustomEvent<DndEvent<DndColumn>>) {
  columns = e.detail.items;
}

function handleFinalize(e: CustomEvent<DndEvent<DndColumn>>) {
  columns = e.detail.items.filter((c) => c.id !== SHADOW_PLACEHOLDER_ITEM_ID);
}

// ── Column CRUD ───────────────────────────────────────────────────────────────

function addColumn() {
  const usedStatuses = new Set(columns.map((c) => c.status));
  const next = TASK_STATUSES.find((s) => !usedStatuses.has(s));
  if (!next) return;
  columns = [
    ...columns,
    { id: crypto.randomUUID(), status: next, label: next.replace('_', ' '), wipLimit: 999 },
  ];
}

function removeColumn(id: string) {
  columns = columns.filter((c) => c.id !== id);
}

function updateColumn(id: string, patch: Partial<ColumnConfig>) {
  columns = columns.map((c) => (c.id === id ? { ...c, ...patch } : c));
}

// ── Save ──────────────────────────────────────────────────────────────────────

let nameError = $state('');

function save() {
  if (!name.trim()) {
    nameError = 'Board name is required';
    return;
  }
  if (scopeType === 'agent' && !agentId.trim()) {
    nameError = 'Agent ID is required for agent-scoped boards';
    return;
  }
  nameError = '';

  const scope = buildScope();
  // Strip dnd 'id' back to plain ColumnConfig
  const cleanColumns: ColumnConfig[] = columns.map(({ status, label, wipLimit, verb }) => ({
    status,
    label,
    wipLimit,
    ...(verb !== undefined ? { verb } : {}),
  }));

  if (board) {
    kanbanBoards.renameBoard(board.id, name.trim());
    kanbanBoards.updateScope(board.id, scope);
    kanbanBoards.updateColumns(board.id, cleanColumns);
    kanbanBoards.setActive(board.id);
  } else {
    kanbanBoards.createBoard(name.trim(), scope, cleanColumns);
  }

  onClose();
}

function handleKeydown(e: KeyboardEvent) {
  if (e.key === 'Escape') onClose();
}
</script>

<svelte:window onkeydown={handleKeydown} />

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="be-backdrop" onclick={onClose} aria-hidden="true"></div>

<div class="be-modal" role="dialog" aria-modal="true" aria-label={board ? 'Edit board' : 'New board'}>
  <header class="be-header">
    <h2 class="be-title">{board ? 'Edit board' : 'New board'}</h2>
    <button class="be-close" onclick={onClose} aria-label="Close">✕</button>
  </header>

  <div class="be-body">
    <!-- Board name -->
    <div class="be-field">
      <label class="be-label" for="be-name">Board name</label>
      <input
        id="be-name"
        class="be-input"
        class:be-input--error={!!nameError}
        type="text"
        bind:value={name}
        placeholder="e.g. Engineering sprint"
        autocomplete="off"
      />
      {#if nameError}
        <p class="be-error" role="alert">{nameError}</p>
      {/if}
    </div>

    <!-- Scope picker -->
    <fieldset class="be-fieldset">
      <legend class="be-label">Scope</legend>
      <div class="be-radio-group">
        <label class="be-radio-label">
          <input type="radio" bind:group={scopeType} value="workspace" />
          All tasks in workspace
        </label>
        <label class="be-radio-label">
          <input type="radio" bind:group={scopeType} value="agent" />
          Specific agent
        </label>
        <label class="be-radio-label">
          <input type="radio" bind:group={scopeType} value="assignee_agent" />
          All agent-assigned tasks
        </label>
        <label class="be-radio-label">
          <input type="radio" bind:group={scopeType} value="assignee_human" />
          All human-assigned tasks
        </label>
      </div>

      {#if scopeType === 'agent'}
        <div class="be-field be-field--indent">
          <label class="be-label" for="be-agent-id">Agent slug / ID</label>
          <input
            id="be-agent-id"
            class="be-input"
            type="text"
            bind:value={agentId}
            placeholder="e.g. claude-code"
            autocomplete="off"
          />
        </div>
      {/if}
    </fieldset>

    <!-- Columns editor -->
    <div class="be-field">
      <span class="be-label">Columns</span>
      <p class="be-hint">Drag to reorder. Max one column per status.</p>
      <div
        class="be-columns-list"
        use:dndzone={{ items: columns, flipDurationMs: 120 }}
        onconsider={handleConsider}
        onfinalize={handleFinalize}
      >
        {#each columns as col (col.id)}
          <div class="be-col-row">
            <span class="be-drag-handle" aria-hidden="true">⠿</span>

            <select
              class="be-select be-select--status"
              value={col.status}
              onchange={(e) => updateColumn(col.id, { status: (e.currentTarget as HTMLSelectElement).value as TaskStatus })}
              aria-label="Column status"
            >
              {#each TASK_STATUSES as s (s)}
                <option value={s}>{s}</option>
              {/each}
            </select>

            <input
              class="be-input be-input--col-label"
              type="text"
              value={col.label}
              oninput={(e) => updateColumn(col.id, { label: (e.currentTarget as HTMLInputElement).value })}
              placeholder="Label"
              aria-label="Column label"
            />

            <input
              class="be-input be-input--wip"
              type="number"
              value={col.wipLimit === 999 ? '' : col.wipLimit}
              oninput={(e) => {
                const v = parseInt((e.currentTarget as HTMLInputElement).value, 10);
                updateColumn(col.id, { wipLimit: isNaN(v) || v < 1 ? 999 : v });
              }}
              placeholder="WIP ∞"
              min="1"
              aria-label="WIP limit"
            />

            <select
              class="be-select be-select--verb"
              value={col.verb ?? ''}
              onchange={(e) => {
                const v = (e.currentTarget as HTMLSelectElement).value as TransitionVerb | '';
                updateColumn(col.id, { verb: v === '' ? undefined : v });
              }}
              aria-label="Transition verb"
              title="Verb emitted when a card is dropped into this column"
            >
              <option value="">(auto: {inferVerb(col.status)})</option>
              {#each VERBS as v (v)}
                <option value={v}>{v}</option>
              {/each}
            </select>

            <button
              class="be-col-delete"
              onclick={() => removeColumn(col.id)}
              aria-label="Remove column"
              disabled={columns.length <= 1}
            >✕</button>
          </div>
        {/each}
      </div>

      <button
        class="be-add-col"
        onclick={addColumn}
        disabled={columns.length >= TASK_STATUSES.length}
      >
        + Add column
      </button>
    </div>
  </div>

  <footer class="be-footer">
    <button class="btn-pill btn-pill-secondary btn-pill-sm" onclick={onClose}>Cancel</button>
    <button class="btn-pill btn-pill-primary btn-pill-sm" onclick={save}>
      {board ? 'Save changes' : 'Create board'}
    </button>
  </footer>
</div>

<style>
  .be-backdrop { position: fixed; inset: 0; z-index: 59; background: color-mix(in oklch, var(--fg) 20%, transparent); }
  .be-modal { position: fixed; top: 50%; left: 50%; transform: translate(-50%,-50%); z-index: 60; width: min(520px,94vw); max-height: 88vh; display: flex; flex-direction: column; border-radius: 6px; border: 1px solid var(--border); background: var(--bg); box-shadow: 0 8px 32px color-mix(in oklch, var(--fg) 16%, transparent); overflow: hidden; }
  .be-header { display: flex; align-items: center; justify-content: space-between; padding: 14px 16px; border-bottom: 1px solid var(--border); flex-shrink: 0; }
  .be-title { margin: 0; font-family: var(--font-mono); font-size: 14px; font-weight: 600; color: var(--fg); }
  .be-close { background: transparent; border: none; cursor: pointer; color: var(--fg-muted); font-size: 14px; padding: 2px 4px; border-radius: 3px; line-height: 1; transition: color 0.1s ease; }
  .be-close:hover { color: var(--fg); }
  .be-body { display: flex; flex-direction: column; gap: 20px; padding: 16px; overflow-y: auto; flex: 1; }
  .be-field { display: flex; flex-direction: column; gap: 6px; }
  .be-field--indent { margin-top: 8px; padding-left: 12px; border-left: 2px solid var(--border); }
  .be-fieldset { border: none; padding: 0; margin: 0; display: flex; flex-direction: column; gap: 6px; }
  .be-label { font-family: var(--font-mono); font-size: 11px; font-weight: 600; color: var(--fg-muted); text-transform: uppercase; letter-spacing: 0.06em; }
  .be-hint { margin: 0; font-family: var(--font-mono); font-size: 11px; color: var(--fg-subtle); }
  .be-input, .be-select { padding: 6px 8px; border-radius: 4px; border: 1px solid var(--border); background: var(--bg-inset); font-family: var(--font-mono); font-size: 13px; color: var(--fg); outline: none; transition: border-color 0.1s ease; }
  .be-input:focus, .be-select:focus { border-color: color-mix(in oklch, var(--fg) 40%, transparent); }
  .be-input--error { border-color: var(--signal-error, oklch(0.65 0.22 25)); }
  .be-input--col-label { flex: 1; min-width: 80px; }
  .be-input--wip { width: 68px; flex-shrink: 0; }
  .be-select { cursor: pointer; }
  .be-select--status { width: 120px; flex-shrink: 0; }
  .be-select--verb { width: 110px; flex-shrink: 0; font-size: 11px; }
  .be-error { margin: 0; font-family: var(--font-mono); font-size: 12px; color: var(--signal-error, oklch(0.65 0.22 25)); }
  .be-radio-group { display: flex; flex-direction: column; gap: 6px; }
  .be-radio-label { display: flex; align-items: center; gap: 8px; font-family: var(--font-mono); font-size: 13px; color: var(--fg); cursor: pointer; }
  .be-columns-list { display: flex; flex-direction: column; gap: 6px; }
  .be-col-row { display: flex; align-items: center; gap: 8px; padding: 6px 8px; border-radius: 4px; border: 1px solid var(--border); background: var(--bg-inset); }
  .be-drag-handle { font-size: 14px; color: var(--fg-subtle); cursor: grab; flex-shrink: 0; user-select: none; padding: 0 2px; }
  .be-drag-handle:active { cursor: grabbing; }
  .be-col-delete { background: transparent; border: none; color: var(--fg-muted); cursor: pointer; font-size: 12px; padding: 2px 4px; border-radius: 3px; flex-shrink: 0; transition: color 0.1s ease; line-height: 1; }
  .be-col-delete:hover:not(:disabled) { color: var(--signal-error, oklch(0.65 0.22 25)); }
  .be-col-delete:disabled, .be-add-col:disabled { opacity: 0.35; cursor: not-allowed; }
  .be-add-col { margin-top: 4px; padding: 6px 10px; border-radius: 4px; border: 1px dashed var(--border); background: transparent; font-family: var(--font-mono); font-size: 12px; color: var(--fg-muted); cursor: pointer; align-self: flex-start; transition: border-color 0.1s ease, color 0.1s ease; }
  .be-add-col:hover:not(:disabled) { border-color: color-mix(in oklch, var(--fg) 40%, transparent); color: var(--fg); }
  .be-footer { display: flex; justify-content: flex-end; gap: 8px; padding: 12px 16px; border-top: 1px solid var(--border); flex-shrink: 0; }
</style>
