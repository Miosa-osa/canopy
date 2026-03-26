<!-- src/lib/components/costs/BudgetPolicyTable.svelte -->
<script lang="ts">
  import BudgetBar from '$lib/components/shared/BudgetBar.svelte';
  import { costsStore } from '$lib/stores/costs.svelte';
  import type { BudgetPolicy, BudgetPolicyInput } from '$api/types';

  // ── Formatting helpers ──────────────────────────────────────────────────────

  function fmtCents(cents: number): string {
    return '$' + (cents / 100).toFixed(2);
  }

  function policyScope(policy: BudgetPolicy): string {
    if (policy.agent_ids.length === 0) return 'All agents';
    if (policy.agent_ids.length === 1) return '1 agent';
    return `${policy.agent_ids.length} agents`;
  }

  function policyStatus(policy: BudgetPolicy): 'healthy' | 'warning' | 'exceeded' {
    const incident = costsStore.incidents.find(
      (i) => i.policy_id === policy.id && !i.resolved
    );
    if (!incident) return 'healthy';
    if (incident.type === 'hard_stop') return 'exceeded';
    return 'warning';
  }

  function currentUsageCents(policy: BudgetPolicy): number {
    const incident = costsStore.incidents.find((i) => i.policy_id === policy.id);
    return incident ? incident.amount_cents : 0;
  }

  // ── Edit state ──────────────────────────────────────────────────────────────

  let editingId = $state<string | null>(null);
  let editName = $state('');
  let editDailyLimitDollars = $state('');
  let editMonthlyLimitDollars = $state('');
  let editWarningPct = $state('');
  let editHardStop = $state(false);
  let saving = $state(false);

  function startEdit(policy: BudgetPolicy) {
    editingId = policy.id;
    editName = policy.name;
    editDailyLimitDollars = (policy.daily_limit_cents / 100).toFixed(2);
    editMonthlyLimitDollars = (policy.monthly_limit_cents / 100).toFixed(2);
    editWarningPct = String(Math.round(policy.warning_threshold * 100));
    editHardStop = policy.hard_stop;
    deleteConfirmId = null;
    showCreateForm = false;
  }

  function cancelEdit() {
    editingId = null;
  }

  async function saveEdit() {
    if (!editingId) return;
    saving = true;
    const input: BudgetPolicyInput = {
      daily_limit_cents: Math.round(parseFloat(editDailyLimitDollars) * 100),
      monthly_limit_cents: Math.round(parseFloat(editMonthlyLimitDollars) * 100),
      warning_threshold: parseFloat(editWarningPct) / 100,
      hard_stop: editHardStop,
    };
    try {
      await costsStore.upsertPolicy('policy', editingId, input);
      editingId = null;
    } finally {
      saving = false;
    }
  }

  // ── Delete state ────────────────────────────────────────────────────────────

  let deleteConfirmId = $state<string | null>(null);
  let deleting = $state(false);

  function requestDelete(policy: BudgetPolicy) {
    deleteConfirmId = policy.id;
    editingId = null;
    showCreateForm = false;
  }

  function cancelDelete() {
    deleteConfirmId = null;
  }

  async function confirmDelete() {
    if (!deleteConfirmId) return;
    deleting = true;
    try {
      await costsStore.deletePolicy('policy', deleteConfirmId);
      deleteConfirmId = null;
    } finally {
      deleting = false;
    }
  }

  // ── Create state ────────────────────────────────────────────────────────────

  let showCreateForm = $state(false);
  let createName = $state('');
  let createDailyLimitDollars = $state('');
  let createMonthlyLimitDollars = $state('');
  let createWarningPct = $state('80');
  let createHardStop = $state(false);
  let creating = $state(false);

  function openCreateForm() {
    showCreateForm = true;
    editingId = null;
    deleteConfirmId = null;
    createName = '';
    createDailyLimitDollars = '';
    createMonthlyLimitDollars = '';
    createWarningPct = '80';
    createHardStop = false;
  }

  function cancelCreate() {
    showCreateForm = false;
  }

  async function submitCreate() {
    creating = true;
    // Use a generated scope ID based on name; the backend owns the canonical ID
    const scopeId = createName.toLowerCase().replace(/\s+/g, '-') + '-' + Date.now();
    const input: BudgetPolicyInput = {
      daily_limit_cents: Math.round(parseFloat(createDailyLimitDollars) * 100),
      monthly_limit_cents: Math.round(parseFloat(createMonthlyLimitDollars) * 100),
      warning_threshold: parseFloat(createWarningPct) / 100,
      hard_stop: createHardStop,
    };
    try {
      await costsStore.upsertPolicy('policy', scopeId, input);
      showCreateForm = false;
    } finally {
      creating = false;
    }
  }

  // ── Validation helpers ──────────────────────────────────────────────────────

  function isPositiveMoney(val: string): boolean {
    const n = parseFloat(val);
    return !isNaN(n) && n > 0;
  }

  function isValidPct(val: string): boolean {
    const n = parseFloat(val);
    return !isNaN(n) && n > 0 && n <= 100;
  }

  const editValid = $derived(
    isPositiveMoney(editDailyLimitDollars) &&
    isPositiveMoney(editMonthlyLimitDollars) &&
    isValidPct(editWarningPct)
  );

  const createValid = $derived(
    createName.trim().length > 0 &&
    isPositiveMoney(createDailyLimitDollars) &&
    isPositiveMoney(createMonthlyLimitDollars) &&
    isValidPct(createWarningPct)
  );
