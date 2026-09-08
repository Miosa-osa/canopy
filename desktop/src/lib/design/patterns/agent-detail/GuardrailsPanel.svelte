<script lang="ts">
/**
 * GuardrailsPanel — budget picker, governance rule bindings, per-session limits.
 * CSS prefix: grp- (GuardrailsPanel)
 */
import type { Budget } from '$lib/api/queries/budgets.js';
import type { AgentGuardrails } from '$lib/domain/agents/config.js';
import type { Rule } from '$lib/domain/governance/types.js';

interface Props {
  guardrails: AgentGuardrails;
  budgets: Budget[];
  rules: Rule[];
  budgetsLoading: boolean;
  rulesLoading: boolean;
  onChange: (g: AgentGuardrails) => void;
  isLocalDraft: boolean;
}

let { guardrails, budgets, rules, budgetsLoading, rulesLoading, onChange, isLocalDraft }: Props =
  $props();

function patch(partial: Partial<AgentGuardrails>) {
  onChange({ ...guardrails, ...partial });
}

function toggleRule(id: string) {
  const next = guardrails.rule_ids.includes(id)
    ? guardrails.rule_ids.filter((r) => r !== id)
    : [...guardrails.rule_ids, id];
  patch({ rule_ids: next });
}

function parseOptInt(v: string): number | null {
  const n = parseInt(v, 10);
  return isNaN(n) || n <= 0 ? null : n;
}
</script>

