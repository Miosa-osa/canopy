<script lang="ts">
  /**
   * Settings › Analytics — alert configuration + Iris agent settings.
   * Reads /api/v1/analytics/alerts. Posts to create new alerts.
   */
  import {
    createMutation,
    createQuery,
    useQueryClient,
  } from "@tanstack/svelte-query";
  import { Bell, Plus } from "lucide-svelte";
  import { alertsQuery, createAlert } from "$lib/api/queries/analytics.js";
  import type {
    AlertCreate,
    AlertType,
    InsightSeverity,
  } from "$lib/domain/analytics/types.js";

  const qc = useQueryClient();
  const alertsResult = createQuery(alertsQuery());

  // ── Form state ─────────────────────────────────────────────────────────────

  let creating = $state(false);
  let formSlug = $state("");
  let formName = $state("");
  let formMetric = $state("cost_cents");
  let formType = $state<AlertType>("anomaly");
  let formSeverity = $state<InsightSeverity>("medium");
  let formSensitivity = $state(0.8);
  let formDescription = $state("");
  let formError = $state<string | null>(null);

  function resetForm() {
    formSlug = "";
    formName = "";
    formMetric = "cost_cents";
    formType = "anomaly";
    formSeverity = "medium";
    formSensitivity = 0.8;
    formDescription = "";
    formError = null;
  }

  const createMut = createMutation({
    mutationFn: (body: AlertCreate) => createAlert(body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["analytics", "alerts"] });
      creating = false;
      resetForm();
    },
    onError: (err: Error) => {
      formError = err.message;
    },
  });

  function submitCreate(e: Event) {
    e.preventDefault();
    formError = null;
    if (!formSlug.trim() || !formName.trim()) {
      formError = "Slug and name are required.";
      return;
    }
    $createMut.mutate({
      slug: formSlug.trim(),
      name: formName.trim(),
      metric: formMetric,
      type: formType,
      severity: formSeverity,
      sensitivity: formSensitivity,
      description: formDescription.trim() || undefined,
      enabled: true,
      config:
        formType === "anomaly"
          ? { lookback_hours: 168, season: "weekly" }
          : { value: 0, direction: "above", window_seconds: 300 },
      routing: {
        channels: ["#analytics-alerts"],
        cooldown_seconds: 600,
      },
    });
  }

  const alerts = $derived($alertsResult.data ?? []);

  function fmtFireCount(n: number): string {
    return n === 0 ? "never" : `${n}×`;
  }
</script>

