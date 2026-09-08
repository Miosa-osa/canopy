<script lang="ts">
/**
 * /review — Human-review approval queue + git changes panel.
 * CSS prefix: rq- (ReviewQueue)
 * LOC target: ≤ 320.
 */
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import {
  Bot,
  Database,
  FileText,
  GitBranch,
  Plus,
  RefreshCw,
  Search,
  ShieldCheck,
  Terminal,
} from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import {
  approveReviewMutation,
  createReviewMutation,
  rejectReviewMutation,
  requestChangesMutation,
  resubmitReviewMutation,
  reviewSummaryQuery,
  reviewsQuery,
} from '$lib/api/queries/reviews.js';
import ReviewCreateModal from '$lib/design/patterns/ReviewCreateModal.svelte';
import ReviewDetailModal from '$lib/design/patterns/ReviewDetailModal.svelte';
import GitChangesPanel from '$lib/design/patterns/review/GitChangesPanel.svelte';
import type {
  ApproveReviewBody,
  CreateReviewBody,
  RejectReviewBody,
  RequestChangesBody,
  Review,
  ReviewFilters,
  ReviewSummary,
} from '$lib/domain/reviews/types.js';
import { toasts } from '$lib/stores/toasts.svelte.js';

const queryClient = useQueryClient();

// ── Top-level view switcher ───────────────────────────────────────────────────

type View = 'overview' | 'queue' | 'sources' | 'git';
let activeView = $state<View>('overview');

// ── Tab state ─────────────────────────────────────────────────────────────────

type Tab =
  | 'all'
  | 'artifacts'
  | 'tool_calls'
  | 'hire_agents'
  | 'approved'
  | 'rejected'
  | 'changes_requested';
let activeTab = $state<Tab>('all');

const tabFilters: Record<Tab, ReviewFilters> = {
  all: {},
  artifacts: { kind: 'artifact' },
  tool_calls: { kind: 'tool_call' },
  hire_agents: { kind: 'hire_agent' },
  approved: { status: 'approved' },
  rejected: { status: 'rejected' },
  changes_requested: { status: 'changes_requested' },
};

// ── Query ─────────────────────────────────────────────────────────────────────

const queryOptsStore = writable(
  untrack(() => reviewsQuery(tabFilters[activeTab]) as CreateQueryOptions<Review[]>)
);

$effect(() => {
  queryOptsStore.set(reviewsQuery(tabFilters[activeTab]) as CreateQueryOptions<Review[]>);
});

const query = createQuery<Review[]>(queryOptsStore);
const reviews = $derived(($query.data ?? []) as Review[]);
const summaryQuery = createQuery<ReviewSummary>(
  reviewSummaryQuery() as CreateQueryOptions<ReviewSummary>
);
const summary = $derived($summaryQuery.data as ReviewSummary | undefined);
let searchQuery = $state('');
let workspaceFilter = $state('');

const filteredReviews = $derived.by(() => {
  const search = searchQuery.trim().toLowerCase();
  const workspace = workspaceFilter.trim().toLowerCase();

  return reviews.filter((review) => {
    const matchesWorkspace =
      !workspace || (review.workspaceSlug ?? '').toLowerCase().includes(workspace);
    if (!matchesWorkspace) return false;
    if (!search) return true;

    const haystack = [
      review.id,
      review.workspaceSlug,
      review.kind,
      review.status,
      review.artifactType,
      review.artifactId,
      review.artifactPreview,
      review.toolName,
      review.toolArgs ? JSON.stringify(review.toolArgs) : null,
      review.sessionId,
      review.agentId,
      review.feedback,
    ]
      .filter(Boolean)
      .join(' ')
      .toLowerCase();

    return haystack.includes(search);
  });
});

const pendingCount = $derived(reviews.filter((r) => r.status === 'pending').length);
const artifactCount = $derived(reviews.filter((r) => r.kind === 'artifact').length);
const toolCallCount = $derived(reviews.filter((r) => r.kind === 'tool_call').length);
const hireAgentCount = $derived(reviews.filter((r) => r.kind === 'hire_agent').length);
const summaryPendingCount = $derived(summary?.pendingCount ?? pendingCount);

// ── Detail modal ──────────────────────────────────────────────────────────────

let selectedReview = $state<Review | null>(null);
let createOpen = $state(false);

// ── Mutations ─────────────────────────────────────────────────────────────────

