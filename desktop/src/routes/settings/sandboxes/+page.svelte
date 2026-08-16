<script lang="ts">
  /**
   * Settings › Sandboxes — TTL defaults, snapshot retention, alert config.
   * Reads /api/v1/sandboxes-ng/alerts. Posts to create new alerts.
   */
  import {
    createMutation,
    createQuery,
    useQueryClient,
  } from "@tanstack/svelte-query";
  import { Bell, Plus } from "lucide-svelte";
  import {
    sandboxAlertsQuery,
    createSandboxAlert,
  } from "$lib/api/queries/sandboxes_ng.js";
  import type {
    AlertSeverity,
    AlertType,
    SandboxAlertCreate,
  } from "$lib/domain/sandboxes_ng/types.js";

  const qc = useQueryClient();
  const alertsResult = createQuery(sandboxAlertsQuery());

  // ── TTL defaults (local-only, no backend write yet) ────────────────────────

  let ttlWallSeconds = $state(3600);
  let ttlIdleSeconds = $state(900);
  let ttlArchiveSeconds = $state(7 * 24 * 3600);

  // ── Snapshot retention (display only — defaults are server-side) ───────────

  const RETENTION_HINTS = [
    { kind: "filesystem", retention: "indefinite" },
    { kind: "directory", retention: "30 days" },
    { kind: "memory", retention: "7 days" },
  ];

  // ── Form state ─────────────────────────────────────────────────────────────

  let creating = $state(false);
  let formSlug = $state("");
  let formName = $state("");
  let formMetric = $state("public_port_count");
  let formType = $state<AlertType>("threshold");
  let formSeverity = $state<AlertSeverity>("medium");
  let formDescription = $state("");
  let formError = $state<string | null>(null);

  function resetForm() {
    formSlug = "";
    formName = "";
    formMetric = "public_port_count";
    formType = "threshold";
    formSeverity = "medium";
    formDescription = "";
    formError = null;
  }

  const createMut = createMutation({
    mutationFn: (body: SandboxAlertCreate) => createSandboxAlert(body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["sandboxes-ng", "alerts"] });
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
      description: formDescription.trim() || undefined,
      enabled: true,
      config:
        formType === "threshold"
          ? { value: 0, direction: "above", window_seconds: 300 }
          : { conditions: [] },
      routing: {
        channels: ["#sandboxes-feed"],
        cooldown_seconds: 600,
      },
    });
  }

  const alerts = $derived($alertsResult.data ?? []);

  function fmtFireCount(n: number): string {
    return n === 0 ? "never" : `${n}×`;
  }

  function fmtSeconds(n: number): string {
    if (n < 60) return `${n}s`;
    if (n < 3600) return `${Math.round(n / 60)}m`;
    if (n < 86400) return `${Math.round(n / 3600)}h`;
    return `${Math.round(n / 86400)}d`;
  }
</script>

