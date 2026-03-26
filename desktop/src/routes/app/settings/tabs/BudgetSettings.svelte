<!-- src/routes/app/settings/tabs/BudgetSettings.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { settingsStore } from '$lib/stores/settings.svelte';
  import { costsStore } from '$lib/stores/costs.svelte';

  // Local display state (dollars / percent) initialised from the workspace policy
  let dailyLimitDollars = $state(50);
  let monthlyLimitDollars = $state(500);
  let warningThreshold = $state(80);
  let hardStop = $state(true);

  let dirty = $state(false);
  let saving = $state(false);

  function loadFromPolicy(): void {
    const policy = costsStore.policies.find(p => p.agent_ids.length === 0);
    if (!policy) return;
    dailyLimitDollars = Math.round(policy.daily_limit_cents / 100);
    monthlyLimitDollars = Math.round(policy.monthly_limit_cents / 100);
    // API stores warning_threshold as 0-1 decimal; display as 0-100 percent
    warningThreshold = Math.round(policy.warning_threshold * 100);
    hardStop = policy.hard_stop;
    dirty = false;
  }

  onMount(async () => {
    if (costsStore.policies.length === 0) {
      await costsStore.fetchPolicies();
    }
    loadFromPolicy();
  });

  // Re-initialise whenever the policies array is updated from the store
  $effect(() => {
    // Touch costsStore.policies to subscribe to reactive updates
    void costsStore.policies;
    loadFromPolicy();
  });

  async function saveSettings(): Promise<void> {
    saving = true;
    await costsStore.upsertPolicy('workspace', 'default', {
      daily_limit_cents: Math.round(dailyLimitDollars * 100),
      monthly_limit_cents: Math.round(monthlyLimitDollars * 100),
      warning_threshold: warningThreshold / 100,
      hard_stop: hardStop,
    });
    saving = false;
    dirty = false;
  }

  function markDirty(): void {
    dirty = true;
  }
</script>