const approveMut = createMutation<Review, Error, { id: string; body?: ApproveReviewBody }>(
  approveReviewMutation() as CreateMutationOptions<
    Review,
    Error,
    { id: string; body?: ApproveReviewBody }
  >
);

const rejectMut = createMutation<Review, Error, { id: string; body?: RejectReviewBody }>(
  rejectReviewMutation() as CreateMutationOptions<
    Review,
    Error,
    { id: string; body?: RejectReviewBody }
  >
);

const changesMut = createMutation<Review, Error, { id: string; body?: RequestChangesBody }>(
  requestChangesMutation() as CreateMutationOptions<
    Review,
    Error,
    { id: string; body?: RequestChangesBody }
  >
);

const resubmitMut = createMutation<
  Review,
  Error,
  { id: string; attrs?: { artifactPreview?: string } }
>(
  resubmitReviewMutation() as CreateMutationOptions<
    Review,
    Error,
    { id: string; attrs?: { artifactPreview?: string } }
  >
);

const createMut = createMutation<Review, Error, CreateReviewBody>(
  createReviewMutation() as CreateMutationOptions<Review, Error, CreateReviewBody>
);

const isMutating = $derived(
  $approveMut.isPending || $rejectMut.isPending || $changesMut.isPending || $resubmitMut.isPending
);

function invalidate(): void {
  queryClient.invalidateQueries({ queryKey: ['reviews'] });
}

function handleApprove(body: ApproveReviewBody): void {
  if (!selectedReview) return;
  $approveMut.mutate(
    { id: selectedReview.id, body },
    {
      onSuccess: () => {
        toasts.success('Review approved');
        selectedReview = null;
        invalidate();
      },
      onError: (err) => toasts.error(`Approve failed: ${err.message}`),
    }
  );
}

function handleReject(body: RejectReviewBody): void {
  if (!selectedReview) return;
  $rejectMut.mutate(
    { id: selectedReview.id, body },
    {
      onSuccess: () => {
        toasts.success('Review rejected');
        selectedReview = null;
        invalidate();
      },
      onError: (err) => toasts.error(`Reject failed: ${err.message}`),
    }
  );
}

function handleRequestChanges(body: RequestChangesBody): void {
  if (!selectedReview) return;
  $changesMut.mutate(
    { id: selectedReview.id, body },
    {
      onSuccess: () => {
        toasts.success('Changes requested');
        selectedReview = null;
        invalidate();
      },
      onError: (err) => toasts.error(`Request changes failed: ${err.message}`),
    }
  );
}

function handleResubmit(): void {
  if (!selectedReview) return;
  $resubmitMut.mutate(
    { id: selectedReview.id },
    {
      onSuccess: (updated) => {
        toasts.success('Resubmitted for review');
        selectedReview = updated;
        invalidate();
      },
      onError: (err) => toasts.error(`Resubmit failed: ${err.message}`),
    }
  );
}

