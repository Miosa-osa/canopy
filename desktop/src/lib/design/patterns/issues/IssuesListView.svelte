<script lang="ts">
/**
 * IssuesListView — table rendering + empty/loading/error states for the issues list view.
 * CSS prefix: il- (shared with /issues page).
 */

import { CircleDot } from 'lucide-svelte';
import { goto } from '$app/navigation';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import IssuePriorityDot from '$lib/design/patterns/IssuePriorityDot.svelte';
import IssueStatusPill from '$lib/design/patterns/IssueStatusPill.svelte';
import SkeletonList from '$lib/design/patterns/SkeletonList.svelte';
import type { Issue } from '$lib/domain/issues/types.js';

interface Props {
  issues: Issue[];
  isLoading: boolean;
  isError: boolean;
  errorMessage: string;
  statusTab: string;
  assigneeFilter: string;
  onRetry: () => void;
  onNewIssue: () => void;
}

let {
  issues,
  isLoading,
  isError,
  errorMessage,
  statusTab,
  assigneeFilter,
  onRetry,
  onNewIssue,
}: Props = $props();

function relativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60_000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  return `${Math.floor(hrs / 24)}d ago`;
}
</script>

{#if isLoading}
  <div class="il-skeleton-wrap">
    <SkeletonList count={10} height="2.25rem" gap="0.25rem" />
  </div>

{:else if isError}
  <EmptyState
    title="Couldn't load issues"
    body={errorMessage || 'Check your connection and try again.'}
    action="Retry"
    onAction={onRetry}
  />

{:else if issues.length === 0}
  <EmptyState
    icon={CircleDot as never}
    title="No issues"
    body={statusTab !== 'all' || assigneeFilter !== 'all'
      ? 'No issues match your filters.'
      : 'Create your first issue to get started.'}
    action="+ New issue"
    onAction={onNewIssue}
  />

{:else}
  <div class="il-table-wrap">
    <table class="il-table" aria-label="Issue list">
      <thead>
        <tr>
          <th class="il-th il-th-pri" aria-label="Priority"></th>
          <th class="il-th il-th-id">ID</th>
          <th class="il-th il-th-title">Title</th>
          <th class="il-th il-th-status">Status</th>
          <th class="il-th il-th-labels">Labels</th>
          <th class="il-th il-th-branch">Branch</th>
          <th class="il-th il-th-updated">Updated</th>
        </tr>
      </thead>
      <tbody>
        {#each issues as issue (issue.id)}
          <!-- svelte-ignore a11y_interactive_supports_focus -->
          <tr
            class="il-row"
            role="button"
            onclick={() => goto(`/issues/${issue.shortId}`)}
            onkeydown={(e) => e.key === 'Enter' && goto(`/issues/${issue.shortId}`)}
          >
            <td class="il-td il-td-pri">
              <IssuePriorityDot priority={issue.priority} />
            </td>
            <td class="il-td il-mono il-td-id">{issue.shortId}</td>
            <td class="il-td il-td-title">{issue.title}</td>
            <td class="il-td il-td-status">
              <IssueStatusPill status={issue.status} />
              {#if issue.reviewId}
                <a
                  class="il-review-pill"
                  href="/reviews/{issue.reviewId}"
                  aria-label="Under review — view review"
                  onclick={(e) => e.stopPropagation()}
                >Under review</a>
              {/if}
            </td>
            <td class="il-td il-td-labels">
              {#if issue.labels.length > 0}
                <div class="il-labels">
                  {#each issue.labels.slice(0, 3) as label (label.id)}
                    <span class="il-label-chip">{label.name}</span>
                  {/each}
                  {#if issue.labels.length > 3}
                    <span class="il-label-more">+{issue.labels.length - 3}</span>
                  {/if}
                </div>
              {:else}
                <span class="il-empty-cell">—</span>
              {/if}
            </td>
            <td class="il-td il-td-branch">
              {#if issue.branch}
                <code class="il-branch">{issue.branch}</code>
              {:else}
                <span class="il-empty-cell">—</span>
              {/if}
            </td>
            <td class="il-td il-mono il-td-updated">
              {relativeTime(issue.updatedAt)}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
{/if}

<style>
  /* Skeleton */
  .il-skeleton-wrap {
    flex: 1;
    padding: var(--space-4) var(--space-6);
    overflow: hidden;
  }

  /* List table */
  .il-table-wrap {
    flex: 1;
    overflow-y: auto;
    overflow-x: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .il-table {
    width: 100%;
    border-collapse: collapse;
    table-layout: fixed;
  }

  .il-th {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-subtle);
    padding: var(--space-2) var(--space-3);
    text-align: left;
    border-bottom: 1px solid var(--border);
    letter-spacing: 0.06em;
    text-transform: uppercase;
    white-space: nowrap;
    position: sticky;
    top: 0;
    background: var(--bg);
    z-index: 1;
  }

  .il-th-pri { width: 32px; padding-left: var(--space-4); }
  .il-th-id { width: 110px; }
  .il-th-title { min-width: 220px; }
  .il-th-status { width: 110px; }
  .il-th-labels { width: 180px; }
  .il-th-branch { width: 160px; }
  .il-th-updated { width: 90px; }

  :global(.il-row) {
    cursor: pointer;
    transition: background 0.08s ease;
  }
  :global(.il-row:hover) {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }

  .il-td {
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    border-bottom: 1px solid var(--border);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  :global(.il-row:last-child .il-td) { border-bottom: none; }

  .il-td-pri { padding-left: var(--space-4); }
  .il-td-title { font-weight: 500; }

  .il-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  .il-empty-cell { color: var(--fg-subtle); }

  .il-labels {
    display: flex;
    align-items: center;
    gap: 4px;
    flex-wrap: nowrap;
    overflow: hidden;
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

  .il-label-more {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .il-branch {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-muted);
    background: var(--bg-inset);
    padding: 1px 4px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 150px;
    display: inline-block;
  }

  .il-review-pill {
    display: inline-block;
    margin-left: var(--space-2);
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 500;
    padding: 1px 6px;
    border-radius: var(--radius-sm);
    white-space: nowrap;
    background: color-mix(in oklch, oklch(0.78 0.15 85) 20%, transparent 80%);
    color: color-mix(in oklch, oklch(0.55 0.15 85) 90%, var(--fg) 10%);
    border: 1px solid color-mix(in oklch, oklch(0.78 0.15 85) 40%, transparent 60%);
    text-decoration: none;
    cursor: pointer;
  }

  .il-review-pill:hover {
    background: color-mix(in oklch, oklch(0.78 0.15 85) 30%, transparent 70%);
  }
</style>
