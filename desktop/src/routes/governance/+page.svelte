<script lang="ts">
/**
 * /governance — Rules, Approvals, and Audit log.
 * Tab state lives in ?tab=rules|approvals|audit (default: rules).
 * CSS prefix: gov- (Governance)
 */
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { ChevronDown, ChevronRight, RefreshCw, Shield } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import { page } from '$app/state';
import {
  approvalsQuery,
  approveApprovalMutation,
  auditQuery,
  createRuleMutation,
  deleteRuleMutation,
  rejectApprovalMutation,
  rulesQuery,
  updateRuleMutation,
} from '$lib/api/queries/governance.js';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import SkeletonList from '$lib/design/patterns/SkeletonList.svelte';
import StatusDot from '$lib/design/patterns/StatusDot.svelte';
import type {
  Approval,
  ApprovalStatus,
  AuditEntry,
  AuditFilters,
  CreateRuleBody,
  Rule,
  RuleAction,
  RuleCondition,
  RuleConditionType,
  UpdateRuleBody,
} from '$lib/domain/governance/types.js';
import { useListKeyboard } from '$lib/utils/useListKeyboard.svelte.js';

const queryClient = useQueryClient();

// ── Tab state (URL-driven) ────────────────────────────────────────────────────

type Tab = 'rules' | 'approvals' | 'audit';

const activeTab = $derived<Tab>(
  (() => {
    const t = page.url.searchParams.get('tab');
    return (t === 'approvals' || t === 'audit' ? t : 'rules') as Tab;
  })()
);

function setTab(tab: Tab) {
  const u = new URL(page.url);
  u.searchParams.set('tab', tab);
  goto(u.toString(), { replaceState: true, noScroll: true });
}

// ── RULES tab ─────────────────────────────────────────────────────────────────

const rulesOptsStore = writable(untrack(() => rulesQuery() as CreateQueryOptions<Rule[]>));
const rulesResult = createQuery<Rule[]>(rulesOptsStore);

const sortedRules = $derived(
  [...($rulesResult.data ?? [])].sort((a, b) => b.priority - a.priority)
);

// Inline edit state — one rule expanded at a time (null = none, 'new' = create form)
let expandedRuleId = $state<string | 'new' | null>(null);

// Draft state for the inline edit/create panel
interface RuleDraft {
  name: string;
  description: string;
  priority: number;
  action: RuleAction;
  enabled: boolean;
  conditions: RuleCondition[];
}

const BLANK_DRAFT: RuleDraft = {
  name: '',
  description: '',
  priority: 10,
  action: 'warn',
  enabled: true,
  conditions: [],
};

let draft = $state<RuleDraft>({ ...BLANK_DRAFT });

function openCreate() {
  draft = { ...BLANK_DRAFT };
  expandedRuleId = 'new';
}

function openEdit(rule: Rule) {
  draft = {
    name: rule.name,
    description: rule.description ?? '',
    priority: rule.priority,
    action: rule.action,
    enabled: rule.enabled,
    conditions: rule.conditions.map((c) => ({ ...c })),
  };
  expandedRuleId = rule.id;
}

function closePanel() {
  expandedRuleId = null;
}

// Condition builder helpers
function addCondition() {
  draft.conditions = [...draft.conditions, { type: 'runtime', value: '' }];
}

function removeCondition(index: number) {
  draft.conditions = draft.conditions.filter((_, i) => i !== index);
}

function updateConditionType(index: number, type: RuleConditionType) {
  draft.conditions = draft.conditions.map((c, i) => (i === index ? { ...c, type } : c));
}

function updateConditionValue(index: number, value: string) {
  draft.conditions = draft.conditions.map((c, i) => (i === index ? { ...c, value } : c));
}

// Mutations
const createRuleOptsStore = writable(
  untrack(() => createRuleMutation() as CreateMutationOptions<Rule, Error, CreateRuleBody>)
);
const createRuleMut = createMutation<Rule, Error, CreateRuleBody>(createRuleOptsStore);

const updateRuleOptsStore = writable(
  untrack(
    () =>
      updateRuleMutation() as CreateMutationOptions<
        Rule,
        Error,
        { id: string; body: UpdateRuleBody }
      >
  )
);
const updateRuleMut = createMutation<Rule, Error, { id: string; body: UpdateRuleBody }>(
  updateRuleOptsStore
);

const deleteRuleOptsStore = writable(
  untrack(() => deleteRuleMutation() as CreateMutationOptions<void, Error, string>)
);
const deleteRuleMut = createMutation<void, Error, string>(deleteRuleOptsStore);

async function saveRule() {
  const body: CreateRuleBody = {
    name: draft.name,
    description: draft.description || undefined,
    enabled: draft.enabled,
    priority: draft.priority,
    action: draft.action,
    conditions: draft.conditions,
  };
  if (expandedRuleId === 'new') {
    await $createRuleMut.mutateAsync(body);
  } else if (expandedRuleId) {
    await $updateRuleMut.mutateAsync({ id: expandedRuleId, body });
  }
  await queryClient.invalidateQueries({ queryKey: ['governance', 'rules'] });
  closePanel();
}