<section class="stg-section">
  <h2 class="stg-section-title">Budget</h2>

  <div class="stg-card">
    <div class="stg-field stg-field--row">
      <div class="stg-field-text">
        <label class="stg-label" for="budget-enforcement">Budget Enforcement</label>
        <p class="stg-desc">When enabled, agents are paused when they exceed their assigned budget limits.</p>
      </div>
      <label class="stg-toggle" aria-label="Enable budget enforcement">
        <input
          id="budget-enforcement"
          type="checkbox"
          checked={settingsStore.data.budget_enforcement}
          onchange={(e) => settingsStore.update('budget_enforcement', (e.target as HTMLInputElement).checked)}
        />
        <span class="stg-toggle-track">
          <span class="stg-toggle-thumb"></span>
        </span>
      </label>
    </div>

    <div class="stg-sep"></div>

    <div class="stg-field">
      <label class="stg-label" for="daily-limit">Daily Limit (USD)</label>
      <p class="stg-desc">Hard ceiling on spend per calendar day across all agents.</p>
      <div class="stg-input-group">
        <span class="stg-input-prefix">$</span>
        <input
          id="daily-limit"
          class="stg-input stg-input--prefixed"
          type="number"
          min="0"
          step="1"
          bind:value={dailyLimitDollars}
          oninput={markDirty}
        />
      </div>
    </div>

    <div class="stg-sep"></div>

    <div class="stg-field">
      <label class="stg-label" for="monthly-limit">Monthly Limit (USD)</label>
      <p class="stg-desc">Hard ceiling on spend per calendar month across all agents.</p>
      <div class="stg-input-group">
        <span class="stg-input-prefix">$</span>
        <input
          id="monthly-limit"
          class="stg-input stg-input--prefixed"
          type="number"
          min="0"
          step="10"
          bind:value={monthlyLimitDollars}
          oninput={markDirty}
        />
      </div>
    </div>

    <div class="stg-sep"></div>

    <div class="stg-field">
      <label class="stg-label" for="warning-threshold">
        Warning Threshold
        <span class="stg-value-badge">{warningThreshold}%</span>
      </label>
      <p class="stg-desc">Trigger a budget warning when this percentage of the daily limit is consumed.</p>
      <input
        id="warning-threshold"
        class="stg-slider"
        type="range"
        min="10"
        max="95"
        step="5"
        bind:value={warningThreshold}
        oninput={markDirty}
      />
      <div class="stg-slider-labels">
        <span>10%</span>
        <span>95%</span>
      </div>
    </div>

    <div class="stg-sep"></div>

    <div class="stg-field stg-field--row">
      <div class="stg-field-text">
        <label class="stg-label" for="hard-stop">Hard Stop on Limit</label>
        <p class="stg-desc">Immediately terminate agent runs when the daily limit is hit. Disable to allow overruns with warnings only.</p>
      </div>
      <label class="stg-toggle" aria-label="Hard stop on budget limit">
        <input
          id="hard-stop"
          type="checkbox"
          bind:checked={hardStop}
          onchange={markDirty}
        />
        <span class="stg-toggle-track">
          <span class="stg-toggle-thumb"></span>
        </span>
      </label>
    </div>

    {#if dirty}
      <div class="stg-sep"></div>
      <div class="stg-field stg-field--row stg-field--actions">
        <p class="stg-desc stg-desc--unsaved">Unsaved changes</p>
        <button
          class="stg-btn-save"
          onclick={saveSettings}
          disabled={saving}
          aria-label="Save budget settings"
        >
          {saving ? 'Saving…' : 'Save Changes'}
        </button>
      </div>
    {/if}
  </div>
</section>

<style>
  .stg-section { max-width: 640px; }

  .stg-section-title {
    font-size: 15px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0 0 4px;
  }

  .stg-card {
    background: var(--bg-surface);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-md);
    padding: 4px 0;
    margin-top: 16px;
  }

  .stg-sep {
    height: 1px;
    background: var(--border-default);
    margin: 0;
  }

  .stg-field {
    padding: 14px 16px;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .stg-field--row {
    flex-direction: row;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
  }

  .stg-field--actions {
    padding: 12px 16px;
  }

  .stg-field-text {
    display: flex;
    flex-direction: column;
    gap: 4px;
    flex: 1;
    min-width: 0;
  }

  .stg-label {
    font-size: 13px;
    font-weight: 500;
    color: var(--text-primary);
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .stg-desc {
    font-size: 12px;
    color: var(--text-tertiary);
    line-height: 1.5;
  }

  .stg-desc--unsaved {
    color: var(--accent-warning, #f59e0b);
  }

  .stg-value-badge {
    font-size: 11px;
    font-weight: 500;
    color: var(--accent-primary);
    background: rgba(59, 130, 246, 0.12);
    border: 1px solid rgba(59, 130, 246, 0.2);
    border-radius: var(--radius-full);
    padding: 1px 7px;
  }

  .stg-input-group {
    display: flex;
    align-items: stretch;
  }

  .stg-input-prefix {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0 10px;
    font-size: 13px;
    color: var(--text-tertiary);
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-right: none;
    border-radius: var(--radius-sm) 0 0 var(--radius-sm);
    flex-shrink: 0;
  }

  .stg-input {
    width: 100%;
    padding: 7px 10px;
    font-size: 13px;
    color: var(--text-primary);
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
    outline: none;
    transition: border-color var(--transition-fast);
  }

  .stg-input:focus { border-color: var(--border-focus); }

  .stg-input--prefixed {
    border-radius: 0 var(--radius-sm) var(--radius-sm) 0;
  }

  .stg-slider {
    width: 100%;
    height: 4px;
    appearance: none;
    background: var(--border-default);
    border-radius: var(--radius-full);
    outline: none;
    cursor: pointer;
    accent-color: var(--accent-primary);
  }

  .stg-slider::-webkit-slider-thumb {
    appearance: none;
    width: 16px;
    height: 16px;
    border-radius: 50%;
    background: var(--accent-primary);
    cursor: pointer;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.2);
    transition: box-shadow var(--transition-fast);
  }

  .stg-slider::-webkit-slider-thumb:hover {
    box-shadow: 0 0 0 5px rgba(59, 130, 246, 0.25);
  }

  .stg-slider-labels {
    display: flex;
    justify-content: space-between;
    font-size: 11px;
    color: var(--text-muted);
    margin-top: 4px;
  }

  .stg-toggle {
    display: flex;
    align-items: center;
    cursor: pointer;
    flex-shrink: 0;
  }

  .stg-toggle input {
    position: absolute;
    width: 1px;
    height: 1px;
    opacity: 0;
    pointer-events: none;
  }

  .stg-toggle-track {
    position: relative;
    display: inline-block;
    width: 36px;
    height: 20px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-full);
    transition: background var(--transition-fast), border-color var(--transition-fast);
  }

  .stg-toggle input:checked ~ .stg-toggle-track {
    background: var(--accent-primary);
    border-color: var(--accent-primary);
  }

  .stg-toggle-thumb {
    position: absolute;
    top: 2px;
    left: 2px;
    width: 14px;
    height: 14px;
    background: var(--text-tertiary);
    border-radius: 50%;
    transition: transform var(--transition-fast), background var(--transition-fast);
  }

  .stg-toggle input:checked ~ .stg-toggle-track .stg-toggle-thumb {
    transform: translateX(16px);
    background: #fff;
  }

  .stg-btn-save {
    flex-shrink: 0;
    padding: 6px 14px;
    font-size: 13px;
    font-weight: 500;
    color: #fff;
    background: var(--accent-primary);
    border: none;
    border-radius: var(--radius-sm);
    cursor: pointer;
    transition: opacity var(--transition-fast);
  }

  .stg-btn-save:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .stg-btn-save:not(:disabled):hover {
    opacity: 0.88;
  }
</style>
