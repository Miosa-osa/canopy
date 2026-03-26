<!-- src/routes/app/alerts/+page.svelte -->
<script lang="ts">
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import { alertsStore } from '$lib/stores/alerts.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';
  import type { AlertRule } from '$api/types';

  // Re-fetch whenever the active workspace changes (covers onMount + workspace switches)
  $effect(() => {
    const wsId = workspaceStore.activeWorkspaceId ?? undefined;
    void alertsStore.fetchRules(wsId);
  });

  const ENTITY_OPTIONS: { value: AlertRule['entity_type']; label: string }[] = [
    { value: 'agent',    label: 'Agent'    },
    { value: 'system',   label: 'System'   },
    { value: 'schedule', label: 'Schedule' },
    { value: 'budget',   label: 'Cost'     },
  ];

  const OPERATOR_OPTIONS: { value: AlertRule['operator']; label: string }[] = [
    { value: 'gt',       label: '>'        },
    { value: 'lt',       label: '<'        },
    { value: 'gte',      label: '>='       },
    { value: 'lte',      label: '<='       },
    { value: 'eq',       label: '=='       },
    { value: 'neq',      label: '!='       },
    { value: 'contains', label: 'contains' },
  ];

  const ACTION_OPTIONS: { value: AlertRule['action']; label: string }[] = [
    { value: 'notify',      label: 'Notify'    },
    { value: 'pause_agent', label: 'Pause'     },
    { value: 'webhook',     label: 'Webhook'   },
    { value: 'email',       label: 'Email'     },
  ];

  // Create form state
  let showForm = $state(false);
  let formName = $state('');
  let formEntity = $state<AlertRule['entity_type']>('agent');
  let formField = $state('');
  let formOperator = $state<AlertRule['operator']>('gt');
  let formThreshold = $state('');
  let formAction = $state<AlertRule['action']>('notify');
  let formEnabled = $state(true);
  let creating = $state(false);
  let formError = $state<string | null>(null);

  async function handleCreate() {
    if (!formName.trim() || !formField.trim() || !formThreshold.trim()) return;
    creating = true;
    formError = null;
    const created = await alertsStore.createRule({
      name: formName.trim(),
      entity_type: formEntity,
      field: formField.trim(),
      operator: formOperator,
      value: formThreshold.trim(),
      action: formAction,
      enabled: formEnabled,
    });
    creating = false;
    if (created) {
      resetForm();
    } else {
      formError = alertsStore.error;
    }
  }

  function resetForm() {
    showForm = false;
    formName = '';
    formEntity = 'agent';
    formField = '';
    formOperator = 'gt';
    formThreshold = '';
    formAction = 'notify';
    formEnabled = true;
    formError = null;
  }
</script>

<PageShell
  title="Alerts"
  subtitle="{alertsStore.enabledCount} of {alertsStore.totalCount} enabled"
