<script lang="ts">
  /**
   * Settings › Schedule — Scheduling Agent settings + spec defaults.
   * Reads /api/v1/schedule/specs. Surfaces overlap policy + miss alerting defaults.
   * CSS prefix: ss-
   */
  import {
    createMutation,
    createQuery,
    useQueryClient,
  } from "@tanstack/svelte-query";
  import { Calendar, Plus } from "lucide-svelte";
  import {
    archiveSpec,
    createSpec,
    pauseSpec,
    specsQuery,
    unpauseSpec,
  } from "$lib/api/queries/schedule.js";
  import type {
    OverlapPolicy,
    SpecCreate,
  } from "$lib/domain/schedule/types.js";

  const qc = useQueryClient();
  const specsResult = createQuery(specsQuery());

  // ── Form state ─────────────────────────────────────────────────────────────

  let creating = $state(false);
  let formSlug = $state("");
  let formName = $state("");
  let formCron = $state("0 9 * * *");
  let formTimezone = $state("UTC");
  let formOverlapPolicy = $state<OverlapPolicy>("skip");
  let formJitterSeconds = $state(0);
  let formGraceSeconds = $state(30);
  let formFailureThreshold = $state(5);
  let formAgentSlug = $state("");
  let formError = $state<string | null>(null);

  function resetForm() {
    formSlug = "";
    formName = "";
    formCron = "0 9 * * *";
    formTimezone = "UTC";
    formOverlapPolicy = "skip";
    formJitterSeconds = 0;
    formGraceSeconds = 30;
    formFailureThreshold = 5;
    formAgentSlug = "";
    formError = null;
  }

  const createMut = createMutation({
    mutationFn: (body: SpecCreate) => createSpec(body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["schedule", "specs"] });
      creating = false;
      resetForm();
    },
    onError: (err: Error) => {
      formError = err.message;
    },
  });

  const pauseMut = createMutation({
    mutationFn: ({ slug }: { slug: string }) => pauseSpec(slug, "manual"),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["schedule", "specs"] });
    },
  });

  const unpauseMut = createMutation({
    mutationFn: ({ slug }: { slug: string }) => unpauseSpec(slug),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["schedule", "specs"] });
    },
  });

  const archiveMut = createMutation({
    mutationFn: ({ slug }: { slug: string }) => archiveSpec(slug),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["schedule", "specs"] });
    },
  });

  function submitCreate(e: Event) {
    e.preventDefault();
    formError = null;
    if (!formSlug.trim() || !formName.trim()) {
      formError = "Slug and name are required.";
      return;
    }
    if (!formCron.trim()) {
      formError = "Cron expression is required.";
      return;
    }
    $createMut.mutate({
      slug: formSlug.trim(),
      name: formName.trim(),
      timezone: formTimezone,
      overlapPolicy: formOverlapPolicy,
      jitterSeconds: formJitterSeconds,
      graceSeconds: formGraceSeconds,
      failureThreshold: formFailureThreshold,
      agentSlug: formAgentSlug.trim() || undefined,
      model: { crons: [formCron.trim()] },
    });
  }

  const specs = $derived($specsResult.data ?? []);
</script>

