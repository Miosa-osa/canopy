<script lang="ts">
/**
 * Settings › Budgets — list + create/edit inline + delete.
 * Uses budgetsQuery, createBudgetMutation, updateBudgetMutation, deleteBudgetMutation.
 */

import { createMutation, createQuery, useQueryClient } from '@tanstack/svelte-query';
import {
  type Budget,
  type BudgetPeriod,
  type BudgetScopeType,
  type CreateBudgetBody,
  type UpdateBudgetBody,
  budgetsQuery,
  createBudgetMutation,
  deleteBudgetMutation,
  updateBudgetMutation,
} from '$lib/api/queries/budgets.js';
import { agentsQuery } from '$lib/api/queries/agents.js';
import { workspacesQuery } from '$lib/api/queries/workspaces.js';

const qc = useQueryClient();

const listResult = createQuery(budgetsQuery());
const agentsResult = createQuery(agentsQuery());
const workspacesResult = createQuery(workspacesQuery());

// ── Form state ────────────────────────────────────────────────────────────────

/** null = creating new; string = editing existing id */
let editingId = $state<string | null>(null);
let showForm = $state(false);

let formName = $state('');
let formScopeType = $state<BudgetScopeType>('global');
let formScopeId = $state('');
let formPeriod = $state<BudgetPeriod>('monthly');
let formLimitUsd = $state('');
let formSoftAlertPct = $state('80');
let formHardCeiling = $state(false);
let formEnabled = $state(true);
let formError = $state('');

function openCreate(): void {
  editingId = null;
  formName = '';
  formScopeType = 'global';
  formScopeId = '';
  formPeriod = 'monthly';
  formLimitUsd = '';
  formSoftAlertPct = '80';
  formHardCeiling = false;
  formEnabled = true;
  formError = '';
  showForm = true;
}

function openEdit(budget: Budget): void {
  editingId = budget.id;
  formName = budget.name;
  formScopeType = budget.scope_type;
  formScopeId = budget.scope_id ?? '';
  formPeriod = budget.period;
  formLimitUsd = String(budget.limit_usd);
  formSoftAlertPct = String(budget.soft_alert_pct);
  formHardCeiling = budget.hard_ceiling;
  formEnabled = budget.enabled;
  formError = '';
  showForm = true;
}

function closeForm(): void {
  showForm = false;
  editingId = null;
  formError = '';
}

function invalidateList(): void {
  void qc.invalidateQueries({ queryKey: ['budgets'] });
}

const createMut = createMutation({
  ...createBudgetMutation(),
  onSuccess: () => {
    invalidateList();
    closeForm();
  },
  onError: (err) => {
    formError = String(err);
  },
});

// We use a reactive mutation that updates when editingId changes.
const updateMut = createMutation({
  mutationKey: ['budgets', 'update-active'] as const,
  mutationFn: (body: UpdateBudgetBody) => {
    if (!editingId) throw new Error('No budget selected');
    return import('$lib/api/queries/budgets.js').then((m) => m.updateBudget(editingId!, body));
  },
  onSuccess: () => {
    invalidateList();
    closeForm();
  },
  onError: (err) => {
    formError = String(err);
  },
});

// Track which id is pending delete
let deletingId = $state<string | null>(null);
const deleteMut = createMutation({
  mutationKey: ['budgets', 'delete-active'] as const,
  mutationFn: () => {
    if (!deletingId) throw new Error('No budget selected');
    return import('$lib/api/queries/budgets.js').then((m) => m.deleteBudget(deletingId!));
  },
  onSuccess: () => {
    invalidateList();
    deletingId = null;
  },
});

// Toggle enabled inline
const toggleMut = createMutation({
  mutationKey: ['budgets', 'toggle'] as const,
  mutationFn: ({ id, enabled }: { id: string; enabled: boolean }) =>
    import('$lib/api/queries/budgets.js').then((m) => m.updateBudget(id, { enabled })),
  onSuccess: () => invalidateList(),
});

