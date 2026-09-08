<script lang="ts">
/**
 * IssuesBoardView — 5-column inline kanban for the issues board view.
 * CSS prefix: il- (shared with /issues page).
 */
import { goto } from '$app/navigation';
import IssuePriorityDot from '$lib/design/patterns/IssuePriorityDot.svelte';
import type { Issue, IssueStatus } from '$lib/domain/issues/types.js';

interface Props {
  issues: Issue[];
}

let { issues }: Props = $props();

const BOARD_COLS: { status: IssueStatus; label: string }[] = [
  { status: 'backlog', label: 'Backlog' },
  { status: 'open', label: 'Open' },
  { status: 'in_progress', label: 'In Progress' },
  { status: 'in_review', label: 'In Review' },
  { status: 'closed', label: 'Closed' },
];

function issuesForStatus(s: IssueStatus): Issue[] {
  return issues.filter((i) => i.status === s);
}
</script>

<div class="il-board">
  {#each BOARD_COLS as col (col.status)}
    {@const colIssues = issuesForStatus(col.status)}
    <div class="il-board-col">
      <div class="il-board-col-head">
        <span class="il-board-col-label">{col.label}</span>
        <span class="il-board-col-count">{colIssues.length}</span>
      </div>
      <div class="il-board-col-body">
        {#if colIssues.length === 0}
          <p class="il-board-empty">No issues</p>
        {:else}
          {#each colIssues as issue (issue.id)}
            <!-- svelte-ignore a11y_interactive_supports_focus -->
            <div
              class="il-board-card"
              role="button"
              onclick={() => goto(`/issues/${issue.shortId}`)}
              onkeydown={(e) => e.key === 'Enter' && goto(`/issues/${issue.shortId}`)}
            >
              <div class="il-board-card-top">
                <IssuePriorityDot priority={issue.priority} />
                <span class="il-mono il-board-id">{issue.shortId}</span>
              </div>
              <p class="il-board-card-title">{issue.title}</p>
              {#if issue.labels.length > 0}
                <div class="il-board-labels">
                  {#each issue.labels.slice(0, 2) as label (label.id)}
                    <span class="il-label-chip">{label.name}</span>
                  {/each}
                </div>
              {/if}
            </div>
          {/each}
        {/if}
      </div>
    </div>
  {/each}
</div>

<style>
  .il-board {
    flex: 1;
    display: grid;
    grid-template-columns: repeat(5, minmax(200px, 1fr));
    gap: 0;
    overflow-x: auto;
    overflow-y: hidden;
    border-top: 1px solid var(--border);
  }

  .il-board-col {
    display: flex;
    flex-direction: column;
    border-right: 1px solid var(--border);
    min-height: 0;
    overflow: hidden;
  }

  .il-board-col:last-child { border-right: none; }

  .il-board-col-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-2) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .il-board-col-label {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.07em;
    text-transform: uppercase;
    color: var(--fg-subtle);
  }

  .il-board-col-count {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .il-board-col-body {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-2);
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .il-board-empty {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    padding: var(--space-2) 0;
  }

  .il-board-card {
    padding: var(--space-2) var(--space-3);
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    cursor: pointer;
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
    transition: background 0.1s ease;
  }

  .il-board-card:hover {
    background: color-mix(in oklch, var(--fg) 6%, var(--bg-elevated));
  }

  .il-board-card-top {
    display: flex;
    align-items: center;
    gap: var(--space-1);
  }

  .il-board-id {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .il-board-card-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg);
    line-height: 1.4;
    overflow: hidden;
    display: -webkit-box;
    -webkit-line-clamp: 3;
    line-clamp: 3;
    -webkit-box-orient: vertical;
  }

  .il-board-labels {
    display: flex;
    flex-wrap: wrap;
    gap: 3px;
  }

  .il-label-chip {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 500;
    padding: 1px 6px;
    border-radius: 9999px;
    border: 1px solid var(--border);
    color: var(--fg-muted);
    background: var(--bg-inset);
    white-space: nowrap;
  }

  .il-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }
</style>