<div class="ss-page">
  <header class="ss-header">
    <div>
      <h1 class="ss-title">Schedule</h1>
      <p class="ss-sub">Scheduling Agent configuration · spec defaults · overlap policy</p>
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
        New schedule
      </button>
    {/if}
  </header>

  <!-- Scheduling Agent status card -->
  <section class="ss-card ss-agent">
    <div class="ss-agent-row">
      <span class="ss-agent-emoji" aria-hidden="true">🕰️</span>
      <div class="ss-agent-body">
        <div class="ss-agent-name">Scheduling Agent</div>
        <div class="ss-agent-meta">
          Master tick every minute · Budget $15/mo · UTC clock · System agent
        </div>
      </div>
      <a href="/agents/scheduling-agent" class="ss-agent-link">View persona</a>
    </div>
  </section>

  <!-- Defaults card (read-only documentation of platform defaults) -->
  <section class="ss-card">
    <h2 class="ss-card-title">Defaults</h2>
    <dl class="ss-defaults">
      <div class="ss-default">
        <dt>Overlap policy</dt>
        <dd>
          <code>skip</code> — drop the new tick if a previous run is still in flight.
          Override per-spec for routines that must always run.
        </dd>
      </div>
      <div class="ss-default">
        <dt>Grace seconds</dt>
        <dd>
          <code>30</code> — fires arriving within 30s of the scheduled window
          are still considered on-time. Beyond grace + 5× → marked late.
        </dd>
      </div>
      <div class="ss-default">
        <dt>Failure threshold</dt>
        <dd>
          <code>5</code> consecutive failures → spec auto-paused, circuit-breaker
          incident opened. Requires explicit acknowledge to resume.
        </dd>
      </div>
      <div class="ss-default">
        <dt>Jitter seconds</dt>
        <dd>
          <code>0</code> — disabled by default. Enable per-spec to spread
          simultaneous fires and prevent thundering-herd at minute boundaries.
        </dd>
      </div>
      <div class="ss-default">
        <dt>Backfill</dt>
        <dd>
          Always gated. <code>dry_run: true</code> by default; second
          invocation required to apply. Cost preview shown before execution.
        </dd>
      </div>
    </dl>
  </section>

  <!-- Create form -->
  {#if creating}
    <section class="ss-card ss-form">
      <h2 class="ss-form-title">New schedule</h2>
      <form onsubmit={submitCreate}>
        <div class="ss-grid">
          <label class="ss-field">
            <span class="ss-label">Slug</span>
            <input
              type="text"
              class="ss-input"
              bind:value={formSlug}
              placeholder="daily-digest"
              required
            />
          </label>

          <label class="ss-field">
            <span class="ss-label">Name</span>
            <input
              type="text"
              class="ss-input"
              bind:value={formName}
              placeholder="Daily digest"
              required
            />
          </label>

          <label class="ss-field ss-field-wide">
            <span class="ss-label">Cron expression</span>
            <input
              type="text"
              class="ss-input ss-input-mono"
              bind:value={formCron}
              placeholder="0 9 * * *"
              required
            />
            <span class="ss-hint">5-field POSIX cron. Need help? <a href="https://crontab.guru" target="_blank" rel="noopener">crontab.guru</a></span>
          </label>

          <label class="ss-field">
            <span class="ss-label">Timezone</span>
            <input
              type="text"
              class="ss-input"
              bind:value={formTimezone}
              placeholder="UTC"
            />
          </label>

          <label class="ss-field">
            <span class="ss-label">Agent slug (optional)</span>
            <input
              type="text"
              class="ss-input"
              bind:value={formAgentSlug}
              placeholder="analytics-agent"
            />
          </label>

          <label class="ss-field">
            <span class="ss-label">Overlap policy</span>
            <select class="ss-input" bind:value={formOverlapPolicy}>
              <option value="skip">Skip (default)</option>
              <option value="buffer_one">Buffer one</option>
              <option value="cancel_other">Cancel other</option>
              <option value="terminate_other">Terminate other</option>
            </select>
          </label>

          <label class="ss-field">
            <span class="ss-label">Jitter seconds</span>
            <input
              type="number"
              min="0"
              max="3600"
              class="ss-input"
              bind:value={formJitterSeconds}
            />
          </label>

          <label class="ss-field">
            <span class="ss-label">Grace seconds</span>
            <input
              type="number"
              min="0"
              max="86400"
              class="ss-input"
              bind:value={formGraceSeconds}
            />
          </label>

          <label class="ss-field">
            <span class="ss-label">Failure threshold</span>
            <input
              type="number"
              min="1"
              max="100"
              class="ss-input"
              bind:value={formFailureThreshold}
            />
          </label>
        </div>

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
            {$createMut.isPending ? "Creating..." : "Create schedule"}
          </button>
        </div>
      </form>
    </section>
  {/if}

  <!-- Specs list -->
  <section class="ss-card">
    <header class="ss-card-header">
      <h2 class="ss-card-title">
        <Calendar size={14} aria-hidden="true" />
        Schedule specs
      </h2>
      <span class="ss-card-meta">{specs.length} configured</span>
    </header>

    {#if $specsResult.isLoading}
      <p class="ss-empty">Loading…</p>
    {:else if specs.length === 0}
      <p class="ss-empty">
        No schedule specs yet. Create one to start firing heartbeats on a cron tick.
      </p>
    {:else}
      <table class="ss-table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Agent</th>
            <th>Overlap</th>
            <th>Threshold</th>
            <th>Status</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each specs as spec (spec.id)}
            <tr class:disabled={spec.status === "archived"}>
              <td>
                <div class="ss-row-name">{spec.name}</div>
                <div class="ss-row-slug">{spec.slug}</div>
              </td>
              <td>{spec.agentSlug ?? "—"}</td>
              <td><code>{spec.overlapPolicy}</code></td>
              <td>{spec.failureThreshold}</td>
              <td>
                <span class="ss-status ss-status-{spec.status}">
                  {spec.status}
                </span>
              </td>
              <td>
                <div class="ss-row-actions">
                  {#if spec.status === "paused"}
                    <button
                      type="button"
                      class="ss-row-btn"
                      onclick={() => $unpauseMut.mutate({ slug: spec.slug })}
                      disabled={$unpauseMut.isPending}
                    >
                      Unpause
                    </button>
                  {:else if spec.status === "active"}
                    <button
                      type="button"
                      class="ss-row-btn"
                      onclick={() => $pauseMut.mutate({ slug: spec.slug })}
                      disabled={$pauseMut.isPending}
                    >
                      Pause
                    </button>
                  {/if}
                  <button
                    type="button"
                    class="ss-row-btn ss-row-btn-danger"
                    onclick={() => $archiveMut.mutate({ slug: spec.slug })}
                    disabled={$archiveMut.isPending || spec.status === "archived"}
                  >
                    Archive
                  </button>
                </div>
              </td>
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

  .ss-agent {
    background: color-mix(in oklch, var(--cnp-accent) 5%, var(--cnp-bg-elev));
  }

  .ss-agent-row {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .ss-agent-emoji {
    font-size: 1.5rem;
  }

  .ss-agent-body {
    flex: 1;
    min-width: 0;
  }

  .ss-agent-name {
    font-weight: 500;
  }

  .ss-agent-meta {
    color: var(--cnp-fg-muted);
    font-size: 0.8rem;
  }

  .ss-agent-link {
    color: var(--cnp-accent);
    font-size: 0.8rem;
    text-decoration: none;
  }

  .ss-agent-link:hover {
    text-decoration: underline;
  }

  .ss-defaults {
    margin: 0;
    display: grid;
    gap: 0.75rem;
  }

  .ss-default {
    display: grid;
    grid-template-columns: 180px 1fr;
    gap: 1rem;
    align-items: baseline;
  }

  .ss-default dt {
    font-size: 0.8rem;
    color: var(--cnp-fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .ss-default dd {
    margin: 0;
    font-size: 0.85rem;
    line-height: 1.5;
  }

  .ss-default code {
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.8rem;
    background: var(--cnp-bg);
    padding: 0.05rem 0.3rem;
    border-radius: 3px;
    border: 1px solid var(--cnp-border);
  }

  .ss-form-title {
    font-size: 0.95rem;
    font-weight: 500;
    margin: 0 0 1rem 0;
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
    grid-column: 1 / -1;
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

  .ss-input-mono {
    font-family: var(--cnp-font-mono, monospace);
  }

  .ss-input:focus {
    outline: none;
    border-color: var(--cnp-accent);
  }

  .ss-hint {
    font-size: 0.7rem;
    color: var(--cnp-fg-muted);
  }

  .ss-hint a {
    color: var(--cnp-accent);
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
    background: var(--cnp-accent);
    color: var(--cnp-accent-fg, #fff);
    border-color: var(--cnp-accent);
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

  .ss-row-slug {
    color: var(--cnp-fg-muted);
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.7rem;
    margin-top: 0.2rem;
  }

  .ss-status {
    display: inline-block;
    padding: 0.1rem 0.5rem;
    border-radius: 3px;
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    border: 1px solid var(--cnp-border);
  }

  .ss-status-active {
    color: #059669;
    border-color: color-mix(in oklch, #059669 30%, var(--cnp-border));
  }

  .ss-status-paused {
    color: #d97706;
    border-color: color-mix(in oklch, #d97706 30%, var(--cnp-border));
  }

  .ss-status-archived {
    color: var(--cnp-fg-muted);
  }

  .ss-row-actions {
    display: flex;
    gap: 0.3rem;
  }

  .ss-row-btn {
    background: transparent;
    border: 1px solid var(--cnp-border);
    border-radius: 4px;
    color: var(--cnp-fg-muted);
    padding: 0.2rem 0.5rem;
    font-size: 0.75rem;
    cursor: pointer;
    font-family: inherit;
  }

  .ss-row-btn:hover:not(:disabled) {
    color: var(--cnp-fg);
    border-color: var(--cnp-fg-muted);
  }

  .ss-row-btn-danger:hover:not(:disabled) {
    color: #dc2626;
    border-color: color-mix(in oklch, #dc2626 50%, var(--cnp-border));
  }

  .ss-row-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
</style>