</script>

<article class="bpt-panel" aria-label="Budget policies">
  <header class="bpt-header">
    <span class="bpt-title">Budget Policies</span>
    <button
      class="bpt-add-btn"
      aria-label="Add new budget policy"
      onclick={openCreateForm}
    >
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true">
        <path d="M12 5v14M5 12h14" />
      </svg>
      Add Policy
    </button>
  </header>

  {#if showCreateForm}
    <div class="bpt-form-row" role="region" aria-label="Create budget policy">
      <div class="bpt-form-fields">
        <label class="bpt-form-label">
          Name
          <input
            class="bpt-form-input"
            type="text"
            placeholder="e.g. Production Guard"
            bind:value={createName}
            aria-label="Policy name"
          />
        </label>
        <label class="bpt-form-label">
          Daily Limit ($)
          <input
            class="bpt-form-input bpt-form-input--num"
            type="number"
            min="0.01"
            step="0.01"
            placeholder="10.00"
            bind:value={createDailyLimitDollars}
            aria-label="Daily limit in dollars"
          />
        </label>
        <label class="bpt-form-label">
          Monthly Limit ($)
          <input
            class="bpt-form-input bpt-form-input--num"
            type="number"
            min="0.01"
            step="0.01"
            placeholder="200.00"
            bind:value={createMonthlyLimitDollars}
            aria-label="Monthly limit in dollars"
          />
        </label>
        <label class="bpt-form-label">
          Warning (%)
          <input
            class="bpt-form-input bpt-form-input--num"
            type="number"
            min="1"
            max="100"
            step="1"
            placeholder="80"
            bind:value={createWarningPct}
            aria-label="Warning threshold percent"
          />
        </label>
        <label class="bpt-form-label bpt-form-label--check">
          <input
            type="checkbox"
            class="bpt-form-check"
            bind:checked={createHardStop}
            aria-label="Enable hard stop"
          />
          Hard Stop
        </label>
      </div>
      <div class="bpt-form-actions">
        <button
          class="bpt-save-btn"
          onclick={submitCreate}
          disabled={!createValid || creating}
          aria-label="Save new policy"
        >
          {creating ? 'Saving…' : 'Save'}
        </button>
        <button
          class="bpt-cancel-btn"
          onclick={cancelCreate}
          aria-label="Cancel create policy"
        >
          Cancel
        </button>
      </div>
    </div>
  {/if}

  {#if costsStore.policies.length === 0 && !showCreateForm}
    <div class="bpt-empty">No budget policies configured</div>
  {:else if costsStore.policies.length > 0}
    <div class="bpt-table-wrap" role="region" aria-label="Budget policies table">
      <table class="bpt-table">
        <thead>
          <tr>
            <th class="bpt-th">Name</th>
            <th class="bpt-th">Scope</th>
            <th class="bpt-th bpt-th--num">Daily Limit</th>
            <th class="bpt-th bpt-th--num">Monthly Limit</th>
            <th class="bpt-th bpt-th--wide">Daily Usage</th>
            <th class="bpt-th bpt-th--num">Warning</th>
            <th class="bpt-th">Hard Stop</th>
            <th class="bpt-th">Status</th>
            <th class="bpt-th bpt-th--actions">Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each costsStore.policies as policy (policy.id)}
            {@const status = policyStatus(policy)}
            {@const usageCents = currentUsageCents(policy)}

            {#if editingId === policy.id}
              <!-- Inline edit row -->
              <tr class="bpt-row bpt-edit-row">
                <td class="bpt-td" colspan="9">
                  <div class="bpt-form-fields">
                    <label class="bpt-form-label">
                      Name
                      <input
                        class="bpt-form-input"
                        type="text"
                        bind:value={editName}
                        aria-label="Edit policy name"
                      />
                    </label>
                    <label class="bpt-form-label">
                      Daily ($)
                      <input
                        class="bpt-form-input bpt-form-input--num"
                        type="number"
                        min="0.01"
                        step="0.01"
                        bind:value={editDailyLimitDollars}
                        aria-label="Edit daily limit"
                      />
                    </label>
                    <label class="bpt-form-label">
                      Monthly ($)
                      <input
                        class="bpt-form-input bpt-form-input--num"
                        type="number"
                        min="0.01"
                        step="0.01"
                        bind:value={editMonthlyLimitDollars}
                        aria-label="Edit monthly limit"
                      />
                    </label>
                    <label class="bpt-form-label">
                      Warning (%)
                      <input
                        class="bpt-form-input bpt-form-input--num"
                        type="number"
                        min="1"
                        max="100"
                        step="1"
                        bind:value={editWarningPct}
                        aria-label="Edit warning threshold"
                      />
                    </label>
                    <label class="bpt-form-label bpt-form-label--check">
                      <input
                        type="checkbox"
                        class="bpt-form-check"
                        bind:checked={editHardStop}
                        aria-label="Toggle hard stop"
                      />
                      Hard Stop
                    </label>
                    <div class="bpt-form-actions">
                      <button
                        class="bpt-save-btn"
                        onclick={saveEdit}
                        disabled={!editValid || saving}
                        aria-label="Save policy changes"
                      >
                        {saving ? 'Saving…' : 'Save'}
                      </button>
                      <button
                        class="bpt-cancel-btn"
                        onclick={cancelEdit}
                        aria-label="Cancel edit"
                      >
                        Cancel
                      </button>
                    </div>
                  </div>
                </td>
              </tr>
            {:else if deleteConfirmId === policy.id}
              <!-- Delete confirmation row -->
              <tr class="bpt-row bpt-confirm-row">
                <td class="bpt-td" colspan="9">
                  <div class="bpt-confirm-content">
                    <span class="bpt-confirm-msg">
                      Delete policy <strong>{policy.name}</strong>? This cannot be undone.
                    </span>
                    <div class="bpt-form-actions">
                      <button
                        class="bpt-delete-confirm-btn"
                        onclick={confirmDelete}
                        disabled={deleting}
                        aria-label="Confirm delete policy {policy.name}"
                      >
                        {deleting ? 'Deleting…' : 'Delete'}
                      </button>
                      <button
                        class="bpt-cancel-btn"
                        onclick={cancelDelete}
                        aria-label="Cancel delete"
                      >
                        Cancel
                      </button>
                    </div>
                  </div>
                </td>
              </tr>
            {:else}
              <!-- Normal data row -->
              <tr class="bpt-row bpt-row--{status}">
                <td class="bpt-td">
                  <span class="bpt-name">{policy.name}</span>
                </td>
                <td class="bpt-td">
                  <span class="bpt-scope">{policyScope(policy)}</span>
                </td>
                <td class="bpt-td bpt-td--num">{fmtCents(policy.daily_limit_cents)}</td>
                <td class="bpt-td bpt-td--num">{fmtCents(policy.monthly_limit_cents)}</td>
                <td class="bpt-td bpt-td--wide">
                  <BudgetBar
                    spent={usageCents / 100}
                    limit={policy.daily_limit_cents / 100}
                    currency="$"
                    warningPct={Math.round(policy.warning_threshold * 100)}
                  />
                </td>
                <td class="bpt-td bpt-td--num">{Math.round(policy.warning_threshold * 100)}%</td>
                <td class="bpt-td">
                  <span class="bpt-badge bpt-badge--{policy.hard_stop ? 'on' : 'off'}">
                    {policy.hard_stop ? 'Yes' : 'No'}
                  </span>
                </td>
                <td class="bpt-td">
                  <span class="bpt-status bpt-status--{status}" aria-label="Status: {status}">
                    {status === 'healthy' ? 'Healthy' : status === 'warning' ? 'Warning' : 'Exceeded'}
                  </span>
                </td>
                <td class="bpt-td bpt-td--actions">
                  <button
                    class="bpt-action-btn"
                    aria-label="Edit policy {policy.name}"
                    title="Edit"
                    onclick={() => startEdit(policy)}
                  >
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                      <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
                      <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
                    </svg>
                  </button>
                  <button
                    class="bpt-action-btn bpt-action-btn--danger"
                    aria-label="Delete policy {policy.name}"
                    title="Delete"
                    onclick={() => requestDelete(policy)}
                  >
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                      <polyline points="3 6 5 6 21 6" />
                      <path d="M19 6l-1 14H6L5 6M10 11v6M14 11v6" />
                      <path d="M9 6V4h6v2" />
                    </svg>
                  </button>
                </td>
              </tr>
            {/if}
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</article>

<style>
  .bpt-panel {
    background: var(--bg-surface);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-lg);
    padding: var(--space-4);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .bpt-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .bpt-title {
    font-family: var(--font-sans);
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary);
  }

  .bpt-add-btn {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
    background: var(--accent-primary);
    border: none;
    border-radius: var(--radius-sm);
    color: #fff;
    font-family: var(--font-sans);
    font-size: 12px;
    font-weight: 500;
    padding: var(--space-1) var(--space-3);
    cursor: pointer;
    transition: opacity 120ms ease;
  }

  .bpt-add-btn:hover {
    opacity: 0.85;
  }

  /* ── Form row (create + inline edit) ─────────────────────────────────────── */

  .bpt-form-row {
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-md);
    padding: var(--space-3);
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .bpt-form-fields {
    display: flex;
    flex-wrap: wrap;
    align-items: flex-end;
    gap: var(--space-2);
  }

  .bpt-form-label {
    display: flex;
    flex-direction: column;
    gap: 3px;
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--text-tertiary);
    font-weight: 500;
  }

  .bpt-form-label--check {
    flex-direction: row;
    align-items: center;
    gap: var(--space-1);
    color: var(--text-secondary);
    cursor: pointer;
  }

  .bpt-form-input {
    background: var(--bg-surface);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-xs);
    color: var(--text-primary);
    font-family: var(--font-sans);
    font-size: 12px;
    padding: 4px 6px;
    width: 120px;
    outline: none;
    transition: border-color 120ms ease;
  }

  .bpt-form-input--num {
    width: 80px;
    text-align: right;
    font-variant-numeric: tabular-nums;
  }

  .bpt-form-input:focus {
    border-color: var(--accent-primary);
  }

  .bpt-form-check {
    accent-color: var(--accent-primary);
    width: 14px;
    height: 14px;
    cursor: pointer;
  }

  .bpt-form-actions {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    margin-left: auto;
  }

  .bpt-save-btn {
    background: var(--accent-primary);
    border: none;
    border-radius: var(--radius-xs);
    color: #fff;
    font-family: var(--font-sans);
    font-size: 12px;
    font-weight: 500;
    padding: 4px 10px;
    cursor: pointer;
    transition: opacity 120ms ease;
  }

  .bpt-save-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .bpt-save-btn:not(:disabled):hover {
    opacity: 0.85;
  }

  .bpt-cancel-btn {
    background: none;
    border: 1px solid var(--border-default);
    border-radius: var(--radius-xs);
    color: var(--text-secondary);
    font-family: var(--font-sans);
    font-size: 12px;
    font-weight: 500;
    padding: 4px 10px;
    cursor: pointer;
    transition: border-color 120ms ease, color 120ms ease;
  }

  .bpt-cancel-btn:hover {
    border-color: var(--border-hover);
    color: var(--text-primary);
  }

  /* ── Delete confirm row ───────────────────────────────────────────────────── */

  .bpt-confirm-row {
    background: rgba(239, 68, 68, 0.04);
  }

  .bpt-confirm-content {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
    flex-wrap: wrap;
  }

  .bpt-confirm-msg {
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--text-secondary);
  }

  .bpt-confirm-msg strong {
    color: var(--text-primary);
    font-weight: 600;
  }

  .bpt-delete-confirm-btn {
    background: rgba(239, 68, 68, 0.15);
    border: 1px solid rgba(239, 68, 68, 0.4);
    border-radius: var(--radius-xs);
    color: #ef4444;
    font-family: var(--font-sans);
    font-size: 12px;
    font-weight: 500;
    padding: 4px 10px;
    cursor: pointer;
    transition: background 120ms ease;
  }

  .bpt-delete-confirm-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .bpt-delete-confirm-btn:not(:disabled):hover {
    background: rgba(239, 68, 68, 0.25);
  }

  /* ── Inline edit row ──────────────────────────────────────────────────────── */

  .bpt-edit-row {
    background: var(--bg-elevated);
  }

  .bpt-edit-row .bpt-td {
    padding: var(--space-2) var(--space-2);
  }

  /* ── Table ────────────────────────────────────────────────────────────────── */

  .bpt-empty {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 60px;
    font-size: 13px;
    color: var(--text-tertiary);
  }

  .bpt-table-wrap {
    overflow-x: auto;
  }

  .bpt-table {
    width: 100%;
    border-collapse: collapse;
    font-family: var(--font-sans);
    font-size: 12px;
  }

  .bpt-th {
    padding: var(--space-2);
    text-align: left;
    color: var(--text-tertiary);
    font-weight: 500;
    font-size: 11px;
    letter-spacing: 0.3px;
    border-bottom: 1px solid var(--border-default);
    white-space: nowrap;
  }

  .bpt-th--num { text-align: right; }
  .bpt-th--wide { min-width: 140px; }
  .bpt-th--actions { width: 64px; }

  .bpt-row {
    border-bottom: 1px solid var(--border-default);
    transition: background 120ms ease;
  }

  .bpt-row:last-child { border-bottom: none; }
  .bpt-row:hover { background: var(--bg-elevated); }

  .bpt-row--warning { background: rgba(245, 158, 11, 0.03); }
  .bpt-row--exceeded { background: rgba(239, 68, 68, 0.04); }

  .bpt-td {
    padding: var(--space-2);
    color: var(--text-secondary);
    vertical-align: middle;
  }

  .bpt-td--num { text-align: right; font-variant-numeric: tabular-nums; }
  .bpt-td--wide { min-width: 140px; }
  .bpt-td--actions {
    display: flex;
    align-items: center;
    gap: var(--space-1);
  }

  .bpt-name {
    font-weight: 600;
    color: var(--text-primary);
  }

  .bpt-scope {
    color: var(--text-tertiary);
    font-size: 11px;
  }

  .bpt-badge {
    display: inline-flex;
    align-items: center;
    padding: 2px 6px;
    border-radius: var(--radius-xs);
    font-size: 11px;
    font-weight: 500;
  }

  .bpt-badge--on  { color: #ef4444; background: rgba(239,68,68,0.1); }
  .bpt-badge--off { color: var(--text-tertiary); background: rgba(255,255,255,0.05); }

  .bpt-status {
    display: inline-flex;
    align-items: center;
    padding: 2px 7px;
    border-radius: var(--radius-xs);
    font-size: 11px;
    font-weight: 500;
  }

  .bpt-status--healthy  { color: rgba(34, 197, 94, 0.7); background: rgba(34,197,94,0.08); }
  .bpt-status--warning  { color: #f59e0b; background: rgba(245,158,11,0.1); }
  .bpt-status--exceeded { color: #ef4444; background: rgba(239,68,68,0.1); }

  .bpt-action-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 26px;
    height: 26px;
    background: none;
    border: 1px solid var(--border-default);
    border-radius: var(--radius-xs);
    color: var(--text-tertiary);
    cursor: pointer;
    transition: border-color 120ms ease, color 120ms ease;
  }

  .bpt-action-btn:hover {
    border-color: var(--border-hover);
    color: var(--text-primary);
  }

  .bpt-action-btn--danger:hover {
    border-color: rgba(239, 68, 68, 0.5);
    color: #ef4444;
  }
</style>
