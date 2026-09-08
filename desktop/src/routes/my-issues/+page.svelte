<script lang="ts">
/**
 * /my-issues — Issues scoped to human assignees (developer view).
 * No filter bar — already scoped. Dense list view only.
 * CSS prefix: mi- (MyIssues)
 * LOC target: ≤ 200.
 */
import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
import { User } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import { ApiError } from '$lib/api/client.js';
import { issuesQuery } from '$lib/api/queries/issues.js';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import IssuePriorityDot from '$lib/design/patterns/IssuePriorityDot.svelte';
import IssueStatusPill from '$lib/design/patterns/IssueStatusPill.svelte';
import SkeletonList from '$lib/design/patterns/SkeletonList.svelte';
import type { Issue, IssueFilters } from '$lib/domain/issues/types.js';

// Scope to human assignees — v1 (no auth context yet)
const filters: IssueFilters = { assigneeType: 'human' };

const queryOptsStore = writable(untrack(() => issuesQuery(filters) as CreateQueryOptions<Issue[]>));

const query = createQuery<Issue[]>(queryOptsStore);

const issues = $derived((($query.data ?? []) as Issue[]).filter((i) => i.status !== 'closed'));

const backendUnavailable = $derived(
  $query.isError &&
    ($query.error instanceof ApiError
      ? $query.error.status === 404
      : String(($query.error as Error)?.message ?? '').includes('404'))
);

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

<div class="mi-page">
  <!-- Header -->
  <header class="mi-header">
    <h1 class="mi-title">My issues</h1>
    {#if !$query.isLoading && !$query.isError}
      <span class="mi-count">{issues.length} open</span>
    {/if}
  </header>

  <!-- Backend-not-ready banner -->
  {#if backendUnavailable}
    <div class="mi-banner" role="status">
      Backend not ready — retry later. Issues endpoint returning 404.
    </div>
  {/if}

  <!-- Loading -->
  {#if $query.isLoading}
    <div class="mi-skeleton">
      <SkeletonList count={8} height="2.25rem" gap="0.25rem" />
    </div>

  <!-- Error (non-404) -->
  {:else if $query.isError && !backendUnavailable}
    <EmptyState
      title="Couldn't load issues"
      body={($query.error as Error).message || 'Check your connection and try again.'}
      action="Retry"
      onAction={() => $query.refetch()}
    />

  <!-- Empty -->
  {:else if issues.length === 0}
    <EmptyState
      icon={User as never}
      title="No issues assigned to you"
      body="Issues assigned to human team members appear here."
    />

  <!-- List -->
  {:else}
    <div class="mi-table-wrap">
      <table class="mi-table" aria-label="My issues">
        <thead>
          <tr>
            <th class="mi-th mi-th-pri" aria-label="Priority"></th>
            <th class="mi-th mi-th-id">ID</th>
            <th class="mi-th mi-th-title">Title</th>
            <th class="mi-th mi-th-status">Status</th>
            <th class="mi-th mi-th-branch">Branch</th>
            <th class="mi-th mi-th-updated">Updated</th>
          </tr>
        </thead>
        <tbody>
          {#each issues as issue (issue.id)}
            <!-- svelte-ignore a11y_interactive_supports_focus -->
            <tr
              class="mi-row"
              role="button"
              onclick={() => goto(`/issues/${issue.shortId}`)}
              onkeydown={(e) => e.key === 'Enter' && goto(`/issues/${issue.shortId}`)}
            >
              <td class="mi-td mi-td-pri">
                <IssuePriorityDot priority={issue.priority} />
              </td>
              <td class="mi-td mi-mono">{issue.shortId}</td>
              <td class="mi-td mi-td-title">{issue.title}</td>
              <td class="mi-td">
                <IssueStatusPill status={issue.status} />
              </td>
              <td class="mi-td mi-mono">
                {#if issue.branch}
                  <code class="mi-branch">{issue.branch}</code>
                {:else}
                  <span class="mi-empty">—</span>
                {/if}
              </td>
              <td class="mi-td mi-mono">{relativeTime(issue.updatedAt)}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>

<style>
  .mi-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  .mi-header {
    display: flex;
    align-items: baseline;
    gap: var(--space-3);
    padding: var(--space-5) var(--space-6) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .mi-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    letter-spacing: -0.025em;
  }

  .mi-count {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
  }

  .mi-banner {
    margin: var(--space-3) var(--space-6);
    padding: var(--space-2) var(--space-3);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    flex-shrink: 0;
  }

  .mi-skeleton {
    flex: 1;
    padding: var(--space-4) var(--space-6);
    overflow: hidden;
  }

  .mi-table-wrap {
    flex: 1;
    overflow-y: auto;
    overflow-x: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .mi-table {
    width: 100%;
    border-collapse: collapse;
    table-layout: fixed;
  }

  .mi-th {
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

  .mi-th-pri     { width: 32px; padding-left: var(--space-4); }
  .mi-th-id      { width: 110px; }
  .mi-th-title   { min-width: 220px; }
  .mi-th-status  { width: 110px; }
  .mi-th-branch  { width: 160px; }
  .mi-th-updated { width: 90px; }

  :global(.mi-row) {
    cursor: pointer;
    transition: background 0.08s ease;
  }
  :global(.mi-row:hover) {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }

  .mi-td {
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    border-bottom: 1px solid var(--border);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  :global(.mi-row:last-child .mi-td) { border-bottom: none; }

  .mi-td-pri   { padding-left: var(--space-4); }
  .mi-td-title { font-weight: 500; }

  .mi-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  .mi-branch {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-muted);
    background: var(--bg-inset);
    padding: 1px 4px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
  }

  .mi-empty { color: var(--fg-subtle); }
</style>
