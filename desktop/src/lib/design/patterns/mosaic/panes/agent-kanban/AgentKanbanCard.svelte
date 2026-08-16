<script lang="ts">
  /**
   * AgentKanbanCard — single task card within an Agent Kanban column.
   * CSS prefix: akc-
   *
   * Renders title, priority dot, claimed-by chip (when set), required-skills
   * tags, and a session badge when in_progress. Wraps the existing Task domain
   * shape — does NOT extend it.
   */

  import type { Task, TaskPriority } from '$lib/domain/tasks/types.js';

  interface Props {
    task: Task & {
      claimedByAgentId?: string | null;
      requiredSkills?: string[];
    };
  }

  let { task }: Props = $props();

  const PRIORITY_LABELS: Record<TaskPriority, string> = {
    0: 'none',
    1: 'low',
    2: 'med',
    3: 'high',
  };

  const claimedBy = $derived(
    (task as unknown as { claimedByAgentId?: string | null; claimed_by_agent_id?: string | null })
      .claimedByAgentId ??
      (task as unknown as { claimed_by_agent_id?: string | null }).claimed_by_agent_id ??
      null,
  );

  const requiredSkills = $derived(
    (task as unknown as { requiredSkills?: string[]; required_skills?: string[] }).requiredSkills ??
      (task as unknown as { required_skills?: string[] }).required_skills ??
      [],
  );

  const priorityLabel = $derived(PRIORITY_LABELS[task.priority] ?? 'none');
</script>

<article
  class="akc-card"
  data-priority={task.priority}
  data-status={task.status}
  aria-label={`Task ${task.shortId}: ${task.title}`}
>
  <header class="akc-card__head">
    <span class="akc-card__priority" aria-label={`Priority ${priorityLabel}`}></span>
    <h3 class="akc-card__title">{task.title}</h3>
  </header>

  <div class="akc-card__meta">
    <span class="akc-card__short-id">{task.shortId}</span>
    {#if claimedBy}
      <span class="akc-card__claim" aria-label={`Claimed by ${claimedBy}`}>
        @{claimedBy}
      </span>
    {/if}
  </div>

  {#if requiredSkills.length > 0}
    <ul class="akc-card__skills" aria-label="Required skills">
      {#each requiredSkills as skill (skill)}
        <li class="akc-card__skill">{skill}</li>
      {/each}
    </ul>
  {/if}

  {#if task.status === 'in_progress' && (task as unknown as { sessionId?: string }).sessionId}
    <footer class="akc-card__footer">
      <span class="akc-card__session">
        session {String((task as unknown as { sessionId?: string }).sessionId).slice(0, 8)}
      </span>
    </footer>
  {/if}
</article>

<style>
  .akc-card {
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding: 10px 12px;
    border-radius: var(--radius-md);
    background: var(--surface, var(--bg));
    border: 1px solid var(--border);
    font-family: var(--font-sans);
    cursor: grab;
    transition: border-color 0.1s ease, box-shadow 0.1s ease;
  }

  .akc-card:hover {
    border-color: color-mix(in oklch, var(--fg) 25%, transparent);
  }

  .akc-card:active {
    cursor: grabbing;
  }

  .akc-card__head {
    display: flex;
    align-items: flex-start;
    gap: 8px;
  }

  .akc-card__priority {
    flex-shrink: 0;
    width: 8px;
    height: 8px;
    margin-top: 5px;
    border-radius: 50%;
    background: var(--fg-subtle);
  }

  .akc-card[data-priority="1"] .akc-card__priority { background: oklch(0.75 0.12 190); }
  .akc-card[data-priority="2"] .akc-card__priority { background: oklch(0.78 0.16 75); }
  .akc-card[data-priority="3"] .akc-card__priority { background: oklch(0.62 0.22 25); }

  .akc-card__title {
    flex: 1;
    margin: 0;
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
    line-height: 1.35;
    /* clamp to 2 lines */
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  .akc-card__meta {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 11px;
    color: var(--fg-subtle);
  }

  .akc-card__short-id {
    font-family: var(--font-mono);
  }

  .akc-card__claim {
    padding: 1px 6px;
    border-radius: var(--radius-sm);
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 18%, transparent);
    color: var(--fg);
  }

  .akc-card__skills {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    margin: 0;
    padding: 0;
    list-style: none;
  }

  .akc-card__skill {
    padding: 1px 6px;
    border-radius: var(--radius-sm);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg-muted);
    font-size: 10px;
  }

  .akc-card__footer {
    border-top: 1px solid var(--border);
    padding-top: 6px;
    font-size: 10px;
    color: var(--fg-subtle);
    font-family: var(--font-mono);
  }
</style>