function handleSubmit(): void {
  formError = '';
  const limitVal = parseFloat(formLimitUsd);
  if (!formName.trim()) { formError = 'Name is required.'; return; }
  if (isNaN(limitVal) || limitVal <= 0) { formError = 'Limit must be a positive number.'; return; }
  if (formScopeType !== 'global' && !formScopeId) {
    formError = `Select a ${formScopeType} for the scope.`;
    return;
  }

  const body: CreateBudgetBody = {
    name: formName.trim(),
    scope_type: formScopeType,
    scope_id: formScopeType === 'global' ? null : formScopeId,
    period: formPeriod,
    limit_usd: limitVal,
    soft_alert_pct: parseInt(formSoftAlertPct, 10) || 80,
    hard_ceiling: formHardCeiling,
    enabled: formEnabled,
  };

  if (editingId) {
    $updateMut.mutate(body);
  } else {
    $createMut.mutate(body);
  }
}

function spendPct(b: Budget): number {
  if (b.limit_usd === 0) return 0;
  return Math.min(100, (b.spent_this_period / b.limit_usd) * 100);
}

const SCOPE_LABELS: Record<BudgetScopeType, string> = {
  global: 'Global',
  agent: 'Agent',
  workspace: 'Workspace',
};
</script>

<div class="bg-page">
  <!-- Header row -->
  <div class="bg-header-row">
    <p class="bg-desc">Set spending limits per scope. Hard ceilings block sessions when exceeded.</p>
    <button class="bg-pill-btn bg-pill-btn--primary" onclick={openCreate}>
      + New Budget
    </button>
  </div>

  <!-- Inline form -->
  {#if showForm}
    <div class="bg-form-card" aria-label="{editingId ? 'Edit' : 'Create'} budget">
      <p class="bg-form-title">{editingId ? 'Edit budget' : 'New budget'}</p>

      <div class="bg-form-grid">
        <!-- Name -->
        <div class="bg-field">
          <label class="bg-field-label" for="bg-name">Name</label>
          <input id="bg-name" class="bg-input" type="text" placeholder="e.g. Monthly global cap" bind:value={formName} />
        </div>

        <!-- Scope type -->
        <div class="bg-field">
          <label class="bg-field-label" for="bg-scope-type">Scope</label>
          <select id="bg-scope-type" class="bg-input" bind:value={formScopeType}>
            <option value="global">Global</option>
            <option value="agent">Agent</option>
            <option value="workspace">Workspace</option>
          </select>
        </div>

        <!-- Scope ID (conditional) -->
        {#if formScopeType === 'agent'}
          <div class="bg-field">
            <label class="bg-field-label" for="bg-scope-id">Agent</label>
            <select id="bg-scope-id" class="bg-input" bind:value={formScopeId}>
              <option value="">Select agent…</option>
              {#each ($agentsResult.data ?? []) as agent (agent.slug)}
                <option value={agent.slug}>{agent.name}</option>
              {/each}
            </select>
          </div>
        {:else if formScopeType === 'workspace'}
          <div class="bg-field">
            <label class="bg-field-label" for="bg-scope-id">Workspace</label>
            <select id="bg-scope-id" class="bg-input" bind:value={formScopeId}>
              <option value="">Select workspace…</option>
              {#each ($workspacesResult.data ?? []) as ws (ws.slug)}
                <option value={ws.slug}>{ws.name ?? ws.slug}</option>
              {/each}
            </select>
          </div>
        {/if}

        <!-- Period -->
        <div class="bg-field">
          <label class="bg-field-label" for="bg-period">Period</label>
          <select id="bg-period" class="bg-input" bind:value={formPeriod}>
            <option value="weekly">Weekly</option>
            <option value="monthly">Monthly</option>
          </select>
        </div>

        <!-- Limit USD -->
        <div class="bg-field">
          <label class="bg-field-label" for="bg-limit">Limit (USD)</label>
          <input id="bg-limit" class="bg-input" type="number" min="0.01" step="0.01" placeholder="100.00" bind:value={formLimitUsd} />
        </div>

        <!-- Soft alert pct -->
        <div class="bg-field">
          <label class="bg-field-label" for="bg-alert">Alert at (%)</label>
          <input id="bg-alert" class="bg-input" type="number" min="1" max="100" step="1" bind:value={formSoftAlertPct} />
        </div>
      </div>

      <!-- Checkboxes row -->
      <div class="bg-check-row">
        <label class="bg-check-label">
          <input type="checkbox" bind:checked={formHardCeiling} />
          Hard ceiling (block sessions when exceeded)
        </label>
        <label class="bg-check-label">
          <input type="checkbox" bind:checked={formEnabled} />
          Enabled
        </label>
      </div>

      {#if formError}
        <p class="bg-form-error">{formError}</p>
      {/if}

      <div class="bg-form-actions">
        <button
          class="bg-pill-btn bg-pill-btn--primary"
          disabled={$createMut.isPending || $updateMut.isPending}
          onclick={handleSubmit}
        >
          {($createMut.isPending || $updateMut.isPending) ? 'Saving…' : 'Save'}
        </button>
        <button class="bg-pill-btn" onclick={closeForm}>Cancel</button>
      </div>
    </div>
  {/if}

  <!-- Budget list -->
  {#if $listResult.isLoading}
    <p class="bg-empty">Loading budgets…</p>
  {:else if ($listResult.data ?? []).length === 0}
    <p class="bg-empty">No budgets configured. Create one above.</p>
  {:else}
    <div class="bg-list">
      {#each ($listResult.data ?? []) as budget (budget.id)}
        <div class="bg-row">
          <div class="bg-row-left">
            <span class="bg-row-name">{budget.name}</span>
            <span class="bg-scope-chip">{SCOPE_LABELS[budget.scope_type]}{budget.scope_id ? ': ' + budget.scope_id : ''}</span>
            {#if budget.hard_ceiling}
              <span class="bg-hard-badge">hard ceiling</span>
            {/if}
          </div>

          <div class="bg-row-center">
            <span class="bg-mono">${budget.limit_usd.toFixed(2)}</span>
            <span class="bg-period-label">/{budget.period}</span>
            <!-- Spend bar -->
            <div class="bg-spend-track" aria-label="Spent {spendPct(budget).toFixed(0)}%">
              <div class="bg-spend-fill" style="width: {spendPct(budget)}%"></div>
            </div>
            <span class="bg-mono bg-spend-label">${budget.spent_this_period.toFixed(2)}</span>
          </div>

          <div class="bg-row-right">
            <!-- Enabled toggle -->
            <button
              class="bg-toggle"
              class:bg-toggle--on={budget.enabled}
              onclick={() => $toggleMut.mutate({ id: budget.id, enabled: !budget.enabled })}
              aria-pressed={budget.enabled}
              aria-label="{budget.enabled ? 'Disable' : 'Enable'} {budget.name}"
              title="{budget.enabled ? 'Enabled' : 'Disabled'}"
            >
              <span class="bg-toggle-knob"></span>
            </button>

            <button
              class="bg-icon-btn"
              onclick={() => openEdit(budget)}
              aria-label="Edit {budget.name}"
              title="Edit"
            >
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
            </button>

            <button
              class="bg-icon-btn bg-icon-btn--danger"
              disabled={deletingId === budget.id && $deleteMut.isPending}
              onclick={() => {
                deletingId = budget.id;
                $deleteMut.mutate();
              }}
              aria-label="Delete {budget.name}"
              title="Delete"
            >
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6M14 11v6"/><path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/></svg>
            </button>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .bg-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-6);
    max-width: 720px;
  }

  .bg-header-row {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: var(--space-4);
  }

  .bg-desc {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
  }

  .bg-empty {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    margin: 0;
  }

  /* ── Pill buttons ────────────────────────────────────────────────────────── */

  .bg-pill-btn {
    display: inline-flex;
    align-items: center;
    padding: var(--space-1) var(--space-3);
    border-radius: 9999px;
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    cursor: pointer;
    white-space: nowrap;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .bg-pill-btn:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
    border-color: var(--border-strong);
  }

  .bg-pill-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .bg-pill-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .bg-pill-btn--primary {
    background: var(--cnp-accent);
    border-color: var(--cnp-accent);
    color: oklch(100% 0 0);
  }

  .bg-pill-btn--primary:hover:not(:disabled) {
    background: color-mix(in oklch, var(--cnp-accent) 85%, oklch(0% 0 0) 15%);
    border-color: color-mix(in oklch, var(--cnp-accent) 85%, oklch(0% 0 0) 15%);
    color: oklch(100% 0 0);
  }

  /* ── Inline form card ────────────────────────────────────────────────────── */

  .bg-form-card {
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-5) var(--space-5);
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }

  .bg-form-title {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
  }

  .bg-form-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: var(--space-4) var(--space-5);
  }

  .bg-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .bg-field-label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--fg-subtle);
  }

  .bg-input {
    padding: var(--space-2) var(--space-3);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--bg-inset);
    color: var(--fg);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    outline: none;
    width: 100%;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .bg-input:focus {
    border-color: var(--cnp-accent);
  }

  .bg-check-row {
    display: flex;
    gap: var(--space-6);
    flex-wrap: wrap;
  }

  .bg-check-label {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    cursor: pointer;
  }

  .bg-form-error {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: oklch(55% 0.2 25);
    margin: 0;
    padding: var(--space-2) var(--space-3);
    background: color-mix(in oklch, oklch(60% 0.2 25) 10%, transparent 90%);
    border-radius: var(--radius-sm);
  }

  .bg-form-actions {
    display: flex;
    gap: var(--space-2);
  }

  /* ── Budget list ─────────────────────────────────────────────────────────── */

  .bg-list {
    display: flex;
    flex-direction: column;
    gap: 1px;
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    overflow: hidden;
  }

  .bg-row {
    display: flex;
    align-items: center;
    gap: var(--space-4);
    padding: var(--space-3) var(--space-4);
    background: var(--bg);
    transition: background var(--dur-instant) var(--ease-out);
  }

  .bg-row + .bg-row {
    border-top: 1px solid var(--border);
  }

  .bg-row:hover {
    background: color-mix(in oklch, var(--fg) 2%, transparent 98%);
  }

  .bg-row-left {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    min-width: 0;
    flex: 1;
  }

  .bg-row-name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .bg-scope-chip {
    flex-shrink: 0;
    display: inline-flex;
    align-items: center;
    padding: 0 var(--space-2);
    height: 18px;
    border-radius: 9999px;
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 500;
    background: color-mix(in oklch, var(--fg) 7%, transparent 93%);
    color: var(--fg-muted);
  }

  .bg-hard-badge {
    flex-shrink: 0;
    display: inline-flex;
    align-items: center;
    padding: 0 var(--space-2);
    height: 18px;
    border-radius: 9999px;
    font-family: var(--font-sans);
    font-size: 9px;
    font-weight: 600;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    background: color-mix(in oklch, var(--cnp-accent) 12%, transparent 88%);
    color: var(--cnp-accent);
  }

  .bg-row-center {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
  }

  .bg-mono {
    font-family: var(--font-mono);
    font-size: 12px;
    color: var(--fg-muted);
  }

  .bg-period-label {
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
  }

  .bg-spend-track {
    width: 64px;
    height: 4px;
    background: color-mix(in oklch, var(--fg) 10%, transparent 90%);
    border-radius: 9999px;
    overflow: hidden;
  }

  .bg-spend-fill {
    height: 100%;
    background: var(--cnp-accent);
    border-radius: 9999px;
    transition: width var(--dur-normal) var(--ease-io);
  }

  .bg-spend-label {
    min-width: 48px;
  }

  .bg-row-right {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    flex-shrink: 0;
  }

  /* ── Toggle ──────────────────────────────────────────────────────────────── */

  .bg-toggle {
    position: relative;
    width: 28px;
    height: 16px;
    border-radius: 9999px;
    border: none;
    background: color-mix(in oklch, var(--fg) 15%, transparent 85%);
    cursor: pointer;
    transition: background var(--dur-instant) var(--ease-out);
    flex-shrink: 0;
  }

  .bg-toggle--on {
    background: var(--cnp-accent);
  }

  .bg-toggle:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .bg-toggle-knob {
    position: absolute;
    top: 2px;
    left: 2px;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    background: oklch(100% 0 0);
    transition: transform var(--dur-instant) var(--ease-out);
    pointer-events: none;
  }

  .bg-toggle--on .bg-toggle-knob {
    transform: translateX(12px);
  }

  /* ── Icon buttons ────────────────────────────────────────────────────────── */

  .bg-icon-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    border-radius: var(--radius-sm);
    border: none;
    background: transparent;
    color: var(--fg-subtle);
    cursor: pointer;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .bg-icon-btn:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
  }

  .bg-icon-btn:disabled {
    opacity: 0.3;
    cursor: not-allowed;
  }

  .bg-icon-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  .bg-icon-btn--danger:hover:not(:disabled) {
    background: color-mix(in oklch, oklch(60% 0.2 25) 12%, transparent 88%);
    color: oklch(55% 0.2 25);
  }
</style>