<div class="sa-page">
  <header class="sa-header">
    <div>
      <h1 class="sa-title">Analytics</h1>
      <p class="sa-sub">Iris (Analytics Agent) configuration · alert rules</p>
    </div>
    {#if !creating}
      <button
        type="button"
        class="sa-btn sa-btn-primary"
        onclick={() => {
          resetForm();
          creating = true;
        }}
      >
        <Plus size={14} aria-hidden="true" />
        New alert
      </button>
    {/if}
  </header>

  <!-- Iris status card -->
  <section class="sa-card sa-iris">
    <div class="sa-iris-row">
      <span class="sa-iris-emoji" aria-hidden="true">📈</span>
      <div class="sa-iris-body">
        <div class="sa-iris-name">Iris</div>
        <div class="sa-iris-meta">
          Heartbeat every 4h · Budget $50/mo · Posts to #analytics-feed
        </div>
      </div>
      <a href="/agents/analytics-agent" class="sa-iris-link">View persona</a>
    </div>
  </section>

  <!-- Create form -->
  {#if creating}
    <section class="sa-card sa-form">
      <h2 class="sa-form-title">New alert</h2>
      <form onsubmit={submitCreate}>
        <div class="sa-grid">
          <label class="sa-field">
            <span class="sa-label">Slug</span>
            <input
              type="text"
              class="sa-input"
              bind:value={formSlug}
              placeholder="cost-spike-daily"
              required
            />
          </label>

          <label class="sa-field">
            <span class="sa-label">Name</span>
            <input
              type="text"
              class="sa-input"
              bind:value={formName}
              placeholder="Daily cost spike"
              required
            />
          </label>

          <label class="sa-field">
            <span class="sa-label">Metric</span>
            <select class="sa-input" bind:value={formMetric}>
              <option value="cost_cents">Cost (cents)</option>
              <option value="duration_ms">Duration (ms)</option>
              <option value="run_count">Run count</option>
              <option value="error_rate">Error rate</option>
            </select>
          </label>

          <label class="sa-field">
            <span class="sa-label">Type</span>
            <select class="sa-input" bind:value={formType}>
              <option value="anomaly">Anomaly (Prophet)</option>
              <option value="threshold">Threshold (static)</option>
              <option value="composite">Composite</option>
            </select>
          </label>

          <label class="sa-field">
            <span class="sa-label">Severity</span>
            <select class="sa-input" bind:value={formSeverity}>
              <option value="info">Info</option>
              <option value="medium">Medium</option>
              <option value="high">High</option>
              <option value="critical">Critical</option>
            </select>
          </label>

          {#if formType === "anomaly"}
            <label class="sa-field">
              <span class="sa-label">Sensitivity (0–1)</span>
              <input
                type="number"
                step="0.05"
                min="0"
                max="1"
                class="sa-input"
                bind:value={formSensitivity}
              />
            </label>
          {/if}
        </div>

        <label class="sa-field sa-field-wide">
          <span class="sa-label">Description (optional)</span>
          <textarea
            class="sa-input sa-textarea"
            rows="2"
            bind:value={formDescription}
            placeholder="When fired, this alerts on..."
          ></textarea>
        </label>

        {#if formError}
          <p class="sa-error">{formError}</p>
        {/if}

        <div class="sa-actions">
          <button
            type="button"
            class="sa-btn"
            onclick={() => {
              creating = false;
              resetForm();
            }}
            disabled={$createMut.isPending}
          >
            Cancel
          </button>
          <button
            type="submit"
            class="sa-btn sa-btn-primary"
            disabled={$createMut.isPending}
          >
            {$createMut.isPending ? "Creating..." : "Create alert"}
          </button>
        </div>
      </form>
    </section>
  {/if}

  <!-- Alerts list -->
  <section class="sa-card">
    <header class="sa-card-header">
      <h2 class="sa-card-title">
        <Bell size={14} aria-hidden="true" />
        Alerts
      </h2>
      <span class="sa-card-meta">{alerts.length} configured</span>
    </header>

    {#if $alertsResult.isLoading}
      <p class="sa-empty">Loading…</p>
    {:else if alerts.length === 0}
      <p class="sa-empty">
        No alerts yet. Create one to be paged when a metric crosses your
        threshold or anomaly band.
      </p>
    {:else}
      <table class="sa-table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Metric</th>
            <th>Type</th>
            <th>Severity</th>
            <th>Fired</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {#each alerts as alert (alert.id)}
            <tr class:disabled={!alert.enabled}>
              <td>
                <div class="sa-row-name">{alert.name}</div>
                {#if alert.description}
                  <div class="sa-row-desc">{alert.description}</div>
                {/if}
                <div class="sa-row-slug">{alert.slug}</div>
              </td>
              <td>{alert.metric}</td>
              <td>{alert.type}</td>
              <td>
                <span class="sa-sev sa-sev-{alert.severity}">
                  {alert.severity}
                </span>
              </td>
              <td>{fmtFireCount(alert.fireCount)}</td>
              <td>
                {alert.enabled ? "Enabled" : "Disabled"}
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </section>
</div>

<style>
  .sa-page {
    padding: 1rem 2rem;
    max-width: 1000px;
    color: var(--cnp-fg);
  }

  .sa-header {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    margin-bottom: 1.5rem;
    gap: 1rem;
  }

  .sa-title {
    font-family: var(--cnp-font-serif, Georgia, serif);
    font-size: 1.5rem;
    font-weight: 500;
    letter-spacing: -0.02em;
    margin: 0 0 0.25rem 0;
  }

  .sa-sub {
    margin: 0;
    color: var(--cnp-fg-muted);
    font-size: 0.85rem;
  }

  .sa-card {
    background: var(--cnp-bg-elev);
    border: 1px solid var(--cnp-border);
    border-radius: 8px;
    padding: 1.25rem;
    margin-bottom: 1rem;
  }

  .sa-iris {
    background: color-mix(in oklch, var(--cnp-accent) 5%, var(--cnp-bg-elev));
  }

  .sa-iris-row {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .sa-iris-emoji {
    font-size: 1.5rem;
  }

  .sa-iris-body {
    flex: 1;
    min-width: 0;
  }

  .sa-iris-name {
    font-weight: 500;
  }

  .sa-iris-meta {
    color: var(--cnp-fg-muted);
    font-size: 0.8rem;
  }

  .sa-iris-link {
    color: var(--cnp-accent);
    font-size: 0.8rem;
    text-decoration: none;
  }

  .sa-iris-link:hover {
    text-decoration: underline;
  }

  .sa-form-title {
    font-size: 0.95rem;
    font-weight: 500;
    margin: 0 0 1rem 0;
  }

  .sa-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 0.75rem;
    margin-bottom: 0.75rem;
  }

  .sa-field {
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
  }

  .sa-field-wide {
    margin-bottom: 0.75rem;
  }

  .sa-label {
    font-size: 0.75rem;
    color: var(--cnp-fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .sa-input {
    background: var(--cnp-bg);
    border: 1px solid var(--cnp-border);
    border-radius: 4px;
    color: var(--cnp-fg);
    padding: 0.4rem 0.6rem;
    font-size: 0.85rem;
    font-family: inherit;
  }

  .sa-input:focus {
    outline: none;
    border-color: var(--cnp-accent);
  }

  .sa-textarea {
    resize: vertical;
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.8rem;
  }

  .sa-actions {
    display: flex;
    gap: 0.5rem;
    justify-content: flex-end;
    margin-top: 1rem;
  }

  .sa-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.5rem 1rem;
    border: 1px solid var(--cnp-border);
    background: var(--cnp-bg);
    color: var(--cnp-fg);
    border-radius: 4px;
    font-size: 0.85rem;
    cursor: pointer;
    font-family: inherit;
  }

  .sa-btn:hover:not(:disabled) {
    border-color: var(--cnp-fg-muted);
  }

  .sa-btn-primary {
    background: var(--cnp-accent);
    color: var(--cnp-accent-fg, #fff);
    border-color: var(--cnp-accent);
  }

  .sa-btn-primary:hover:not(:disabled) {
    filter: brightness(1.1);
  }

  .sa-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .sa-error {
    color: #dc2626;
    font-size: 0.85rem;
    margin: 0.5rem 0 0 0;
  }

  .sa-card-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 0.75rem;
  }

  .sa-card-title {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.95rem;
    font-weight: 500;
    margin: 0;
  }

  .sa-card-meta {
    font-size: 0.8rem;
    color: var(--cnp-fg-muted);
  }

  .sa-empty {
    color: var(--cnp-fg-muted);
    font-size: 0.85rem;
    margin: 0.5rem 0;
  }

  .sa-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.85rem;
  }

  .sa-table th {
    text-align: left;
    font-weight: 500;
    color: var(--cnp-fg-muted);
    text-transform: uppercase;
    font-size: 0.7rem;
    letter-spacing: 0.04em;
    padding: 0.5rem 0.5rem;
    border-bottom: 1px solid var(--cnp-border);
  }

  .sa-table td {
    padding: 0.6rem 0.5rem;
    border-bottom: 1px solid var(--cnp-border);
    vertical-align: top;
  }

  .sa-table tr.disabled td {
    opacity: 0.5;
  }

  .sa-row-name {
    font-weight: 500;
  }

  .sa-row-desc {
    color: var(--cnp-fg-muted);
    font-size: 0.75rem;
    margin-top: 0.2rem;
  }

  .sa-row-slug {
    color: var(--cnp-fg-muted);
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.7rem;
    margin-top: 0.2rem;
  }

  .sa-sev {
    display: inline-block;
    padding: 0.1rem 0.5rem;
    border-radius: 3px;
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    border: 1px solid var(--cnp-border);
  }

  .sa-sev-info {
    color: var(--cnp-fg-muted);
  }

  .sa-sev-medium {
    color: #d97706;
    border-color: color-mix(in oklch, #d97706 30%, var(--cnp-border));
  }

  .sa-sev-high {
    color: #dc2626;
    border-color: color-mix(in oklch, #dc2626 30%, var(--cnp-border));
  }

  .sa-sev-critical {
    color: #dc2626;
    background: color-mix(in oklch, #dc2626 10%, transparent);
    border-color: color-mix(in oklch, #dc2626 50%, var(--cnp-border));
  }
</style>
