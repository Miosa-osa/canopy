<script lang="ts">
  /**
   * IssueDetailSidebar — PushPanel content for the issue detail page.
   * Renders the properties panel (status, priority, metadata).
   * CSS prefix: id- (shared with /issues/[short_id] page).
   */
  import { ExternalLink } from 'lucide-svelte';
  import PushPanel from '$lib/design/patterns/PushPanel.svelte';
  import IssuePriorityDot from '$lib/design/patterns/IssuePriorityDot.svelte';
  import type { Issue, IssueStatus, IssuePriority } from '$lib/domain/issues/types.js';

  interface Props {
    issue: Issue;
    open: boolean;
    onClose: () => void;
    onUpdateStatus: (status: IssueStatus) => void;
    onUpdatePriority: (priority: IssuePriority) => void;
  }

  let { issue, open, onClose, onUpdateStatus, onUpdatePriority }: Props = $props();

  function formatDate(iso: string | null): string {
    if (!iso) return '—';
    return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
  }
</script>

<PushPanel {open} title="Properties" {onClose}>
  <!-- Status picker -->
  <div class="id-prop-field">
    <span class="id-prop-key">Status</span>
    <select
      class="id-prop-select"
      value={issue.status}
      onchange={(e) => onUpdateStatus((e.currentTarget as HTMLSelectElement).value as IssueStatus)}
      aria-label="Status"
    >
      <option value="backlog">Backlog</option>
      <option value="open">Open</option>
      <option value="in_progress">In Progress</option>
      <option value="in_review">In Review</option>
      <option value="closed">Closed</option>
    </select>
  </div>

  <!-- Priority picker -->
  <div class="id-prop-field">
    <span class="id-prop-key">Priority</span>
    <div class="id-prop-row">
      <IssuePriorityDot priority={issue.priority} />
      <select
        class="id-prop-select"
        value={issue.priority}
        onchange={(e) => onUpdatePriority(Number((e.currentTarget as HTMLSelectElement).value) as IssuePriority)}
        aria-label="Priority"
      >
        <option value={0}>None</option>
        <option value={1}>Low</option>
        <option value={2}>Medium</option>
        <option value={3}>High</option>
      </select>
    </div>
  </div>

  <dl class="id-meta">
    <dt class="id-meta-key">Assignee</dt>
    <dd class="id-meta-val id-mono">
      {#if issue.assigneeType && issue.assigneeId}
        {issue.assigneeType === 'agent' ? '[A]' : '[H]'} {issue.assigneeId}
      {:else}
        —
      {/if}
    </dd>

    <dt class="id-meta-key">Labels</dt>
    <dd class="id-meta-val">
      {#if issue.labels.length > 0}
        <div class="id-tags">
          {#each issue.labels as label (label.id)}
            <span class="id-tag">{label.name}</span>
          {/each}
        </div>
      {:else}
        —
      {/if}
    </dd>

    <dt class="id-meta-key">Estimate</dt>
    <dd class="id-meta-val id-mono">
      {issue.estimateMinutes != null ? `${issue.estimateMinutes}m` : '—'}
    </dd>

    <dt class="id-meta-key">Branch</dt>
    <dd class="id-meta-val id-mono">
      {#if issue.branch}
        <code class="id-code">{issue.branch}</code>
      {:else}—{/if}
    </dd>

    <dt class="id-meta-key">PR</dt>
    <dd class="id-meta-val">
      {#if issue.prUrl}
        <a class="id-pr-link" href={issue.prUrl} target="_blank" rel="noreferrer" aria-label="Open pull request">
          <ExternalLink size={12} aria-hidden="true" />
          Open PR
        </a>
      {:else}
        —
      {/if}
    </dd>

    <dt class="id-meta-key">Parent</dt>
    <dd class="id-meta-val id-mono">{issue.parentId ?? '—'}</dd>

    <dt class="id-meta-key">Due</dt>
    <dd class="id-meta-val id-mono">{formatDate(issue.dueAt)}</dd>

    <dt class="id-meta-key">Created</dt>
    <dd class="id-meta-val id-mono">{formatDate(issue.insertedAt)}</dd>

    <dt class="id-meta-key">Updated</dt>
    <dd class="id-meta-val id-mono">{formatDate(issue.updatedAt)}</dd>
  </dl>
</PushPanel>

<style>
  .id-prop-field {
    display: flex;
    flex-direction: column;
    gap: 4px;
    margin-bottom: var(--space-3);
  }

  .id-prop-key {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .id-prop-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .id-prop-select {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-1) var(--space-2);
    outline: none;
    cursor: pointer;
    flex: 1;
  }

  .id-meta {
    display: grid;
    grid-template-columns: auto 1fr;
    gap: var(--space-2) var(--space-3);
    margin: 0;
    border-top: 1px solid var(--border);
    padding-top: var(--space-3);
  }

  .id-meta-key {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    align-self: start;
    padding-top: 1px;
  }

  .id-meta-val {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    word-break: break-word;
  }

  .id-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  .id-code {
    font-family: var(--font-mono);
    font-size: 11px;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 1px 4px;
  }

  .id-pr-link {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--cnp-accent, oklch(0.78 0.18 145));
    text-decoration: none;
  }
  .id-pr-link:hover { text-decoration: underline; }

  .id-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
  }

  .id-tag {
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--fg-subtle);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 1px 5px;
  }
</style>