>
  {#snippet actions()}
    <button
      class="al-create-btn"
      onclick={() => showForm = true}
      type="button"
      aria-label="Create alert rule"
    >
      + Create
    </button>
  {/snippet}

  {#if alertsStore.loading && alertsStore.rules.length === 0}
    <div class="al-loading" role="status" aria-live="polite">
      <div class="al-spinner" aria-hidden="true"></div>
      <span>Loading alert rules…</span>
    </div>
  {:else if alertsStore.error && alertsStore.rules.length === 0}
    <div class="al-error" role="alert">
      <p>Failed to load alerts: {alertsStore.error}</p>
      <button onclick={() => void alertsStore.fetchRules()}>Retry</button>
    </div>
  {:else if alertsStore.rules.length === 0}
    <div class="al-empty" role="status">
      <p>No alert rules configured.</p>
    </div>
  {:else}
    <div class="al-list" role="list" aria-label="Alert rules">
      {#each alertsStore.rules as rule (rule.id)}
        <div class="al-item" role="listitem">
          <div class="al-info">
            <div class="al-name">{rule.name}</div>
            <div class="al-meta">
              <span class="al-entity">{rule.entity ?? rule.entity_type}</span>
              <span class="al-op">{rule.field} {rule.operator} {rule.value}</span>
              <span class="al-action">→ {rule.action}</span>
            </div>
          </div>
          <span class="al-status" class:al-status--on={rule.enabled}>
            {rule.enabled ? 'Active' : 'Inactive'}
          </span>
        </div>
      {/each}
    </div>
  {/if}
</PageShell>

<!-- Create alert dialog -->
{#if showForm}
  <div
    class="al-overlay"
    role="dialog"
    aria-modal="true"
    aria-label="Create alert rule"
    onclick={(e) => { if (e.target === e.currentTarget) resetForm(); }}
  >
    <div class="al-dialog">
      <h2 class="al-dialog-title">New Alert Rule</h2>

      <div class="al-field">
        <label class="al-label" for="al-name-input">Name</label>
        <input
          id="al-name-input"
          class="al-input"
          type="text"
          placeholder="High error rate"
          bind:value={formName}
          autofocus
        />
      </div>

      <div class="al-field">
        <label class="al-label" for="al-entity-input">Entity</label>
        <select id="al-entity-input" class="al-select" bind:value={formEntity}>
          {#each ENTITY_OPTIONS as opt (opt.value)}
            <option value={opt.value}>{opt.label}</option>
          {/each}
        </select>
      </div>

      <div class="al-field">
        <label class="al-label" for="al-field-input">Field</label>
        <input
          id="al-field-input"
          class="al-input"
          type="text"
          placeholder="e.g. error_rate"
          bind:value={formField}
        />
      </div>

      <div class="al-row">
        <div class="al-field">
          <label class="al-label" for="al-operator-input">Operator</label>
          <select id="al-operator-input" class="al-select" bind:value={formOperator}>
            {#each OPERATOR_OPTIONS as opt (opt.value)}
              <option value={opt.value}>{opt.label}</option>
            {/each}
          </select>
        </div>

        <div class="al-field">
          <label class="al-label" for="al-threshold-input">Threshold</label>
          <input
            id="al-threshold-input"
            class="al-input"
            type="text"
            placeholder="e.g. 0.1"
            bind:value={formThreshold}
          />
        </div>
      </div>

      <div class="al-field">
        <label class="al-label" for="al-action-input">Action</label>
        <select id="al-action-input" class="al-select" bind:value={formAction}>
          {#each ACTION_OPTIONS as opt (opt.value)}
            <option value={opt.value}>{opt.label}</option>
          {/each}
        </select>
      </div>

      <label class="al-checkbox-label">
        <input type="checkbox" bind:checked={formEnabled} />
        <span>Enabled</span>
      </label>

      {#if formError}
        <p class="al-form-error" role="alert">{formError}</p>
      {/if}

      <div class="al-dialog-actions">
        <button class="al-btn-ghost" onclick={resetForm} disabled={creating}>Cancel</button>
        <button
          class="al-btn-primary"
          onclick={handleCreate}
          disabled={creating || !formName.trim() || !formField.trim() || !formThreshold.trim()}
        >
          {creating ? 'Creating…' : 'Create Rule'}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .al-create-btn {
    height: 28px; padding: 0 12px; border-radius: 6px; font-size: 12px; font-weight: 500;
    background: #6366f1; border: none; color: white; cursor: pointer; transition: background 120ms ease;
  }
  .al-create-btn:hover { background: #4f46e5; }

  .al-loading, .al-empty, .al-error {
    display: flex; flex-direction: column; align-items: center;
    justify-content: center; gap: 12px; height: 200px;
    color: var(--dt3); font-size: 13px;
  }
  .al-spinner {
    width: 24px; height: 24px; border-radius: 50%;
    border: 2px solid var(--dbd); border-top-color: var(--dt2);
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }
  .al-list { display: flex; flex-direction: column; gap: 8px; padding: 24px; }
  .al-item {
    display: flex; align-items: center; gap: 16px;
    padding: 14px 16px; border-radius: 8px;
    background: var(--dbg2); border: 1px solid var(--dbd);
  }
  .al-info { flex: 1; }
  .al-name { font-size: 14px; font-weight: 500; color: var(--dt); margin-bottom: 4px; }
  .al-meta { display: flex; align-items: center; gap: 8px; font-size: 12px; color: var(--dt3); flex-wrap: wrap; }
  .al-entity { background: var(--dbg3); padding: 1px 6px; border-radius: 4px; font-size: 10px; text-transform: uppercase; }
  .al-op { font-family: var(--font-mono); }
  .al-action { color: var(--dt2); }
  .al-status { font-size: 12px; padding: 3px 8px; border-radius: 4px; background: var(--dbg3); color: var(--dt3); }
  .al-status--on { background: rgba(34, 197, 94, 0.12); color: rgba(134, 239, 172, 0.8); }

  /* Dialog */
  .al-overlay {
    position: fixed; inset: 0; background: rgba(0,0,0,0.5);
    display: flex; align-items: center; justify-content: center; z-index: 1000;
  }
  .al-dialog {
    background: var(--dbg2); border: 1px solid var(--dbd); border-radius: 12px;
    padding: 24px; width: 440px; max-width: calc(100vw - 40px);
    display: flex; flex-direction: column; gap: 16px;
  }
  .al-dialog-title { font-size: 16px; font-weight: 600; color: var(--dt); margin: 0; }
  .al-field { display: flex; flex-direction: column; gap: 6px; }
  .al-label { font-size: 12px; font-weight: 500; color: var(--dt2); }
  .al-input, .al-select {
    height: 34px; padding: 0 10px; border-radius: 6px; font-size: 13px;
    background: var(--dbg3); border: 1px solid var(--dbd); color: var(--dt);
    width: 100%; box-sizing: border-box;
  }
  .al-input:focus, .al-select:focus { outline: none; border-color: #6366f1; }
  .al-row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
  .al-checkbox-label {
    display: flex; align-items: center; gap: 8px; font-size: 13px; color: var(--dt);
    cursor: pointer;
  }
  .al-checkbox-label input[type="checkbox"] { accent-color: #6366f1; }
  .al-form-error { font-size: 12px; color: #fca5a5; margin: 0; }
  .al-dialog-actions { display: flex; gap: 8px; justify-content: flex-end; margin-top: 4px; }
  .al-btn-ghost, .al-btn-primary {
    padding: 7px 16px; border-radius: 6px; font-size: 13px; font-weight: 500; cursor: pointer;
    transition: all 120ms ease;
  }
  .al-btn-ghost { background: transparent; border: 1px solid var(--dbd); color: var(--dt3); }
  .al-btn-ghost:hover:not(:disabled) { background: var(--dbg3); color: var(--dt2); }
  .al-btn-primary { background: #6366f1; border: none; color: #fff; }
  .al-btn-primary:hover:not(:disabled) { background: #4f46e5; }
  .al-btn-ghost:disabled, .al-btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
