<script lang="ts">
  /**
   * AgentKanbanPane — Mosaic pane that renders the Agent Kanban board.
   * CSS prefix: akp-
   *
   * 4 columns: Backlog, Claimed, In Progress, Done.
   * Right-side rail: idle agents (drop a card on an agent to manually claim).
   *
   * State machine (column → action mapping):
   *   Backlog → Claimed:    POST /agent-kanban/claim     (with selected agent)
   *   Claimed → Backlog:    POST /agent-kanban/release/:id
   *   * → Done:             POST /agent-kanban/complete/:id   (with confirm)
   *   Claimed → In Progress: dispatch via existing /tasks/:id/dispatch
   *
   * The pane defers all backend writes to TanStack mutations and falls
   * back to a simple toast on error. The query auto-refetches every 15s
   * so other agents' moves land in the board without manual refresh.
   */

  import { createMutation, createQuery, useQueryClient } from '@tanstack/svelte-query';
  import { SHADOW_PLACEHOLDER_ITEM_ID } from 'svelte-dnd-action';
  import type { DndEvent } from 'svelte-dnd-action';
  import {
    agentKanbanBoardQuery,
    claimTaskMutation,
    completeTaskMutation,
    idleAgentsQuery,
    releaseTaskMutation,
  } from '$lib/api/queries/agent-kanban.js';
  import {
    KANBAN_COLUMNS,
    type AgentKanbanBoard,
    type AgentKanbanColumn,
    type IdleAgent,
  } from '$lib/domain/agent-kanban/types.js';
  import type { Task } from '$lib/domain/tasks/types.js';
  import { toasts } from '$lib/stores/toasts.svelte.js';
  import KanbanColumn from './agent-kanban/KanbanColumn.svelte';
  import IdleAgentsRail from './agent-kanban/IdleAgentsRail.svelte';

  // ── Props ──────────────────────────────────────────────────────────────────

  interface Props {
    workspaceSlug: string;
  }

  let { workspaceSlug }: Props = $props();

  // ── Queries ────────────────────────────────────────────────────────────────

  const boardQuery = createQuery<AgentKanbanBoard>(
    agentKanbanBoardQuery({ workspaceSlug }),
  );
  const idleQuery = createQuery<IdleAgent[]>(idleAgentsQuery());
  const queryClient = useQueryClient();

  // ── Mutations ─────────────────────────────────────────────────────────────

  const claimMut = createMutation(claimTaskMutation());
  const releaseMut = createMutation(releaseTaskMutation());
  const completeMut = createMutation(completeTaskMutation());

  // ── Local column state (used during drag) ─────────────────────────────────

  type Columns = Record<AgentKanbanColumn, Task[]>;

  function emptyColumns(): Columns {
    return { backlog: [], claimed: [], in_progress: [], done: [] };
  }

  function fromBoard(b: AgentKanbanBoard | undefined): Columns {
    if (!b) return emptyColumns();
    return {
      backlog: b.backlog ?? [],
      claimed: b.claimed ?? [],
      in_progress: b.in_progress ?? [],
      done: b.done ?? [],
    };
  }

  let columns = $state<Columns>(emptyColumns());
  let dragging = $state(false);

  $effect(() => {
    if (!dragging) {
      columns = fromBoard($boardQuery.data);
    }
  });

  // Auto-pickup toggle is currently a UI-only flag. The backend loop is
  // driven by per-agent `config.auto_pickup` — see wiring doc.
  let autoPickupOn = $state(false);

  // ── Drag-drop ─────────────────────────────────────────────────────────────

  function handleConsider(col: AgentKanbanColumn, e: CustomEvent<DndEvent<Task>>): void {
    dragging = true;
    columns = { ...columns, [col]: e.detail.items };
  }

  function handleFinalize(col: AgentKanbanColumn, e: CustomEvent<DndEvent<Task>>): void {
    dragging = false;
    const items = e.detail.items;
    columns = { ...columns, [col]: items };

    const moved = items.find((t) => t.id !== SHADOW_PLACEHOLDER_ITEM_ID && !belongsTo(t, col));
    if (!moved) return;

    void applyTransition(moved, col);
  }

  function belongsTo(task: Task, col: AgentKanbanColumn): boolean {
    if (col === 'done') return task.status === 'done';
    if (col === 'in_progress') {
      return Boolean((task as unknown as { sessionId?: string }).sessionId);
    }
    if (col === 'claimed') {
      const c = (task as unknown as { claimedByAgentId?: string | null }).claimedByAgentId;
      return Boolean(c) && !(task as unknown as { sessionId?: string }).sessionId;
    }
    // backlog
    const claim = (task as unknown as { claimedByAgentId?: string | null }).claimedByAgentId;
    return !claim;
  }

  async function applyTransition(task: Task, target: AgentKanbanColumn): Promise<void> {
    try {
      if (target === 'done') {
        if (!confirm(`Mark "${task.title}" as done?`)) {
          await invalidate();
          return;
        }
        await $completeMut.mutateAsync({ taskId: task.shortId });
        toasts.success('Marked done');
      } else if (target === 'backlog') {
        await $releaseMut.mutateAsync(task.shortId);
        toasts.success('Released to backlog');
      } else if (target === 'claimed') {
        // Need an agent — pick the first idle agent. If none, surface an error.
        const candidate = ($idleQuery.data ?? [])[0];
        if (!candidate) {
          toasts.error('No idle agents available to claim');
          await invalidate();
          return;
        }
        await $claimMut.mutateAsync({
          agentSlug: candidate.slug,
          taskId: task.shortId,
        });
        toasts.success(`Claimed by ${candidate.slug}`);
      } else {
        // in_progress is reached via dispatch — covered by Tasks.Dispatcher
        // and the existing /tasks/:id/dispatch endpoint, not this pane.
        toasts.info('Move to In Progress via the agent dispatch action');
        await invalidate();
        return;
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Transition failed';
      toasts.error(msg);
    }
    await invalidate();
  }

  async function invalidate(): Promise<void> {
    await queryClient.invalidateQueries({ queryKey: ['agent-kanban'] });
  }

  // ── Manual claim from rail drop ───────────────────────────────────────────

  function handleRailClaim(agentSlug: string, taskShortId: string): void {
    $claimMut.mutate(
      { agentSlug, taskId: taskShortId },
      {
        onSuccess: () => {
          toasts.success(`Claimed by ${agentSlug}`);
          void invalidate();
        },
        onError: (err) => {
          toasts.error(err instanceof Error ? err.message : 'Claim failed');
        },
      },
    );
  }
</script>

<div class="akp-root" data-workspace={workspaceSlug}>
  {#if $boardQuery.isLoading}
    <div class="akp-status">Loading board…</div>
  {:else if $boardQuery.isError}
    <div class="akp-status akp-status--error">
      Failed to load: {$boardQuery.error?.message ?? 'unknown error'}
    </div>
  {:else}
    <div class="akp-board" role="region" aria-label="Agent Kanban board">
      {#each KANBAN_COLUMNS as col (col.key)}
        <KanbanColumn
          column={col.key}
          label={col.label}
          items={columns[col.key]}
          showAutoPickupToggle={col.key === 'backlog'}
          autoPickupOn={col.key === 'backlog' ? autoPickupOn : false}
          onAutoPickupToggle={() => (autoPickupOn = !autoPickupOn)}
          onConsider={(e) => handleConsider(col.key, e)}
          onFinalize={(e) => handleFinalize(col.key, e)}
        />
      {/each}
    </div>
  {/if}

  <IdleAgentsRail
    agents={$idleQuery.data ?? []}
    onClaim={handleRailClaim}
  />
</div>

<style>
  .akp-root {
    display: flex;
    flex: 1;
    min-height: 0;
    height: 100%;
    background: var(--bg);
  }

  .akp-board {
    flex: 1;
    display: flex;
    gap: 12px;
    padding: 12px;
    overflow-x: auto;
    align-items: stretch;
    min-height: 0;
  }

  .akp-status {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--fg-subtle);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
  }

  .akp-status--error {
    color: var(--signal-error, oklch(0.55 0.22 25));
  }
</style>