<div class="grp-root">
  {#if isLocalDraft}
    <div class="grp-draft-banner" role="note">
      Local draft — will sync when backend guardrail storage is available.
    </div>
  {/if}

  <!-- Budget -->
  <section class="grp-section">
    <h3 class="grp-section-label">Budget</h3>
    {#if budgetsLoading}
      <p class="grp-hint">Loading budgets…</p>
    {:else if budgets.length === 0}
      <p class="grp-hint">No budgets configured. Create one in Settings → Budgets.</p>
    {:else}
      <div class="grp-field">
        <label class="grp-label" for="grp-budget">Bind budget</label>
        <select
          id="grp-budget"
          class="grp-select"
          value={guardrails.budget_id ?? ''}
          onchange={(e) =>
            patch({ budget_id: (e.currentTarget as HTMLSelectElement).value || null })}
        >
          <option value="">None</option>
          {#each budgets as b (b.id)}
            <option value={b.id}>
              {b.name} — ${b.limit_usd}/{b.period}
            </option>
          {/each}
        </select>
      </div>
    {/if}
  </section>

  <!-- Per-session limits -->
  <section class="grp-section">
    <h3 class="grp-section-label">Per-session limits</h3>
    <div class="grp-row">
      <div class="grp-field">
        <label class="grp-label" for="grp-max-tokens">Max tokens per session</label>
        <input
          id="grp-max-tokens"
          class="grp-input grp-input--mono"
          type="number"
          min="1"
          placeholder="No limit"
          value={guardrails.max_tokens_per_session ?? ''}
          onchange={(e) =>
            patch({
              max_tokens_per_session: parseOptInt((e.currentTarget as HTMLInputElement).value),
            })}
        />
      </div>
      <div class="grp-field">
        <label class="grp-label" for="grp-max-runtime">Max runtime (seconds)</label>
        <input
          id="grp-max-runtime"
          class="grp-input grp-input--mono"
          type="number"
          min="1"
          placeholder="No limit"
          value={guardrails.max_runtime_seconds ?? ''}
          onchange={(e) =>
            patch({
              max_runtime_seconds: parseOptInt((e.currentTarget as HTMLInputElement).value),
            })}
        />
      </div>
    </div>
  </section>

  <!-- Governance rules -->
  <section class="grp-section">
    <h3 class="grp-section-label">Governance rules</h3>
    {#if rulesLoading}
      <p class="grp-hint">Loading rules…</p>
    {:else if rules.length === 0}
      <p class="grp-hint">No governance rules configured. Create rules in Governance.</p>
    {:else}
      <div class="grp-rules" role="list">
        {#each rules as rule (rule.id)}
          {@const bound = guardrails.rule_ids.includes(rule.id)}
          <label class="grp-rule-row" role="listitem">
            <input
              type="checkbox"
              class="grp-checkbox"
              checked={bound}
              onchange={() => toggleRule(rule.id)}
              aria-label="{bound ? 'Unbind' : 'Bind'} rule {rule.name}"
            />
            <div class="grp-rule-body">
              <div class="grp-rule-header">
                <span class="grp-rule-name">{rule.name}</span>
                <span class="grp-rule-action grp-rule-action--{rule.action}">{rule.action}</span>
                {#if !rule.enabled}
                  <span class="grp-rule-disabled">disabled</span>
                {/if}
              </div>
              {#if rule.description}
                <p class="grp-rule-desc">{rule.description}</p>
              {/if}
            </div>
          </label>
        {/each}
      </div>
    {/if}
  </section>
</div>

<style>
  .grp-root {
    display: flex;
    flex-direction: column;
    gap: var(--space-6);
    padding: var(--space-6);
    max-width: 700px;
  }

  .grp-draft-banner {
    padding: var(--space-2) var(--space-4);
    background: color-mix(in oklch, oklch(0.75 0.12 85) 12%, transparent);
    border: 1px solid color-mix(in oklch, oklch(0.75 0.12 85) 30%, transparent);
    border-radius: var(--radius-sm);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: oklch(0.75 0.12 85);
  }

  .grp-section {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .grp-section-label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 500;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--fg-subtle);
    margin: 0;
    padding-bottom: var(--space-1);
    border-bottom: 1px solid var(--border);
  }

  .grp-hint {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
  }

  .grp-row {
    display: flex;
    gap: var(--space-4);
    flex-wrap: wrap;
  }

  .grp-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
    flex: 1;
    min-width: 160px;
  }

  .grp-label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 500;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    color: var(--fg-muted);
  }

  .grp-select,
  .grp-input {
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    width: 100%;
    box-sizing: border-box;
    transition: border-color 0.1s;
  }

  .grp-select:focus,
  .grp-input:focus {
    border-color: var(--cnp-accent, oklch(0.55 0.18 250));
  }

  .grp-select {
    appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%23888' d='M6 8L1 3h10z'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right var(--space-3) center;
    padding-right: calc(var(--space-3) + 20px);
    cursor: pointer;
  }

  .grp-input--mono {
    font-family: var(--font-mono);
    font-size: 12px;
  }

  /* Rules list */
  .grp-rules {
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .grp-rule-row {
    display: flex;
    align-items: flex-start;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-2);
    border-radius: var(--radius-sm);
    cursor: pointer;
    transition: background 0.1s;
  }

  .grp-rule-row:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }

  .grp-checkbox {
    margin-top: 2px;
    flex-shrink: 0;
    accent-color: var(--cnp-accent, oklch(0.55 0.18 250));
    width: 14px;
    height: 14px;
    cursor: pointer;
  }

  .grp-rule-body {
    display: flex;
    flex-direction: column;
    gap: 2px;
    flex: 1;
  }

  .grp-rule-header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-wrap: wrap;
  }

  .grp-rule-name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
  }

  .grp-rule-action {
    padding: 1px 6px;
    border-radius: 9999px;
    font-family: var(--font-mono);
    font-size: 10px;
    font-weight: 600;
  }

  .grp-rule-action--block {
    background: color-mix(in oklch, var(--destructive, oklch(0.55 0.22 25)) 12%, transparent);
    color: var(--destructive, oklch(0.55 0.22 25));
  }

  .grp-rule-action--require_approval {
    background: color-mix(in oklch, oklch(0.7 0.15 55) 12%, transparent);
    color: oklch(0.7 0.15 55);
  }

  .grp-rule-action--warn {
    background: color-mix(in oklch, oklch(0.75 0.12 85) 12%, transparent);
    color: oklch(0.75 0.12 85);
  }

  .grp-rule-action--log {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg-muted);
  }

  .grp-rule-disabled {
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .grp-rule-desc {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    margin: 0;
    line-height: 1.5;
  }
</style>
