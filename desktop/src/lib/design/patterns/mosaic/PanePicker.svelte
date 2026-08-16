<script lang="ts">
  /**
   * PanePicker — keyboard-driven modal for opening a new pane.
   * CSS prefix: pp-
   * LOC target: ≤ 200.
   */
  import { onMount } from 'svelte';
  import { X } from 'lucide-svelte';
  import { createQuery } from '@tanstack/svelte-query';
  import { mosaicLayout, type PaneKind, type Pane } from '$lib/stores/mosaic-layout.svelte.js';
  import { sessionsQuery } from '$lib/api/queries/sessions.js';
  import { issuesQuery } from '$lib/api/queries/issues.js';

  interface Props {
    targetTileId: string | null;
    onClose: () => void;
  }

  let { targetTileId, onClose }: Props = $props();

  interface PickerItem {
    id: string;
    kind: PaneKind;
    ref: string;
    title: string;
    description: string;
    group: 'quick' | 'sessions' | 'issues' | 'other';
  }

  // ── Live queries ──────────────────────────────────────────────────────────
  const sessionsResult = createQuery(sessionsQuery({ limit: 5 }));
  const issuesResult = createQuery(issuesQuery());

  // ── Quick actions (always static, always at top) ──────────────────────────
  const QUICK_ACTIONS: PickerItem[] = [
    { id: 'static-agent_conversation', kind: 'agent_conversation', ref: 'new', title: 'New conversation', description: 'Start a new agent conversation', group: 'quick' },
    { id: 'static-terminal', kind: 'terminal', ref: 'local', title: 'Terminal', description: 'Open a local shell', group: 'quick' },
    { id: 'static-agent_kanban', kind: 'agent_kanban', ref: 'default', title: 'Agent Kanban', description: 'Agent task board (open in Agent Control)', group: 'quick' },
  ];

  // ── Static fallbacks for less common kinds ────────────────────────────────
  const STATIC_OTHER: PickerItem[] = [
    { id: 'static-task',         kind: 'task',         ref: 'task',      title: 'Task',         description: 'Open a task',          group: 'other' },
    { id: 'static-doc',          kind: 'doc',          ref: 'doc',       title: 'Doc',          description: 'Open a document',      group: 'other' },
    { id: 'static-file',         kind: 'file',         ref: 'file',      title: 'File',         description: 'Open a file',          group: 'other' },
    { id: 'static-knowledge',    kind: 'knowledge',    ref: 'kb-root',   title: 'Knowledge base', description: 'Browse knowledge',  group: 'other' },
    { id: 'static-block_stream', kind: 'block_stream', ref: 'stream',    title: 'Block stream', description: 'Live block output',    group: 'other' },
    { id: 'static-workflow',     kind: 'workflow',     ref: 'workflow',  title: 'Workflow',     description: 'Open a workflow',      group: 'other' },
    { id: 'static-notebook',     kind: 'notebook',     ref: 'notebook',  title: 'Notebook',     description: 'Open a notebook',      group: 'other' },
    { id: 'static-history',      kind: 'history',      ref: 'history',   title: 'History',      description: 'Cross-session block history', group: 'other' },
  ];

  // ── Derived catalog: quick + live sessions + live issues + fallbacks ──────
  const catalog = $derived.by<PickerItem[]>(() => {
    const sessions = ($sessionsResult.data ?? []).slice(0, 5).map((s) => ({
      id: `live-session-${s.id}`,
      kind: 'session' as PaneKind,
      ref: s.id,
      title: (s as { title?: string }).title || `Session ${s.id.slice(0, 6)}`,
      description: (s as { runtimeType?: string }).runtimeType || 'Session',
      group: 'sessions' as const,
    }));

    const issues = ($issuesResult.data ?? []).slice(0, 5).map((iss) => ({
      id: `live-issue-${(iss as { shortId?: string }).shortId ?? iss.id}`,
      kind: 'issue' as PaneKind,
      ref: (iss as { shortId?: string }).shortId ?? iss.id,
      title: iss.title,
      description: 'Issue',
      group: 'issues' as const,
    }));

    return [...QUICK_ACTIONS, ...sessions, ...issues, ...STATIC_OTHER];
  });

  let query = $state('');
  let selectedIdx = $state(0);
  let inputEl = $state<HTMLInputElement | undefined>();

  const filtered = $derived(
    query.trim() === ''
      ? catalog
      : catalog.filter(
          (item) =>
            item.title.toLowerCase().includes(query.toLowerCase()) ||
            item.description.toLowerCase().includes(query.toLowerCase()),
        ),
  );

  $effect(() => {
    // Reset selection when filtered list changes
    selectedIdx = 0;
  });

  onMount(() => {
    inputEl?.focus();
  });

  function openItem(item: PickerItem): void {
    const pane: Pane = {
      id: Math.random().toString(36).slice(2, 9),
      kind: item.kind,
      ref: item.ref,
      title: item.title,
    };
    mosaicLayout.openPane(pane, targetTileId ?? undefined);
    onClose();
  }

  function handleKeydown(e: KeyboardEvent): void {
    if (e.key === 'Escape') { onClose(); return; }
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      selectedIdx = Math.min(selectedIdx + 1, filtered.length - 1);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      selectedIdx = Math.max(selectedIdx - 1, 0);
    } else if (e.key === 'Enter') {
      e.preventDefault();
      const item = filtered[selectedIdx];
      if (item) openItem(item);
    }
  }

  const KIND_LABELS: Record<PaneKind, string> = {
    session: 'Session', issue: 'Issue', task: 'Task', doc: 'Doc',
    file: 'File', terminal: 'Terminal', changes: 'Changes', knowledge: 'Knowledge',
    agent_conversation: 'Conversation',
    agent_kanban: 'Kanban',
    block_stream: 'Blocks',
    workflow: 'Workflow',
    notebook: 'Notebook',
    history: 'History',
  };

  const GROUP_LABELS: Record<string, string> = {
    quick: 'Quick Actions',
    sessions: 'Recent Sessions',
    issues: 'Recent Issues',
    other: 'Other',
  };

  // Compute visible group headers from the filtered list
  const visibleGroups = $derived(
    [...new Set(filtered.map((item) => item.group))]
  );