async function deleteRule(id: string) {
  await $deleteRuleMut.mutateAsync(id);
  await queryClient.invalidateQueries({ queryKey: ['governance', 'rules'] });
  if (expandedRuleId === id) closePanel();
}

async function toggleRuleEnabled(rule: Rule) {
  await $updateRuleMut.mutateAsync({ id: rule.id, body: { enabled: !rule.enabled } });
  await queryClient.invalidateQueries({ queryKey: ['governance', 'rules'] });
}

// Keyboard nav for rules list
const rulesKb = useListKeyboard({
  items: () => sortedRules,
  onSelect: (rule) => openEdit(rule),
  onRefresh: () => queryClient.invalidateQueries({ queryKey: ['governance', 'rules'] }),
});

// ── APPROVALS tab ─────────────────────────────────────────────────────────────

let approvalStatusFilter = $state<ApprovalStatus>('pending');

const approvalsOptsStore = writable(
  untrack(() => approvalsQuery(approvalStatusFilter) as CreateQueryOptions<Approval[]>)
);

$effect(() => {
  approvalsOptsStore.set(approvalsQuery(approvalStatusFilter) as CreateQueryOptions<Approval[]>);
});

const approvalsResult = createQuery<Approval[]>(approvalsOptsStore);
const approvals = $derived(($approvalsResult.data ?? []) as Approval[]);

// Inline reason state — keyed by approval id
let pendingDecision = $state<{
  id: string;
  kind: 'approve' | 'reject';
  reason: string;
} | null>(null);

const approveOptsStore = writable(
  untrack(
    () =>
      approveApprovalMutation() as CreateMutationOptions<
        Approval,
        Error,
        { id: string; body?: { reason?: string; decided_by?: string } }
      >
  )
);
const approveMut = createMutation<
  Approval,
  Error,
  { id: string; body?: { reason?: string; decided_by?: string } }
>(approveOptsStore);

const rejectOptsStore = writable(
  untrack(
    () =>
      rejectApprovalMutation() as CreateMutationOptions<
        Approval,
        Error,
        { id: string; body?: { reason?: string; decided_by?: string } }
      >
  )
);
const rejectMut = createMutation<
  Approval,
  Error,
  { id: string; body?: { reason?: string; decided_by?: string } }
>(rejectOptsStore);

async function confirmDecision() {
  if (!pendingDecision) return;
  const { id, kind, reason } = pendingDecision;
  const body = reason ? { reason } : {};
  if (kind === 'approve') {
    await $approveMut.mutateAsync({ id, body });
  } else {
    await $rejectMut.mutateAsync({ id, body });
  }
  await queryClient.invalidateQueries({ queryKey: ['governance', 'approvals'] });
  pendingDecision = null;
}

// ── AUDIT tab ────────────────────────────────────────────────────────────────

type DateRange = '24h' | '7d' | '30d' | 'custom';

let auditEventType = $state('');
let auditSessionId = $state('');
let auditDateRange = $state<DateRange>('24h');
let auditCustomAfter = $state('');
let auditCustomBefore = $state('');
let auditPage = $state(0); // cursor-based via before= param
let expandedAuditId = $state<string | null>(null);

const AUDIT_PAGE_SIZE = 50;

function dateRangeToAfter(range: DateRange): string | undefined {
  if (range === 'custom') return auditCustomAfter || undefined;
  const now = Date.now();
  const ms = { '24h': 86_400_000, '7d': 604_800_000, '30d': 2_592_000_000 }[range];
  return new Date(now - ms).toISOString();
}

const auditFilters = $derived<AuditFilters>({
  event_type: auditEventType || undefined,
  session_id: auditSessionId || undefined,
  after: dateRangeToAfter(auditDateRange),
  before: auditDateRange === 'custom' ? auditCustomBefore || undefined : undefined,
});

const auditOptsStore = writable(
  untrack(() => auditQuery(auditFilters) as CreateQueryOptions<AuditEntry[]>)
);

$effect(() => {
  auditOptsStore.set(auditQuery(auditFilters) as CreateQueryOptions<AuditEntry[]>);
});

const auditResult = createQuery<AuditEntry[]>(auditOptsStore);
const auditEntries = $derived(($auditResult.data ?? []) as AuditEntry[]);
// Paginate client-side: show first (page+1)*AUDIT_PAGE_SIZE entries
const visibleAudit = $derived(auditEntries.slice(0, (auditPage + 1) * AUDIT_PAGE_SIZE));
const hasMoreAudit = $derived(visibleAudit.length < auditEntries.length);

// ── Shared helpers ────────────────────────────────────────────────────────────