function handleCreate(body: CreateReviewBody): void {
  $createMut.mutate(body, {
    onSuccess: (review) => {
      toasts.success('Review created');
      createOpen = false;
      selectedReview = review;
      invalidate();
    },
    onError: (err) => toasts.error(`Create failed: ${err.message}`),
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function statusClass(status: string): string {
  if (status === 'pending') return 'rq-status rq-status--pending';
  if (status === 'approved') return 'rq-status rq-status--approved';
  if (status === 'rejected') return 'rq-status rq-status--rejected';
  if (status === 'changes_requested') return 'rq-status rq-status--changes';
  return 'rq-status rq-status--expired';
}

function reviewTitle(r: Review): string {
  if (r.kind === 'tool_call') return r.toolName ?? 'tool_call';
  if (r.kind === 'hire_agent') {
    const slug = (r.toolArgs?.['child_agent_slug'] as string | undefined) ?? 'agent';
    return `Hire: ${slug}`;
  }
  return r.artifactType
    ? `${r.artifactType}${r.artifactId ? ` · ${r.artifactId}` : ''}`
    : 'Artifact';
}

function sourceLabel(r: Review): string {
  if (r.kind === 'artifact') return 'Artifact gate';
  if (r.kind === 'tool_call') return 'Tool approval';
  return 'Agent hire gate';
}

function sourceDetail(r: Review): string {
  if (r.kind === 'artifact') return 'Created by POST /reviews or Canopy.Reviews.request_artifact/1';
  if (r.kind === 'tool_call')
    return 'Created by agent tool dispatch or Canopy.Reviews.request_tool_call/4';
  return 'Created by canopy.spawn_session approval gate';
}

function truncate(s: string | null | undefined, n = 100): string {
  if (!s) return '';
  return s.length > n ? `${s.slice(0, n)}…` : s;
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleString();
}

function formatOptionalTime(iso: string | null | undefined): string {
  return iso ? formatTime(iso) : 'none';
}

function topEntries(values: Record<string, number> | undefined, limit = 4): [string, number][] {
  return Object.entries(values ?? {})
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit);
}

function viewTitle(view: View): string {
  if (view === 'overview') return 'Review overview';
  if (view === 'queue') return 'Review queue';
  if (view === 'sources') return 'Review routing';
  return 'Git changes';
}

const tabs: { id: Tab; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'artifacts', label: 'Artifacts' },
  { id: 'tool_calls', label: 'Tool calls' },
  { id: 'hire_agents', label: 'Hire agent' },
  { id: 'approved', label: 'Approved' },
  { id: 'rejected', label: 'Rejected' },
  { id: 'changes_requested', label: 'Changes requested' },
];
</script>

<div class="rq-page">
  <header class="rq-header">
    {#if activeView === 'git'}
      <GitBranch size={18} aria-hidden="true" class="rq-icon" />
    {:else}
      <ShieldCheck size={18} aria-hidden="true" class="rq-icon" />
    {/if}
    <h1 class="rq-title">{viewTitle(activeView)}</h1>
    {#if activeView !== 'git'}
      {#if summaryPendingCount > 0}
        <span class="rq-badge" aria-label="{summaryPendingCount} pending">{summaryPendingCount}</span>
      {/if}
    {/if}
    <span class="rq-header-spacer"></span>
    {#if activeView !== 'git'}
      <button
        class="btn-pill btn-pill-secondary btn-pill-sm rq-new-btn"
        onclick={() => { createOpen = true; }}
        aria-label="New review"
      >
        <Plus size={13} aria-hidden="true" />
        New
      </button>
      <button
        class="btn-compact btn-compact-ghost rq-refresh"
        onclick={() => { $query.refetch(); $summaryQuery.refetch(); }}
        aria-label="Refresh reviews"
        disabled={$query.isLoading || $summaryQuery.isLoading}
      >
        <RefreshCw size={13} aria-hidden="true" />
      </button>
    {/if}
  </header>

  <!-- View switcher -->
  <nav class="rq-view-tabs" aria-label="Review views">
    <button
      class="rq-view-tab"
      class:rq-view-tab--active={activeView === 'overview'}
      onclick={() => { activeView = 'overview'; }}
      aria-pressed={activeView === 'overview'}
    >
      <ShieldCheck size={12} aria-hidden="true" />
      Overview
    </button>
    <button
      class="rq-view-tab"
      class:rq-view-tab--active={activeView === 'queue'}
      onclick={() => { activeView = 'queue'; }}
      aria-pressed={activeView === 'queue'}
    >
      <ShieldCheck size={12} aria-hidden="true" />
      Queue
    </button>
    <button
      class="rq-view-tab"
      class:rq-view-tab--active={activeView === 'sources'}
      onclick={() => { activeView = 'sources'; }}
      aria-pressed={activeView === 'sources'}
    >
      <Bot size={12} aria-hidden="true" />
      Routing
    </button>
    <button
      class="rq-view-tab"
      class:rq-view-tab--active={activeView === 'git'}
      onclick={() => { activeView = 'git'; }}
      aria-pressed={activeView === 'git'}
    >
      <GitBranch size={12} aria-hidden="true" />
      Git
    </button>
  </nav>

  {#if activeView === 'overview'}
    <section class="rq-overview" aria-label="Review operations summary">
      {#if $summaryQuery.isLoading}
        <p class="rq-empty">Loading summary...</p>
      {:else if $summaryQuery.isError}
        <p class="rq-empty rq-empty--error">
          Could not load summary — {($summaryQuery.error as Error)?.message ?? 'unknown error'}.
        </p>
      {:else}
        <div class="rq-metrics">
          <div class="rq-metric">
            <span>Total</span>
            <strong>{summary?.total ?? 0}</strong>
            <small>Rows in <code>reviews</code></small>
          </div>
          <div class="rq-metric">
            <span>Pending</span>
            <strong>{summary?.pendingCount ?? 0}</strong>
            <small>Waiting on a human decision</small>
          </div>
          <div class="rq-metric">
            <span>Decided</span>
            <strong>{summary?.decidedCount ?? 0}</strong>
            <small>Approved or rejected</small>
          </div>
          <div class="rq-metric">
            <span>Changes</span>
            <strong>{summary?.changesRequestedCount ?? 0}</strong>
            <small>Waiting on agent resubmission</small>
          </div>
        </div>

        <div class="rq-overview-grid">
          <section class="rq-panel">
            <h2>Queue timing</h2>
            <dl class="rq-facts">
              <div><dt>Oldest pending</dt><dd>{formatOptionalTime(summary?.oldestPendingAt)}</dd></div>
              <div><dt>Next expiry</dt><dd>{formatOptionalTime(summary?.nextExpiryAt)}</dd></div>
            </dl>
          </section>

          <section class="rq-panel">
            <h2>Status</h2>
            <div class="rq-breakdown">
              {#each topEntries(summary?.byStatus) as [label, count]}
                <span><code>{label}</code><strong>{count}</strong></span>
              {/each}
            </div>
          </section>

          <section class="rq-panel">
            <h2>Review kinds</h2>
            <div class="rq-breakdown">
              {#each topEntries(summary?.byKind) as [label, count]}
                <span><code>{label}</code><strong>{count}</strong></span>
              {/each}
            </div>
          </section>

          <section class="rq-panel">
            <h2>Workspaces</h2>
            <div class="rq-breakdown">
              {#each topEntries(summary?.byWorkspace) as [label, count]}
                <span><code>{label}</code><strong>{count}</strong></span>
              {/each}
            </div>
          </section>

          <section class="rq-panel">
            <h2>Agents</h2>
            <div class="rq-breakdown">
              {#each topEntries(summary?.byAgent) as [label, count]}
                <span><code>{label}</code><strong>{count}</strong></span>
              {/each}
            </div>
          </section>

          <section class="rq-panel rq-panel--wide">
            <h2>Recent reviews</h2>
            <div class="rq-recent-list">
              {#each summary?.recent ?? [] as review (review.id)}
                <button class="rq-recent-row" onclick={() => { selectedReview = review; }}>
                  <span>{reviewTitle(review)}</span>
                  <code>{review.workspaceSlug ?? 'global'}</code>
                  <span class={statusClass(review.status)}>{review.status.replace('_', ' ')}</span>
                </button>
              {:else}
                <p class="rq-empty rq-empty--compact">No review rows yet.</p>
              {/each}
            </div>
          </section>
        </div>
      {/if}
    </section>
  {:else if activeView === 'sources'}
    <section class="rq-agent-map rq-agent-map--standalone" aria-label="Agent review routing">
      <div class="rq-agent-map-head">
        <Bot size={14} aria-hidden="true" />
        <div>
          <h2>Agent routing contract</h2>
          <p>Agents route blocked work here by creating a pending row, then wait for the same row to become approved, rejected, or changes requested.</p>
        </div>
      </div>
      <div class="rq-tool-strip" aria-label="Review tools">
        <code>review.request_artifact</code>
        <code>review.request_tool_call</code>
        <code>review.list</code>
        <code>review.summary</code>
        <code>review.get</code>
        <code>review.approve</code>
        <code>review.reject</code>
        <code>review.request_changes</code>
        <code>review.resubmit</code>
      </div>
      <div class="rq-agent-paths">
        <span><strong>Manual UI</strong><code>POST /api/v1/reviews</code></span>
        <span><strong>Legacy agent tool</strong><code>canopy.request_review</code></span>
        <span><strong>Governance gate</strong><code>Canopy.Governance.Reviewer</code></span>
        <span><strong>Sub-agent gate</strong><code>canopy.spawn_session</code></span>
        <span><strong>Agent/MCP tools</strong><code>Canopy.Tools.Reviews</code></span>
        <span><strong>Workspace scope</strong><code>workspace_slug + agent_id + session_id</code></span>
      </div>
    </section>
  {:else if activeView === 'queue'}
    <section class="rq-explain" aria-label="Review queue source model">
      <div class="rq-explain-head">
        <Database size={14} aria-hidden="true" />
        <div>
          <h2>Saved review records</h2>
          <p>Rows come from the backend <code>reviews</code> table. Agents, governance gates, and the New button create pending rows; decisions update the same row.</p>
        </div>
      </div>
      <div class="rq-flow-grid">
        <div>
          <strong>{artifactCount}</strong>
          <span>Artifacts</span>
          <small>docs, tasks, issues, PRs, files, KB chunks</small>
        </div>
        <div>
          <strong>{toolCallCount}</strong>
          <span>Tool calls</span>
          <small>approval-gated tool invocations</small>
        </div>
        <div>
          <strong>{hireAgentCount}</strong>
          <span>Hire gates</span>
          <small>sub-agent spawn approvals</small>
        </div>
        <div>
          <strong>{pendingCount}</strong>
          <span>Pending</span>
          <small>approve, reject, or request changes</small>
        </div>
      </div>
    </section>

    <section class="rq-agent-map" aria-label="Agent review routing">
      <div class="rq-agent-map-head">
        <Bot size={14} aria-hidden="true" />
        <div>
          <h2>Agent routing contract</h2>
          <p>Agents can route work here through prompt/MCP tools. A pending review blocks the risky step until this queue decides it.</p>
        </div>
      </div>
      <div class="rq-tool-strip" aria-label="Review tools">
        <code>review.request_artifact</code>
        <code>review.request_tool_call</code>
        <code>review.list</code>
        <code>review.summary</code>
        <code>review.get</code>
        <code>review.approve</code>
        <code>review.reject</code>
        <code>review.request_changes</code>
        <code>review.resubmit</code>
      </div>
      <div class="rq-agent-paths">
        <span><strong>Legacy agent tool</strong><code>canopy.request_review</code></span>
        <span><strong>Governance gate</strong><code>Canopy.Governance.Reviewer</code></span>
        <span><strong>Sub-agent gate</strong><code>canopy.spawn_session</code></span>
      </div>
    </section>

    <section class="rq-controls" aria-label="Review queue controls">
      <label class="rq-control">
        <Search size={13} aria-hidden="true" />
        <input bind:value={searchQuery} placeholder="Search id, agent, session, tool, preview..." />
      </label>
      <label class="rq-control rq-control--workspace">
        <span>Workspace</span>
        <input bind:value={workspaceFilter} placeholder="all" />
      </label>
      <span class="rq-control-count">{filteredReviews.length} shown / {reviews.length} loaded</span>
    </section>

    <!-- Filter tabs -->
    <nav class="rq-tabs" aria-label="Review filters">
      {#each tabs as tab (tab.id)}
        <button
          class="rq-tab"
          class:rq-tab--active={activeTab === tab.id}
          onclick={() => { activeTab = tab.id; }}
          aria-pressed={activeTab === tab.id}
        >
          {tab.label}
        </button>
      {/each}
    </nav>

    <!-- List -->
    <div class="rq-list" role="list">
      {#if $query.isLoading}
        <p class="rq-empty">Loading…</p>
      {:else if $query.isError}
        <p class="rq-empty rq-empty--error">
          Could not load reviews — {($query.error as Error)?.message ?? 'unknown error'}.
        </p>
      {:else if reviews.length === 0}
        <p class="rq-empty">No reviews in this category.</p>
      {:else if filteredReviews.length === 0}
        <p class="rq-empty">No reviews match the current search.</p>
      {:else}
        {#each filteredReviews as review (review.id)}
          <div class="rq-row" role="listitem">
            <div class="rq-row-icon" aria-hidden="true">
              {#if review.kind === 'tool_call'}
                <Terminal size={14} />
              {:else}
                <FileText size={14} />
              {/if}
            </div>
            <div class="rq-row-main">
              <div class="rq-row-title-row">
                <span class="rq-row-title">{reviewTitle(review)}</span>
                <span class="rq-source-badge" title={sourceDetail(review)}>{sourceLabel(review)}</span>
                {#if review.revisionCount > 0}
                  <span class="rq-revision-badge">rev {review.revisionCount}</span>
                {/if}
              </div>
              <span class="rq-row-preview">{truncate(review.artifactPreview ?? (review.toolArgs ? JSON.stringify(review.toolArgs) : null))}</span>
              <span class="rq-row-ids">
                <code>{review.workspaceSlug ?? 'global'}</code>
                {#if review.sessionId}<code>session {review.sessionId.slice(0, 8)}</code>{/if}
                <code>id {review.id.slice(0, 8)}</code>
              </span>
            </div>
            <div class="rq-row-meta">
              {#if review.agentId}
                <span class="rq-meta-agent">{review.agentId}</span>
              {/if}
              <span class="rq-meta-time">{formatTime(review.requestedAt)}</span>
            </div>
            <span class={statusClass(review.status)}>{review.status.replace('_', ' ')}</span>
            <button
              class="btn-pill btn-pill-secondary btn-pill-sm rq-review-btn"
              onclick={() => { selectedReview = review; }}
              aria-label="Review {reviewTitle(review)}"
            >
              Review
            </button>
          </div>
        {/each}
      {/if}
    </div>
  {:else}
    <div class="rq-git-panel">
      <GitChangesPanel />
    </div>
  {/if}
</div>

{#if selectedReview}
  <ReviewDetailModal
    review={selectedReview}
    isPending={isMutating}
    onApprove={handleApprove}
    onReject={handleReject}
    onRequestChanges={handleRequestChanges}
    onResubmit={handleResubmit}
    onClose={() => { selectedReview = null; }}
  />
{/if}

{#if createOpen}
  <ReviewCreateModal
    isPending={$createMut.isPending}
    onCreate={handleCreate}
    onClose={() => { createOpen = false; }}
  />
{/if}

<style>
  .rq-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  .rq-header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-5) var(--space-6) var(--space-3);
    flex-shrink: 0;
  }

  .rq-header-spacer { flex: 1; }

  /* View switcher */
  .rq-view-tabs {
    display: flex;
    gap: 2px;
    padding: 0 var(--space-6) var(--space-2);
    flex-shrink: 0;
  }

  .rq-view-tab {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    padding: 4px 10px;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    cursor: pointer;
    transition: color 0.1s ease, background 0.1s ease, border-color 0.1s ease;
  }
  .rq-view-tab:hover { color: var(--fg); background: var(--bg-inset); }
  .rq-view-tab--active {
    color: var(--fg);
    background: var(--bg-inset);
    border-color: var(--fg-muted);
  }
  .rq-view-tab:focus-visible { outline: 2px solid var(--cnp-accent, oklch(0.65 0.18 250)); outline-offset: 1px; }

  /* Git panel container */
  .rq-git-panel {
    flex: 1;
    min-height: 0;
    overflow: hidden;
  }

  .rq-overview {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    padding: var(--space-3) var(--space-6) var(--space-6);
  }

  .rq-metrics {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: var(--space-2);
    margin-bottom: var(--space-3);
  }

  .rq-metric,
  .rq-panel {
    min-width: 0;
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    background: var(--bg-inset);
  }

  .rq-metric {
    padding: var(--space-3);
  }

  .rq-metric span {
    display: block;
    color: var(--fg-subtle);
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .rq-metric strong {
    display: block;
    margin-top: 2px;
    color: var(--fg);
    font-family: var(--font-mono);
    font-size: var(--text-2xl);
    font-weight: 700;
  }

  .rq-metric small {
    display: block;
    margin-top: 2px;
    color: var(--fg-muted);
    font-size: var(--text-xs);
  }

  .rq-metric code {
    font-family: var(--font-mono);
    color: var(--fg);
  }

  .rq-overview-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: var(--space-2);
  }

  .rq-panel {
    padding: var(--space-3);
  }

  .rq-panel--wide {
    grid-column: span 2;
  }

  .rq-panel h2 {
    margin: 0 0 var(--space-2);
    color: var(--fg);
    font-size: var(--text-sm);
    font-weight: 600;
  }

  .rq-facts {
    display: grid;
    gap: var(--space-2);
    margin: 0;
  }

  .rq-facts div {
    display: flex;
    justify-content: space-between;
    gap: var(--space-3);
  }

  .rq-facts dt,
  .rq-facts dd {
    margin: 0;
    font-size: var(--text-xs);
  }

  .rq-facts dt {
    color: var(--fg-subtle);
  }

  .rq-facts dd {
    color: var(--fg);
    font-family: var(--font-mono);
    text-align: right;
  }

  .rq-breakdown {
    display: grid;
    gap: 4px;
  }

  .rq-breakdown span {
    min-width: 0;
    display: flex;
    justify-content: space-between;
    gap: var(--space-2);
    color: var(--fg);
    font-size: var(--text-xs);
  }

  .rq-breakdown code {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-family: var(--font-mono);
    color: var(--fg-muted);
  }

  .rq-breakdown strong {
    font-family: var(--font-mono);
  }

  .rq-recent-list {
    display: grid;
    gap: 2px;
  }

  .rq-recent-row {
    min-width: 0;
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(80px, 140px) auto;
    align-items: center;
    gap: var(--space-2);
    width: 100%;
    padding: var(--space-2);
    border: 1px solid transparent;
    border-radius: var(--radius-sm);
    background: transparent;
    color: var(--fg);
    text-align: left;
    cursor: pointer;
  }

  .rq-recent-row:hover {
    border-color: var(--border);
    background: var(--bg);
  }

  .rq-recent-row span:first-child {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-size: var(--text-xs);
  }

  .rq-recent-row code {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    color: var(--fg-muted);
    font-family: var(--font-mono);
    font-size: 10px;
  }

  :global(.rq-icon) { color: var(--fg-muted); }

  .rq-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    letter-spacing: -0.025em;
  }

  .rq-badge {
    min-width: 20px;
    height: 20px;
    padding: 0 6px;
    border-radius: 9999px;
    background: var(--signal-warning);
    color: var(--bg);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 700;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .rq-refresh { color: var(--fg-muted); }
  .rq-new-btn { display: inline-flex; align-items: center; gap: var(--space-1); }

  .rq-explain {
    flex-shrink: 0;
    margin: 0 var(--space-6) var(--space-3);
    padding: var(--space-3);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    background: var(--bg-inset);
  }

  .rq-explain-head {
    display: flex;
    gap: var(--space-2);
    align-items: flex-start;
    color: var(--fg-muted);
  }

  .rq-explain h2 {
    margin: 0;
    color: var(--fg);
    font-size: var(--text-sm);
    font-weight: 600;
  }

  .rq-explain p {
    margin: 3px 0 0;
    color: var(--fg-muted);
    font-size: var(--text-xs);
    line-height: 1.5;
  }

  .rq-explain code {
    font-family: var(--font-mono);
    color: var(--fg);
  }

  .rq-flow-grid {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: var(--space-2);
    margin-top: var(--space-3);
  }

  .rq-agent-map {
    flex-shrink: 0;
    margin: 0 var(--space-6) var(--space-3);
    padding: var(--space-3);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    background: color-mix(in oklch, var(--bg-inset) 78%, var(--bg) 22%);
  }

  .rq-agent-map--standalone {
    margin-top: var(--space-3);
  }

  .rq-agent-map-head {
    display: flex;
    gap: var(--space-2);
    align-items: flex-start;
    color: var(--fg-muted);
  }

  .rq-agent-map h2 {
    margin: 0;
    color: var(--fg);
    font-size: var(--text-sm);
    font-weight: 600;
  }

  .rq-agent-map p {
    margin: 3px 0 0;
    color: var(--fg-muted);
    font-size: var(--text-xs);
    line-height: 1.5;
  }

  .rq-tool-strip {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-1);
    margin-top: var(--space-3);
  }

  .rq-tool-strip code,
  .rq-agent-paths code {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg);
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 2px 5px;
  }

  .rq-agent-paths {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: var(--space-2);
    margin-top: var(--space-2);
  }

  .rq-agent-paths span {
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 3px;
    padding: var(--space-2);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--bg);
  }

  .rq-agent-paths strong {
    color: var(--fg-subtle);
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .rq-controls {
    flex-shrink: 0;
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: 0 var(--space-6) var(--space-3);
  }

  .rq-control {
    min-width: 220px;
    display: flex;
    align-items: center;
    gap: var(--space-2);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    background: var(--bg-inset);
    color: var(--fg-subtle);
    padding: 0 var(--space-2);
    height: 32px;
  }

  .rq-control input {
    min-width: 0;
    flex: 1;
    border: 0;
    outline: 0;
    background: transparent;
    color: var(--fg);
    font: inherit;
    font-size: var(--text-xs);
  }

  .rq-control--workspace {
    min-width: 160px;
  }

  .rq-control--workspace span {
    color: var(--fg-subtle);
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .rq-control-count {
    margin-left: auto;
    color: var(--fg-subtle);
    font-family: var(--font-mono);
    font-size: 10px;
    white-space: nowrap;
  }

  .rq-flow-grid div {
    min-width: 0;
    padding: var(--space-2);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--bg);
  }

  .rq-flow-grid strong,
  .rq-flow-grid span,
  .rq-flow-grid small {
    display: block;
  }

  .rq-flow-grid strong {
    color: var(--fg);
    font-family: var(--font-mono);
    font-size: var(--text-base);
  }

  .rq-flow-grid span {
    margin-top: 1px;
    color: var(--fg);
    font-size: var(--text-xs);
    font-weight: 600;
  }

  .rq-flow-grid small {
    margin-top: 2px;
    color: var(--fg-subtle);
    font-size: 10px;
    line-height: 1.35;
  }

  /* Tabs */
  .rq-tabs {
    display: flex;
    gap: 2px;
    padding: 0 var(--space-6) 0;
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    overflow-x: auto;
  }

  .rq-tab {
    padding: 6px 12px;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg-muted);
    background: transparent;
    border: none;
    border-bottom: 2px solid transparent;
    cursor: pointer;
    transition: color 0.1s ease, border-color 0.1s ease;
    white-space: nowrap;
    margin-bottom: -1px;
  }

  .rq-tab:hover { color: var(--fg); }

  .rq-tab--active {
    color: var(--fg);
    border-bottom-color: var(--fg);
  }

  /* List */
  .rq-list {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-3) var(--space-6);
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .rq-empty {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    padding: var(--space-6) 0;
    text-align: center;
  }

  .rq-empty--error { color: var(--signal-error); }
  .rq-empty--compact {
    padding: var(--space-2) 0;
    text-align: left;
  }

  /* Row */
  .rq-row {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-3);
    border-radius: var(--radius-md);
    border: 1px solid transparent;
    transition: background 0.1s ease, border-color 0.1s ease;
  }

  .rq-row:hover {
    background: var(--bg-inset);
    border-color: var(--border);
  }

  .rq-row-icon {
    color: var(--fg-muted);
    flex-shrink: 0;
    width: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .rq-row-main {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .rq-row-title-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    min-width: 0;
  }

  .rq-revision-badge {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    padding: 0px 4px;
    border-radius: var(--radius-sm);
    flex-shrink: 0;
  }

  .rq-source-badge {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    padding: 0px 4px;
    border-radius: var(--radius-sm);
    flex-shrink: 0;
  }

  .rq-row-title {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .rq-row-preview {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .rq-row-ids {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    margin-top: 2px;
  }

  .rq-row-ids code {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 0 4px;
  }

  .rq-row-meta {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 2px;
    flex-shrink: 0;
  }

  .rq-meta-agent {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    white-space: nowrap;
  }

  .rq-meta-time {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    white-space: nowrap;
  }

  /* Status pills */
  .rq-status {
    padding: 2px 8px;
    border-radius: 9999px;
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    white-space: nowrap;
    flex-shrink: 0;
  }

  .rq-status--pending { background: color-mix(in oklch, var(--signal-warning) 20%, transparent); color: var(--signal-warning); }
  .rq-status--approved { background: color-mix(in oklch, var(--signal-success) 20%, transparent); color: var(--signal-success); }
  .rq-status--rejected { background: color-mix(in oklch, var(--signal-error) 20%, transparent); color: var(--signal-error); }
  .rq-status--changes { background: color-mix(in oklch, var(--signal-thinking) 20%, transparent); color: var(--signal-thinking); }
  .rq-status--expired { background: var(--bg-inset); color: var(--fg-muted); }

  .rq-review-btn { flex-shrink: 0; }

  @media (max-width: 860px) {
    .rq-metrics,
    .rq-overview-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    .rq-panel--wide { grid-column: span 2; }
    .rq-flow-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    .rq-agent-paths { grid-template-columns: 1fr; }
    .rq-controls { flex-wrap: wrap; }
    .rq-control-count { margin-left: 0; width: 100%; }
  }

  @media (max-width: 560px) {
    .rq-metrics,
    .rq-overview-grid { grid-template-columns: 1fr; }
    .rq-panel--wide { grid-column: span 1; }
    .rq-recent-row { grid-template-columns: 1fr; }
    .rq-flow-grid { grid-template-columns: 1fr; }
  }
</style>