</script>

<!-- Backdrop -->
<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
<div class="pp-backdrop" onclick={onClose} aria-hidden="true"></div>

<div
  class="pp-modal"
  role="dialog"
  aria-modal="true"
  aria-label="Open pane"
  onkeydown={handleKeydown}
>
  <div class="pp-header">
    <input
      bind:this={inputEl}
      bind:value={query}
      class="pp-input"
      type="text"
      placeholder="Search sessions, issues, docs…"
      aria-label="Search panes"
      autocomplete="off"
    />
    <button class="pp-close" onclick={onClose} aria-label="Close picker">
      <X size={14} aria-hidden="true" />
    </button>
  </div>

  <div class="pp-list" role="listbox" aria-label="Available panes">
    {#if filtered.length === 0}
      <div class="pp-empty">No results for "{query}"</div>
    {:else}
      {#each visibleGroups as group (group)}
        <div class="pp-group-label">{GROUP_LABELS[group]}</div>
        {#each filtered.filter((item) => item.group === group) as item, _i (item.id)}
          {@const i = filtered.indexOf(item)}
          <!-- svelte-ignore a11y_click_events_have_key_events -->
          <div
            class="pp-item"
            class:pp-item--selected={i === selectedIdx}
            role="option"
            aria-selected={i === selectedIdx}
            onclick={() => openItem(item)}
            onmouseenter={() => { selectedIdx = i; }}
          >
            <span class="pp-item__kind">{KIND_LABELS[item.kind]}</span>
            <span class="pp-item__title">{item.title}</span>
          </div>
        {/each}
      {/each}
    {/if}
  </div>

  <div class="pp-footer">
    <span>↑↓ navigate</span>
    <span>↵ open</span>
    <span>esc close</span>
  </div>
</div>

<style>
  .pp-backdrop {
    position: fixed;
    inset: 0;
    z-index: 100;
    background: color-mix(in oklch, var(--bg) 40%, transparent);
    backdrop-filter: blur(2px);
  }

  .pp-modal {
    position: fixed;
    top: 20%;
    left: 50%;
    transform: translateX(-50%);
    z-index: 101;
    width: min(560px, 90vw);
    background: var(--surface, var(--bg));
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    box-shadow: 0 24px 64px color-mix(in oklch, black 30%, transparent);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    font-family: var(--font-sans);
  }

  .pp-header {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 12px 16px;
    border-bottom: 1px solid var(--border);
  }

  .pp-input {
    flex: 1;
    background: transparent;
    border: none;
    outline: none;
    font-size: var(--text-sm);
    font-family: var(--font-sans);
    color: var(--fg);
    caret-color: var(--cnp-accent, oklch(0.72 0.18 145));
  }

  .pp-input::placeholder { color: var(--fg-subtle); }

  .pp-close {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border: none;
    background: transparent;
    color: var(--fg-subtle);
    cursor: pointer;
    border-radius: var(--radius-sm);
    padding: 4px;
    transition: background 0.1s ease;
  }
  .pp-close:hover { background: color-mix(in oklch, var(--fg) 10%, transparent); color: var(--fg); }

  .pp-list {
    max-height: 360px;
    overflow-y: auto;
    padding: 6px;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .pp-group-label {
    padding: 6px 10px 2px;
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--fg-subtle);
  }

  .pp-empty {
    padding: 24px;
    text-align: center;
    color: var(--fg-subtle);
    font-size: var(--text-sm);
  }

  .pp-item {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 8px 10px;
    border-radius: var(--radius-md);
    cursor: pointer;
    transition: background 0.08s ease;
  }
  .pp-item:hover,
  .pp-item--selected {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
  }

  .pp-item__kind {
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.06em;
    color: var(--cnp-accent, oklch(0.72 0.18 145));
    text-transform: uppercase;
    width: 72px;
    flex-shrink: 0;
  }

  .pp-item__title {
    font-size: var(--text-sm);
    color: var(--fg);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .pp-footer {
    display: flex;
    gap: 16px;
    padding: 8px 16px;
    border-top: 1px solid var(--border);
    font-size: 11px;
    color: var(--fg-subtle);
  }
</style>