<div class="ss-page">
  <header class="ss-header">
    <div>
      <h1 class="ss-title">Sandboxes</h1>
      <p class="ss-sub">Sandbox Operator configuration · TTL defaults · alert rules</p>
    </div>
    {#if !creating}
      <button
        type="button"
        class="ss-btn ss-btn-primary"
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

  <!-- Operator status card -->
  <section class="ss-card ss-operator">
    <div class="ss-operator-row">
      <span class="ss-operator-emoji" aria-hidden="true">📦</span>
      <div class="ss-operator-body">
        <div class="ss-operator-name">Sandbox Operator</div>
        <div class="ss-operator-meta">
          Heartbeat every 2 min · Budget $50/mo · Posts to #sandboxes-feed
        </div>
      </div>
      <a href="/agents/sandbox-operator" class="ss-operator-link">View persona</a>
    </div>
  </section>

  <!-- TTL defaults -->
  <section class="ss-card">
    <header class="ss-card-header">
      <h2 class="ss-card-title">TTL defaults</h2>
      <span class="ss-card-meta">applied at provision time</span>
    </header>

    <div class="ss-grid">
      <label class="ss-field">
        <span class="ss-label">Wall-time TTL ({fmtSeconds(ttlWallSeconds)})</span>
        <input
          type="number"
          min="60"
          step="60"
          class="ss-input"
          bind:value={ttlWallSeconds}
        />
      </label>

      <label class="ss-field">
        <span class="ss-label">Idle stop ({fmtSeconds(ttlIdleSeconds)})</span>
        <input
          type="number"
          min="60"
          step="60"
          class="ss-input"
          bind:value={ttlIdleSeconds}
        />
      </label>

      <label class="ss-field">
        <span class="ss-label">Archive after ({fmtSeconds(ttlArchiveSeconds)})</span>
        <input
          type="number"
          min="3600"
          step="3600"
          class="ss-input"
          bind:value={ttlArchiveSeconds}
        />
      </label>
    </div>

    <p class="ss-hint">
      Three nested timers govern sandbox cost. Wall-time is the absolute
      ceiling. Idle stop pauses inactive sandboxes. Archive moves long-paused
      sandboxes to cold storage.
    </p>
  </section>

  <!-- Snapshot retention -->
  <section class="ss-card">
    <header class="ss-card-header">
      <h2 class="ss-card-title">Snapshot retention</h2>
      <span class="ss-card-meta">expired snapshots reaped at heartbeat</span>
    </header>

    <ul class="ss-retention-list" role="list">
      {#each RETENTION_HINTS as hint (hint.kind)}
        <li class="ss-retention-row">
          <span class="ss-retention-kind">{hint.kind}</span>
          <span class="ss-retention-value">{hint.retention}</span>
        </li>
      {/each}
    </ul>
  </section>

  <!-- Create form -->
  {#if creating}
    <section class="ss-card ss-form">
      <h2 class="ss-form-title">New alert</h2>
      <form onsubmit={submitCreate}>
        <div class="ss-grid">
          <label class="ss-field">
            <span class="ss-label">Slug</span>
            <input
              type="text"
              class="ss-input"
              bind:value={formSlug}
              placeholder="public-port-count-high"
              required
            />
          </label>

          <label class="ss-field">
            <span class="ss-label">Name</span>
            <input
              type="text"
              class="ss-input"
              bind:value={formName}
              placeholder="Too many public ports"
              required
            />
          </label>

          <label class="ss-field">
            <span class="ss-label">Metric</span>
            <select class="ss-input" bind:value={formMetric}>
              <option value="sandbox_count">Sandbox count</option>
              <option value="public_port_count">Public port count</option>
              <option value="orphan_sandbox_count">Orphan sandbox count</option>
              <option value="snapshot_storage_bytes">Snapshot storage (bytes)</option>
              <option value="compute_cost_cents">Compute cost (cents)</option>
              <option value="error_state_count">Error-state count</option>
            </select>
          </label>

          <label class="ss-field">
            <span class="ss-label">Type</span>
            <select class="ss-input" bind:value={formType}>
              <option value="threshold">Threshold</option>
              <option value="composite">Composite</option>
            </select>
          </label>

          <label class="ss-field">
            <span class="ss-label">Severity</span>
            <select class="ss-input" bind:value={formSeverity}>
              <option value="info">Info</option>
              <option value="medium">Medium</option>
              <option value="high">High</option>
              <option value="critical">Critical</option>
            </select>
          </label>
        </div>

        <label class="ss-field ss-field-wide">
          <span class="ss-label">Description (optional)</span>
          <textarea
            class="ss-input ss-textarea"
            rows="2"
            bind:value={formDescription}
            placeholder="When fired, this alerts on..."
          ></textarea>
        </label>

        {#if formError}
          <p class="ss-error">{formError}</p>
        {/if}

        <div class="ss-actions">
          <button
            type="button"
            class="ss-btn"
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
            class="ss-btn ss-btn-primary"
            disabled={$createMut.isPending}
          >
            {$createMut.isPending ? "Creating..." : "Create alert"}
          </button>
        </div>
      </form>
    </section>
  {/if}

  <!-- Alerts list -->
  <section class="ss-card">
    <header class="ss-card-header">
      <h2 class="ss-card-title">
        <Bell size={14} aria-hidden="true" />
        Alerts
      </h2>
      <span class="ss-card-meta">{alerts.length} configured</span>
    </header>

    {#if $alertsResult.isLoading}
      <p class="ss-empty">Loading…</p>
    {:else if alerts.length === 0}
      <p class="ss-empty">
        No alerts yet. Create one to be paged when a metric crosses your
        threshold (e.g. too many public ports, orphan sandboxes, or compute
        cost spike).
      </p>
    {:else}
      <table class="ss-table">
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
                <div class="ss-row-name">{alert.name}</div>
                {#if alert.description}
                  <div class="ss-row-desc">{alert.description}</div>
                {/if}
                <div class="ss-row-slug">{alert.slug}</div>
              </td>
              <td>{alert.metric}</td>
              <td>{alert.type}</td>
              <td>
                <span class="ss-sev ss-sev-{alert.severity}">
                  {alert.severity}
                </span>
              </td>
              <td>{fmtFireCount(alert.fireCount)}</td>
              <td>{alert.enabled ? "Enabled" : "Disabled"}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </section>
</div>

<style>
  .ss-page {
    padding: 1rem 2rem;
    max-width: 1000px;
    color: var(--cnp-fg);
  }

  .ss-header {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    margin-bottom: 1.5rem;
    gap: 1rem;
  }

  .ss-title {
    font-family: var(--cnp-font-serif, Georgia, serif);
    font-size: 1.5rem;
    font-weight: 500;
    letter-spacing: -0.02em;
    margin: 0 0 0.25rem 0;
  }

  .ss-sub {
    margin: 0;
    color: var(--cnp-fg-muted);
    font-size: 0.85rem;
  }

  .ss-card {
    background: var(--cnp-bg-elev);
    border: 1px solid var(--cnp-border);
    border-radius: 8px;
    padding: 1.25rem;
    margin-bottom: 1rem;
  }

  .ss-operator {
    background: color-mix(in oklch, oklch(0.65 0.18 250) 5%, var(--cnp-bg-elev));
  }

  .ss-operator-row {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .ss-operator-emoji {
    font-size: 1.5rem;
  }

  .ss-operator-body {
    flex: 1;
    min-width: 0;
  }

  .ss-operator-name {
    font-weight: 500;
  }

  .ss-operator-meta {
    color: var(--cnp-fg-muted);
    font-size: 0.8rem;
  }

  .ss-operator-link {
    color: oklch(0.65 0.18 250);
    font-size: 0.8rem;
    text-decoration: none;
  }

  .ss-operator-link:hover {
    text-decoration: underline;
  }

  .ss-card-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 0.75rem;
  }

  .ss-card-title {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.95rem;
    font-weight: 500;
    margin: 0;
  }

  .ss-card-meta {
    font-size: 0.8rem;
    color: var(--cnp-fg-muted);
  }

  .ss-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 0.75rem;
    margin-bottom: 0.75rem;
  }

  .ss-field {
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
  }

  .ss-field-wide {
    margin-bottom: 0.75rem;
  }

  .ss-label {
    font-size: 0.75rem;
    color: var(--cnp-fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .ss-input {
    background: var(--cnp-bg);
    border: 1px solid var(--cnp-border);
    border-radius: 4px;
    color: var(--cnp-fg);
    padding: 0.4rem 0.6rem;
    font-size: 0.85rem;
    font-family: inherit;
  }

  .ss-input:focus {
    outline: none;
    border-color: oklch(0.65 0.18 250);
  }

  .ss-textarea {
    resize: vertical;
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.8rem;
  }

  .ss-hint {
    color: var(--cnp-fg-muted);
    font-size: 0.75rem;
    margin: 0.5rem 0 0 0;
  }

  .ss-retention-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
  }

  .ss-retention-row {
    display: flex;
    justify-content: space-between;
    padding: 0.5rem 0.75rem;
    background: var(--cnp-bg);
    border: 1px solid var(--cnp-border);
    border-radius: 4px;
    font-size: 0.85rem;
  }

  .ss-retention-kind {
    text-transform: uppercase;
    font-size: 0.75rem;
    letter-spacing: 0.04em;
    color: var(--cnp-fg-muted);
  }

  .ss-retention-value {
    font-feature-settings: "tnum";
  }

  .ss-actions {
    display: flex;
    gap: 0.5rem;
    justify-content: flex-end;
    margin-top: 1rem;
  }

  .ss-btn {
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

  .ss-btn:hover:not(:disabled) {
    border-color: var(--cnp-fg-muted);
  }

  .ss-btn-primary {
    background: oklch(0.65 0.18 250);
    color: #fff;
    border-color: oklch(0.65 0.18 250);
  }

  .ss-btn-primary:hover:not(:disabled) {
    filter: brightness(1.1);
  }

  .ss-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .ss-error {
    color: #dc2626;
    font-size: 0.85rem;
    margin: 0.5rem 0 0 0;
  }

  .ss-form-title {
    font-size: 0.95rem;
    font-weight: 500;
    margin: 0 0 1rem 0;
  }

  .ss-empty {
    color: var(--cnp-fg-muted);
    font-size: 0.85rem;
    margin: 0.5rem 0;
  }

  .ss-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.85rem;
  }

  .ss-table th {
    text-align: left;
    font-weight: 500;
    color: var(--cnp-fg-muted);
    text-transform: uppercase;
    font-size: 0.7rem;
    letter-spacing: 0.04em;
    padding: 0.5rem 0.5rem;
    border-bottom: 1px solid var(--cnp-border);
  }

  .ss-table td {
    padding: 0.6rem 0.5rem;
    border-bottom: 1px solid var(--cnp-border);
    vertical-align: top;
  }

  .ss-table tr.disabled td {
    opacity: 0.5;
  }

  .ss-row-name {
    font-weight: 500;
  }

  .ss-row-desc {
    color: var(--cnp-fg-muted);
    font-size: 0.75rem;
    margin-top: 0.2rem;
  }

  .ss-row-slug {
    color: var(--cnp-fg-muted);
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.7rem;
    margin-top: 0.2rem;
  }

  .ss-sev {
    display: inline-block;
    padding: 0.1rem 0.5rem;
    border-radius: 3px;
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    border: 1px solid var(--cnp-border);
  }

  .ss-sev-info {
    color: var(--cnp-fg-muted);
  }

  .ss-sev-medium {
    color: #d97706;
    border-color: color-mix(in oklch, #d97706 30%, var(--cnp-border));
  }

  .ss-sev-high {
    color: #dc2626;
    border-color: color-mix(in oklch, #dc2626 30%, var(--cnp-border));
  }

  .ss-sev-critical {
    color: #dc2626;
    background: color-mix(in oklch, #dc2626 10%, transparent);
    border-color: color-mix(in oklch, #dc2626 50%, var(--cnp-border));
  }
</style>