function actionColor(action: RuleAction): string {
  switch (action) {
    case 'block':
      return 'var(--signal-error)';
    case 'require_approval':
    case 'warn':
      return 'var(--signal-warn)';
    case 'log':
      return 'var(--fg-muted)';
  }
}

function formatRelative(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  if (diff < 60_000) return 'just now';
  if (diff < 3_600_000) return `${Math.floor(diff / 60_000)}m ago`;
  if (diff < 86_400_000) return `${Math.floor(diff / 3_600_000)}h ago`;
  return `${Math.floor(diff / 86_400_000)}d ago`;
}

const CONDITION_TYPES: { value: RuleConditionType; label: string }[] = [
  { value: 'runtime', label: 'Runtime' },
  { value: 'agent_slug', label: 'Agent slug' },
  { value: 'workspace_slug', label: 'Workspace slug' },
  { value: 'prompt_regex', label: 'Prompt regex' },
  { value: 'cost_over', label: 'Cost over ($)' },
];

const ACTION_OPTIONS: { value: RuleAction; label: string }[] = [
  { value: 'block', label: 'Block' },
  { value: 'require_approval', label: 'Require approval' },
  { value: 'warn', label: 'Warn' },
  { value: 'log', label: 'Log only' },
];
</script>

<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
<div class="gov-page" role="region" aria-label="Governance">
  <!-- Header -->
  <header class="gov-header">
    <h1 class="gov-title">Governance</h1>
    {#if activeTab === 'rules'}
      <button class="btn-pill btn-pill-primary btn-pill-sm" onclick={openCreate}>
        + New Rule
      </button>
    {/if}
  </header>

  <!-- Tab bar -->
  <nav class="gov-tabs" aria-label="Governance sections">
    {#each (['rules', 'approvals', 'audit'] as const) as tab}
      <button
        class="gov-tab"
        class:gov-tab--active={activeTab === tab}
        onclick={() => setTab(tab)}
        aria-current={activeTab === tab ? 'page' : undefined}
      >
        {tab.charAt(0).toUpperCase() + tab.slice(1)}
        {#if tab === 'approvals' && ($approvalsResult.data ?? []).filter((a) => a.status === 'pending').length > 0}
          <span class="gov-tab-badge">
            {($approvalsResult.data ?? []).filter((a) => a.status === 'pending').length}
          </span>
        {/if}
      </button>
    {/each}
  </nav>

  <!-- ── RULES TAB ─────────────────────────────────────────────────────────── -->

  {#if activeTab === 'rules'}
    <div
      class="gov-section"
      role="list"
      aria-label="Governance rules"
      onkeydown={rulesKb.handleKeydown}
    >
      {#if $rulesResult.isError}
        <EmptyState
          title="Couldn't load rules"
          body={($rulesResult.error as Error).message || 'Check your connection.'}
          action="Retry"
          onAction={() => $rulesResult.refetch()}
        />
      {:else if $rulesResult.isLoading}
        <SkeletonList count={5} height="2.75rem" gap="0.25rem" />
      {:else if sortedRules.length === 0 && expandedRuleId !== 'new'}
        <EmptyState
          title="No governance rules yet."
          body="Rules control which sessions require approval, warn, or block."
          action="+ New Rule"
          onAction={openCreate}
        />
      {:else}
        {#each sortedRules as rule, i (rule.id)}
          <div class="gov-rule-row" role="listitem">
            <!-- Row summary wrapper — flex row with summary button + actions side by side -->
            <div
              class="gov-rule-summary-wrap"
              class:gov-row--selected={rulesKb.selectedIndex === i}
              class:gov-rule-summary-wrap--expanded={expandedRuleId === rule.id}
            >
              <button
                class="gov-rule-summary"
                onclick={() => (expandedRuleId === rule.id ? closePanel() : openEdit(rule))}
                aria-expanded={expandedRuleId === rule.id}
                aria-label="Edit rule {rule.name}"
              >
                <span class="gov-priority-badge">{rule.priority}</span>
                <StatusDot color={rule.enabled ? 'green' : 'grey'} />
                <span class="gov-rule-name">{rule.name}</span>
                <span class="gov-action-badge" style="color: {actionColor(rule.action)};">
                  {rule.action.replace('_', ' ')}
                </span>
                <span class="gov-rule-meta">
                  {rule.conditions.length} condition{rule.conditions.length !== 1 ? 's' : ''}
                </span>
                <span class="gov-rule-meta gov-rule-date">{formatRelative(rule.updatedAt)}</span>
                <span class="gov-rule-chevron" aria-hidden="true">
                  {#if expandedRuleId === rule.id}
                    <ChevronDown size={14} />
                  {:else}
                    <ChevronRight size={14} />
                  {/if}
                </span>
              </button>
              <!-- Row actions — outside the summary button to avoid nested interactive elements -->
              <span class="gov-row-actions" role="group" aria-label="Rule actions">
                <button
                  class="btn-compact btn-compact-ghost"
                  onclick={() => toggleRuleEnabled(rule)}
                  aria-label="{rule.enabled ? 'Disable' : 'Enable'} rule"
                  title="{rule.enabled ? 'Disable' : 'Enable'}"
                >
                  {rule.enabled ? 'Disable' : 'Enable'}
                </button>
                <button
                  class="btn-compact btn-compact-ghost"
                  onclick={() => deleteRule(rule.id)}
                  aria-label="Delete rule {rule.name}"
                  title="Delete"
                >
                  Delete
                </button>
              </span>
            </div>

            <!-- Inline edit panel -->
            {#if expandedRuleId === rule.id}
              <div class="gov-edit-panel" role="form" aria-label="Edit rule">
                {@render editForm()}
              </div>
            {/if}
          </div>
        {/each}

        <!-- New rule create panel (appended below list) -->
        {#if expandedRuleId === 'new'}
          <div class="gov-rule-row" role="listitem">
            <div class="gov-edit-panel gov-edit-panel--new" role="form" aria-label="New rule">
              {@render editForm()}
            </div>
          </div>
        {/if}
      {/if}

      <!-- New rule create panel when list is empty -->
      {#if sortedRules.length === 0 && expandedRuleId === 'new'}
        <div class="gov-rule-row" role="listitem">
          <div class="gov-edit-panel gov-edit-panel--new" role="form" aria-label="New rule">
            {@render editForm()}
          </div>
        </div>
      {/if}
    </div>
  {/if}

  <!-- ── APPROVALS TAB ──────────────────────────────────────────────────────── -->

  {#if activeTab === 'approvals'}
    <div class="gov-section">
      <!-- Status filter pills -->
      <div class="gov-filter-pills" role="group" aria-label="Filter by status">
        {#each (['pending', 'approved', 'rejected'] as const) as status}
          <button
            class="gov-filter-pill"
            class:gov-filter-pill--active={approvalStatusFilter === status}
            onclick={() => {
              approvalStatusFilter = status;
            }}
            aria-pressed={approvalStatusFilter === status}
          >
            {status.charAt(0).toUpperCase() + status.slice(1)}
          </button>
        {/each}
        <button
          class="btn-compact btn-compact-ghost gov-refresh"
          onclick={() => queryClient.invalidateQueries({ queryKey: ['governance', 'approvals'] })}
          aria-label="Refresh approvals"
          title="Refresh"
        >
          <RefreshCw size={12} aria-hidden="true" />
        </button>
      </div>

      {#if $approvalsResult.isError}
        <EmptyState
          title="Couldn't load approvals"
          body={($approvalsResult.error as Error).message || 'Check your connection.'}
          action="Retry"
          onAction={() => $approvalsResult.refetch()}
        />
      {:else if $approvalsResult.isLoading}
        <SkeletonList count={4} height="3rem" gap="0.25rem" />
      {:else if approvals.length === 0}
        <EmptyState
          title="No {approvalStatusFilter} approvals."
          body={approvalStatusFilter === 'pending' ? 'No pending approvals.' : undefined}
        />
      {:else}
        <div class="gov-approval-list" role="list">
          {#each approvals as approval (approval.id)}
            <div class="gov-approval-row" role="listitem">
              <div class="gov-approval-main">
                <span class="gov-action-badge" style="color: {actionColor('require_approval')};">
                  {approval.ruleName}
                </span>
                <a
                  class="gov-session-link"
                  href="/sessions/{approval.sessionId}"
                  aria-label="Open session {approval.sessionId}"
                >
                  {approval.sessionId.slice(0, 8)}…
                </a>
                <span class="gov-rule-meta">{formatRelative(approval.requestedAt)}</span>
                {#if approval.decidedAt}
                  <span class="gov-rule-meta">decided {formatRelative(approval.decidedAt)}</span>
                {/if}
                {#if approval.decidedBy}
                  <span class="gov-rule-meta gov-decided-by">{approval.decidedBy}</span>
                {/if}
                {#if approval.decisionReason}
                  <span class="gov-decision-reason">{approval.decisionReason}</span>
                {/if}

                {#if approval.status === 'pending' && pendingDecision?.id !== approval.id}
                  <span class="gov-approval-actions" role="group">
                    <button
                      class="btn-pill btn-pill-success btn-pill-xs"
                      onclick={() => {
                        pendingDecision = { id: approval.id, kind: 'approve', reason: '' };
                      }}
                      aria-label="Approve {approval.ruleName}"
                    >
                      Approve
                    </button>
                    <button
                      class="btn-pill btn-pill-outline btn-pill-xs gov-reject-btn"
                      onclick={() => {
                        pendingDecision = { id: approval.id, kind: 'reject', reason: '' };
                      }}
                      aria-label="Reject {approval.ruleName}"
                    >
                      Reject
                    </button>
                  </span>
                {/if}
              </div>

              <!-- Inline reason textarea -->
              {#if pendingDecision?.id === approval.id}
                <div class="gov-reason-panel">
                  <textarea
                    class="gov-reason-input"
                    placeholder="Reason (optional)"
                    bind:value={pendingDecision.reason}
                    rows={2}
                    aria-label="Decision reason"
                  ></textarea>
                  <div class="gov-reason-actions">
                    <button
                      class="btn-pill btn-pill-primary btn-pill-xs"
                      onclick={confirmDecision}
                      disabled={$approveMut.isPending || $rejectMut.isPending}
                    >
                      Confirm {pendingDecision.kind}
                    </button>
                    <button
                      class="btn-compact btn-compact-ghost"
                      onclick={() => {
                        pendingDecision = null;
                      }}
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              {/if}
            </div>
          {/each}
        </div>
      {/if}
    </div>
  {/if}

  <!-- ── AUDIT TAB ───────────────────────────────────────────────────────────── -->

  {#if activeTab === 'audit'}
    <div class="gov-section">
      <!-- Filter row -->
      <div class="gov-audit-filters" role="search" aria-label="Filter audit log">
        <select
          class="gov-select"
          bind:value={auditEventType}
          aria-label="Filter by event type"
        >
          <option value="">All event types</option>
          <option value="rule_triggered">rule_triggered</option>
          <option value="rule_created">rule_created</option>
          <option value="rule_updated">rule_updated</option>
          <option value="rule_deleted">rule_deleted</option>
          <option value="approval_requested">approval_requested</option>
          <option value="approval_approved">approval_approved</option>
          <option value="approval_rejected">approval_rejected</option>
          <option value="session_blocked">session_blocked</option>
        </select>

        <input
          class="gov-input"
          type="text"
          placeholder="Session ID"
          bind:value={auditSessionId}
          aria-label="Filter by session ID"
        />

        <div class="gov-date-pills" role="group" aria-label="Date range">
          {#each (['24h', '7d', '30d', 'custom'] as const) as range}
            <button
              class="gov-filter-pill"
              class:gov-filter-pill--active={auditDateRange === range}
              onclick={() => {
                auditDateRange = range;
              }}
              aria-pressed={auditDateRange === range}
            >
              {range}
            </button>
          {/each}
        </div>

        {#if auditDateRange === 'custom'}
          <input
            class="gov-input gov-input-date"
            type="datetime-local"
            bind:value={auditCustomAfter}
            aria-label="After date"
          />
          <input
            class="gov-input gov-input-date"
            type="datetime-local"
            bind:value={auditCustomBefore}
            aria-label="Before date"
          />
        {/if}

        <button
          class="btn-compact btn-compact-ghost gov-refresh"
          onclick={() => queryClient.invalidateQueries({ queryKey: ['governance', 'audit'] })}
          aria-label="Refresh audit log"
          title="Refresh"
        >
          <RefreshCw size={12} aria-hidden="true" />
        </button>
      </div>

      {#if $auditResult.isError}
        <EmptyState
          title="Couldn't load audit log"
          body={($auditResult.error as Error).message || 'Check your connection.'}
          action="Retry"
          onAction={() => $auditResult.refetch()}
        />
      {:else if $auditResult.isLoading}
        <SkeletonList count={8} height="2.25rem" gap="0.125rem" />
      {:else if auditEntries.length === 0}
        <EmptyState title="No audit entries match the filter." />
      {:else}
        <div class="gov-audit-list" role="list">
          {#each visibleAudit as entry (entry.id)}
            <div class="gov-audit-entry" role="listitem">
              <button
                class="gov-audit-row"
                onclick={() => {
                  expandedAuditId = expandedAuditId === entry.id ? null : entry.id;
                }}
                aria-expanded={expandedAuditId === entry.id}
                aria-label="Toggle audit entry {entry.eventType}"
              >
                <span class="gov-audit-ts">{new Date(entry.occurredAt).toISOString().replace('T', ' ').slice(0, 19)}</span>
                <span class="gov-audit-type-badge">{entry.eventType}</span>
                {#if entry.sessionId}
                  <span class="gov-audit-actor">{entry.sessionId.slice(0, 8)}</span>
                {/if}
                {#if entry.ruleId}
                  <span class="gov-rule-meta">rule:{entry.ruleId.slice(0, 8)}</span>
                {/if}
                <span class="gov-audit-chevron" aria-hidden="true">
                  {#if expandedAuditId === entry.id}
                    <ChevronDown size={12} />
                  {:else}
                    <ChevronRight size={12} />
                  {/if}
                </span>
              </button>
              {#if expandedAuditId === entry.id}
                <pre class="gov-audit-payload">{JSON.stringify(entry.payload, null, 2)}</pre>
              {/if}
            </div>
          {/each}
        </div>

        {#if hasMoreAudit}
          <button
            class="btn-pill btn-pill-ghost btn-pill-sm gov-load-more"
            onclick={() => {
              auditPage += 1;
            }}
          >
            Load more
          </button>
        {/if}
      {/if}
    </div>
  {/if}
</div>

<!-- ── Edit/Create form snippet ─────────────────────────────────────────────── -->

{#snippet editForm()}
  <div class="gov-form-grid">
    <div class="gov-form-row">
      <label class="gov-label" for="gov-rule-name">Name</label>
      <input
        id="gov-rule-name"
        class="gov-input"
        type="text"
        bind:value={draft.name}
        placeholder="Rule name"
        required
      />
    </div>

    <div class="gov-form-row">
      <label class="gov-label" for="gov-rule-description">Description</label>
      <textarea
        id="gov-rule-description"
        class="gov-textarea"
        bind:value={draft.description}
        placeholder="Optional description"
        rows={2}
      ></textarea>
    </div>

    <div class="gov-form-row gov-form-row--half">
      <div>
        <label class="gov-label" for="gov-rule-priority">Priority</label>
        <input
          id="gov-rule-priority"
          class="gov-input gov-input-num"
          type="number"
          bind:value={draft.priority}
          min={0}
          max={9999}
        />
      </div>
      <div>
        <label class="gov-label" for="gov-rule-action">Action</label>
        <select id="gov-rule-action" class="gov-select" bind:value={draft.action}>
          {#each ACTION_OPTIONS as opt}
            <option value={opt.value}>{opt.label}</option>
          {/each}
        </select>
      </div>
      <div class="gov-toggle-row">
        <label class="gov-label" for="gov-rule-enabled">Enabled</label>
        <input
          id="gov-rule-enabled"
          type="checkbox"
          class="gov-checkbox"
          bind:checked={draft.enabled}
        />
      </div>
    </div>

    <!-- Conditions -->
    <div class="gov-conditions-section">
      <div class="gov-conditions-header">
        <span class="gov-label">Conditions</span>
        <button
          class="btn-compact btn-compact-secondary"
          type="button"
          onclick={addCondition}
        >
          + Add
        </button>
      </div>
      {#each draft.conditions as condition, i (i)}
        <div class="gov-condition-row">
          <select
            class="gov-select gov-select-sm"
            value={condition.type}
            onchange={(e) => updateConditionType(i, (e.target as HTMLSelectElement).value as RuleConditionType)}
            aria-label="Condition type {i + 1}"
          >
            {#each CONDITION_TYPES as ct}
              <option value={ct.value}>{ct.label}</option>
            {/each}
          </select>
          <input
            class="gov-input gov-input-condition"
            type="text"
            value={condition.value}
            oninput={(e) => updateConditionValue(i, (e.target as HTMLInputElement).value)}
            placeholder={condition.type === 'cost_over' ? '5.00' : 'value'}
            aria-label="Condition value {i + 1}"
          />
          <button
            class="btn-compact btn-compact-ghost"
            type="button"
            onclick={() => removeCondition(i)}
            aria-label="Remove condition {i + 1}"
          >
            ✕
          </button>
        </div>
      {/each}
      {#if draft.conditions.length === 0}
        <p class="gov-conditions-empty">No conditions — rule applies to all sessions.</p>
      {/if}
    </div>

    <!-- Panel footer -->
    <div class="gov-form-footer">
      <button
        class="btn-pill btn-pill-primary btn-pill-sm"
        type="button"
        onclick={saveRule}
        disabled={!draft.name || $createRuleMut.isPending || $updateRuleMut.isPending}
      >
        {$createRuleMut.isPending || $updateRuleMut.isPending ? 'Saving…' : 'Save'}
      </button>
      <button
        class="btn-compact btn-compact-ghost"
        type="button"
        onclick={closePanel}
      >
        Cancel
      </button>
    </div>
  </div>
{/snippet}

<style>
  /* ── Page shell ───────────────────────────────────────────────────────────── */

  .gov-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-6);
    overflow-y: auto;
    height: 100%;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
    outline: none;
  }

  .gov-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: var(--space-3);
  }

  .gov-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    letter-spacing: var(--tracking-2xl);
    line-height: var(--lh-2xl);
  }

  /* ── Tab bar ──────────────────────────────────────────────────────────────── */

  .gov-tabs {
    display: flex;
    gap: 0;
    border-bottom: 1px solid var(--border);
  }

  .gov-tab {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
    padding: var(--space-2) var(--space-4);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg-muted);
    background: none;
    border: none;
    border-bottom: 2px solid transparent;
    cursor: pointer;
    transition:
      color var(--dur-fast) var(--ease-out),
      border-color var(--dur-fast) var(--ease-out);
    margin-bottom: -1px;
  }

  .gov-tab:hover:not(.gov-tab--active) {
    color: var(--fg);
  }

  .gov-tab--active {
    color: var(--fg);
    border-bottom-color: var(--fg);
  }

  .gov-tab-badge {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 18px;
    height: 16px;
    padding: 0 4px;
    font-size: 10px;
    font-weight: 600;
    font-family: var(--font-mono);
    background: color-mix(in oklch, var(--signal-warn) 15%, transparent);
    color: var(--signal-warn);
    border-radius: 9999px;
  }

  /* ── Section container ────────────────────────────────────────────────────── */

  .gov-section {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
    outline: none;
  }

  /* ── Rules list ───────────────────────────────────────────────────────────── */

  .gov-rule-row {
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    overflow: hidden;
    transition: border-color var(--dur-fast) var(--ease-out);
  }

  .gov-rule-row + .gov-rule-row {
    margin-top: var(--space-1);
  }

  .gov-rule-summary-wrap {
    display: flex;
    align-items: center;
    background: var(--bg-elevated);
    transition: background var(--dur-fast) var(--ease-out);
  }

  .gov-rule-summary-wrap:hover,
  .gov-rule-summary-wrap--expanded {
    background: color-mix(in oklch, var(--fg) 4%, var(--bg-elevated));
  }

  .gov-row--selected {
    background: color-mix(in oklch, var(--fg) 6%, var(--bg-elevated)) !important;
  }

  .gov-rule-summary {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    flex: 1;
    min-width: 0;
    padding: var(--space-2) var(--space-3);
    background: transparent;
    border: none;
    cursor: pointer;
    text-align: left;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
  }

  .gov-priority-badge {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    font-variant-numeric: tabular-nums;
    min-width: 28px;
    text-align: right;
    color: var(--fg-muted);
    flex-shrink: 0;
  }

  .gov-rule-name {
    font-weight: 500;
    color: var(--fg);
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .gov-action-badge {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    flex-shrink: 0;
  }

  .gov-rule-meta {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    flex-shrink: 0;
  }

  .gov-rule-date {
    font-variant-numeric: tabular-nums;
  }

  .gov-row-actions {
    display: flex;
    gap: var(--space-1);
    flex-shrink: 0;
  }

  .gov-rule-chevron {
    color: var(--fg-subtle);
    flex-shrink: 0;
    display: flex;
    align-items: center;
  }

  /* ── Edit panel ───────────────────────────────────────────────────────────── */

  .gov-edit-panel {
    padding: var(--space-4);
    border-top: 1px solid var(--border);
    background: var(--bg-inset);
    animation: fade-in-up var(--dur-fast) var(--ease-out) both;
  }

  .gov-edit-panel--new {
    border-top: none;
    border-radius: var(--radius-md);
    border: 1px solid var(--border);
  }

  .gov-form-grid {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .gov-form-row {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .gov-form-row--half {
    flex-direction: row;
    gap: var(--space-3);
    align-items: flex-end;
    flex-wrap: wrap;
  }

  .gov-form-row--half > * {
    flex: 1;
    min-width: 100px;
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .gov-toggle-row {
    flex-direction: row !important;
    align-items: center;
    gap: var(--space-2);
  }

  .gov-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .gov-input {
    height: 28px;
    padding: 0 var(--space-2);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    background: var(--bg-elevated);
    border: 1px solid var(--input-border);
    border-radius: var(--radius-sm);
    outline: none;
    transition: border-color var(--dur-fast) var(--ease-out);
    width: 100%;
    box-sizing: border-box;
  }

  .gov-input:focus-visible {
    border-color: var(--ring);
    outline: 2px solid color-mix(in oklch, var(--ring) 40%, transparent);
    outline-offset: 1px;
  }

  .gov-input-num {
    width: 80px;
    font-family: var(--font-mono);
    font-variant-numeric: tabular-nums;
  }

  .gov-input-condition {
    flex: 1;
  }

  .gov-input-date {
    height: 28px;
    font-size: var(--text-xs);
  }

  .gov-textarea {
    padding: var(--space-2);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    background: var(--bg-elevated);
    border: 1px solid var(--input-border);
    border-radius: var(--radius-sm);
    outline: none;
    resize: vertical;
    width: 100%;
    box-sizing: border-box;
    transition: border-color var(--dur-fast) var(--ease-out);
  }

  .gov-textarea:focus-visible {
    border-color: var(--ring);
  }

  .gov-select {
    height: 28px;
    padding: 0 var(--space-2);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    background: var(--bg-elevated);
    border: 1px solid var(--input-border);
    border-radius: var(--radius-sm);
    outline: none;
    cursor: pointer;
    width: 100%;
    box-sizing: border-box;
  }

  .gov-select:focus-visible {
    border-color: var(--ring);
  }

  .gov-select-sm {
    width: 140px;
    flex-shrink: 0;
  }

  .gov-checkbox {
    width: 16px;
    height: 16px;
    cursor: pointer;
    accent-color: var(--primary);
  }

  /* ── Conditions ───────────────────────────────────────────────────────────── */

  .gov-conditions-section {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .gov-conditions-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .gov-condition-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .gov-conditions-empty {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    margin: 0;
    padding: var(--space-1) 0;
  }

  /* ── Form footer ──────────────────────────────────────────────────────────── */

  .gov-form-footer {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding-top: var(--space-2);
    border-top: 1px solid var(--border);
  }

  /* ── Approvals ────────────────────────────────────────────────────────────── */

  .gov-filter-pills {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    flex-wrap: wrap;
    margin-bottom: var(--space-2);
  }

  .gov-filter-pill {
    display: inline-flex;
    align-items: center;
    height: 26px;
    padding: 0 var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 9999px;
    cursor: pointer;
    transition:
      background var(--dur-fast) var(--ease-out),
      color var(--dur-fast) var(--ease-out),
      border-color var(--dur-fast) var(--ease-out);
  }

  .gov-filter-pill:hover {
    color: var(--fg);
    border-color: var(--border-strong);
  }

  .gov-filter-pill--active {
    background: var(--primary);
    color: var(--primary-fg);
    border-color: var(--primary);
  }

  .gov-refresh {
    margin-left: var(--space-1);
    display: flex;
    align-items: center;
    justify-content: center;
    width: 26px;
    height: 26px;
  }

  .gov-approval-list {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .gov-approval-row {
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    background: var(--bg-elevated);
    overflow: hidden;
  }

  .gov-approval-main {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-2) var(--space-3);
    flex-wrap: wrap;
  }

  .gov-session-link {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    text-decoration: none;
    border-bottom: 1px solid transparent;
    transition: border-color var(--dur-fast) var(--ease-out);
  }

  .gov-session-link:hover {
    color: var(--fg);
    border-bottom-color: var(--border-strong);
  }

  .gov-decided-by {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
  }

  .gov-decision-reason {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    font-style: italic;
  }

  .gov-approval-actions {
    display: flex;
    gap: var(--space-1);
    margin-left: auto;
  }

  .gov-reject-btn {
    border-color: var(--signal-error) !important;
    color: var(--signal-error) !important;
  }

  .gov-reject-btn:hover {
    background: color-mix(in oklch, var(--signal-error) 10%, transparent) !important;
  }

  /* ── Reason panel ─────────────────────────────────────────────────────────── */

  .gov-reason-panel {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-3);
    border-top: 1px solid var(--border);
    background: var(--bg-inset);
    animation: fade-in-up var(--dur-fast) var(--ease-out) both;
  }

  .gov-reason-input {
    padding: var(--space-2);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    background: var(--bg-elevated);
    border: 1px solid var(--input-border);
    border-radius: var(--radius-sm);
    outline: none;
    resize: vertical;
    width: 100%;
    box-sizing: border-box;
  }

  .gov-reason-input:focus-visible {
    border-color: var(--ring);
  }

  .gov-reason-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  /* ── Audit ────────────────────────────────────────────────────────────────── */

  .gov-audit-filters {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-wrap: wrap;
    margin-bottom: var(--space-2);
  }

  .gov-date-pills {
    display: flex;
    gap: var(--space-1);
  }

  .gov-audit-list {
    display: flex;
    flex-direction: column;
    gap: 1px;
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    overflow: hidden;
  }

  .gov-audit-entry {
    background: var(--bg-elevated);
  }

  .gov-audit-entry + .gov-audit-entry {
    border-top: 1px solid var(--border);
  }

  .gov-audit-row {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    width: 100%;
    padding: var(--space-1) var(--space-3);
    background: none;
    border: none;
    cursor: pointer;
    text-align: left;
    transition: background var(--dur-fast) var(--ease-out);
  }

  .gov-audit-row:hover {
    background: color-mix(in oklch, var(--fg) 3%, transparent);
  }

  .gov-audit-ts {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    font-variant-numeric: tabular-nums;
    color: var(--fg-muted);
    flex-shrink: 0;
  }

  .gov-audit-type-badge {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg);
    font-weight: 500;
    flex-shrink: 0;
  }

  .gov-audit-actor {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    flex-shrink: 0;
  }

  .gov-audit-chevron {
    margin-left: auto;
    color: var(--fg-subtle);
    display: flex;
    align-items: center;
    flex-shrink: 0;
  }

  .gov-audit-payload {
    margin: 0;
    padding: var(--space-3);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    background: var(--bg-inset);
    border-top: 1px solid var(--border);
    overflow-x: auto;
    white-space: pre-wrap;
    word-break: break-all;
  }

  .gov-load-more {
    align-self: center;
    margin-top: var(--space-3);
  }

  /* ── Reduced motion ───────────────────────────────────────────────────────── */

  @media (prefers-reduced-motion: reduce) {
    .gov-edit-panel,
    .gov-reason-panel {
      animation: none;
    }
  }
</style>
