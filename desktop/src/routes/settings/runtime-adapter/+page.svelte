<script lang="ts">
  /**
   * Settings › Runtime Adapter — runtime selection policies, default model
   * per role, checkpoint retention, hot-swap rules.
   *
   * This page is *additive* to /settings/runtimes (which is the raw runtime
   * registry / preflight UI). This page operates the *agent* layer on top of
   * that registry — policies, role bindings, retention, swap behaviour.
   */
  import { createMutation, createQuery, useQueryClient } from "@tanstack/svelte-query";
  import { Plug, Plus, RotateCcw } from "lucide-svelte";
  import { assignRole, rolesQuery } from "$lib/api/queries/runtime_adapter.js";
  import {
    MODEL_ROLES,
    type CheckpointRetention,
    type HotSwapRule,
    type ModelRoleName,
    type RoleAssignmentCreate,
    type RuntimeSelectionPolicy,
  } from "$lib/domain/runtime_adapter/types.js";

  const qc = useQueryClient();
  const rolesResult = createQuery(rolesQuery());

  // ── Local-state policy form (persisted via runtime config in v0.2) ───────

  let selectionPolicy = $state<RuntimeSelectionPolicy>("auto-balanced");
  let checkpointRetention = $state<CheckpointRetention>("30-days");
  let hotSwapRule = $state<HotSwapRule>("always-confirm");

  // ── Role assignment form ─────────────────────────────────────────────────

  let creating = $state(false);
  let formRuntime = $state("");
  let formModel = $state("");
  let formRole = $state<ModelRoleName>("chat");
  let formDefault = $state(true);
  let formError = $state<string | null>(null);

  function resetForm() {
    formRuntime = "";
    formModel = "";
    formRole = "chat";
    formDefault = true;
    formError = null;
  }

  const assignMut = createMutation({
    mutationFn: (body: RoleAssignmentCreate) => assignRole(body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["runtime-adapter", "roles"] });
      creating = false;
      resetForm();
    },
    onError: (err: Error) => {
      formError = err.message;
    },
  });

  function submitAssign(e: Event) {
    e.preventDefault();
    formError = null;
    if (!formRuntime.trim() || !formModel.trim()) {
      formError = "Runtime and model are required.";
      return;
    }
    $assignMut.mutate({
      runtime: formRuntime.trim(),
      model: formModel.trim(),
      role: formRole,
      defaultForRole: formDefault,
    });
  }

  const roles = $derived($rolesResult.data ?? []);

  // Per-role defaults computed from the assignment list
  const defaultsByRole = $derived(
    Object.fromEntries(
      MODEL_ROLES.map((role) => [
        role,
        roles.find((r) => r.role === role && r.defaultForRole) ?? null,
      ]),
    ) as Record<ModelRoleName, (typeof roles)[number] | null>,
  );
</script>

<div class="ra-page">
  <header class="ra-header">
    <div>
      <h1 class="ra-title">Runtime Adapter</h1>
      <p class="ra-sub">
        Selection policy · model defaults per role · checkpoint retention · hot-swap behaviour
      </p>
    </div>
    {#if !creating}
      <button
        type="button"
        class="ra-btn ra-btn-primary"
        onclick={() => {
          resetForm();
          creating = true;
        }}
      >
        <Plus size={14} aria-hidden="true" />
        Assign role
      </button>
    {/if}
  </header>

  <!-- Agent status card -->
  <section class="ra-card ra-agent">
    <div class="ra-agent-row">
      <span class="ra-agent-emoji" aria-hidden="true">🔌</span>
      <div class="ra-agent-body">
        <div class="ra-agent-name">Runtime Adapter</div>
        <div class="ra-agent-meta">
          Heartbeat every 6h · Budget $50/mo · 11 runtimes under management
        </div>
      </div>
      <a href="/agents/runtime-adapter-agent" class="ra-agent-link">View persona</a>
    </div>
  </section>

  <!-- Selection policy -->
  <section class="ra-card">
    <header class="ra-card-header">
      <h2 class="ra-card-title">Runtime selection policy</h2>
      <span class="ra-local-badge">local only — backend endpoint coming soon</span>
    </header>
    <p class="ra-help">
      How the agent picks a runtime when a session is composed without one.
    </p>
    <div class="ra-grid">
      <label class="ra-field">
        <span class="ra-label">Policy</span>
        <select class="ra-input" bind:value={selectionPolicy}>
          <option value="manual">Manual (always ask)</option>
          <option value="auto-cheapest">Auto: cheapest first</option>
          <option value="auto-fastest">Auto: fastest first</option>
          <option value="auto-balanced">Auto: balanced cost / quota / history</option>
        </select>
      </label>
    </div>
  </section>

  <!-- Default model per role -->
  <section class="ra-card">
    <header class="ra-card-header">
      <h2 class="ra-card-title">
        <Plug size={14} aria-hidden="true" />
        Default model per role
      </h2>
      <span class="ra-card-meta">{roles.length} assignment{roles.length === 1 ? "" : "s"}</span>
    </header>

    {#if $rolesResult.isLoading}
      <p class="ra-empty">Loading…</p>
    {:else}
      <table class="ra-table">
        <thead>
          <tr>
            <th>Role</th>
            <th>Default runtime</th>
            <th>Default model</th>
            <th>Workspace</th>
          </tr>
        </thead>
        <tbody>
          {#each MODEL_ROLES as role (role)}
            {@const d = defaultsByRole[role]}
            <tr>
              <td><span class="ra-role">{role}</span></td>
              <td>{d?.runtime ?? "—"}</td>
              <td class="ra-mono">{d?.model ?? "—"}</td>
              <td>{d?.workspaceSlug ?? "global"}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </section>

  <!-- Assignment form -->
  {#if creating}
    <section class="ra-card ra-form">
      <h2 class="ra-form-title">Assign role</h2>
      <form onsubmit={submitAssign}>
        <div class="ra-grid">
          <label class="ra-field">
            <span class="ra-label">Runtime</span>
            <input
              type="text"
              class="ra-input"
              bind:value={formRuntime}
              placeholder="claude-local"
              required
            />
          </label>

          <label class="ra-field">
            <span class="ra-label">Model</span>
            <input
              type="text"
              class="ra-input"
              bind:value={formModel}
              placeholder="claude-sonnet-4-7"
              required
            />
          </label>

          <label class="ra-field">
            <span class="ra-label">Role</span>
            <select class="ra-input" bind:value={formRole}>
              {#each MODEL_ROLES as role}
                <option value={role}>{role}</option>
              {/each}
            </select>
          </label>

          <label class="ra-field ra-field-checkbox">
            <input type="checkbox" bind:checked={formDefault} />
            <span class="ra-label">Mark as default for this role</span>
          </label>
        </div>

        {#if formError}
          <p class="ra-error">{formError}</p>
        {/if}

        <div class="ra-actions">
          <button
            type="button"
            class="ra-btn"
            onclick={() => {
              creating = false;
              resetForm();
            }}
            disabled={$assignMut.isPending}
          >
            Cancel
          </button>
          <button
            type="submit"
            class="ra-btn ra-btn-primary"
            disabled={$assignMut.isPending}
          >
            {$assignMut.isPending ? "Saving…" : "Assign"}
          </button>
        </div>
      </form>
    </section>
  {/if}

  <!-- Checkpoint retention -->
  <section class="ra-card">
    <header class="ra-card-header">
      <h2 class="ra-card-title">
        <RotateCcw size={14} aria-hidden="true" />
        Checkpoint retention
      </h2>
      <span class="ra-local-badge">local only — backend endpoint coming soon</span>
    </header>
    <p class="ra-help">
      Checkpoints capture code + transcript + agent memory. Older entries are pruned.
    </p>
    <div class="ra-grid">
      <label class="ra-field">
        <span class="ra-label">Retention</span>
        <select class="ra-input" bind:value={checkpointRetention}>
          <option value="session">Until session ends</option>
          <option value="7-days">7 days</option>
          <option value="30-days">30 days</option>
          <option value="forever">Forever</option>
        </select>
      </label>
    </div>
  </section>

  <!-- Hot swap rules -->
  <section class="ra-card">
    <header class="ra-card-header">
      <h2 class="ra-card-title">Hot-swap behaviour</h2>
      <span class="ra-local-badge">local only — backend endpoint coming soon</span>
    </header>
    <p class="ra-help">
      When a runtime fails or quota is exhausted, how should the agent react?
    </p>
    <div class="ra-grid">
      <label class="ra-field">
        <span class="ra-label">Rule</span>
        <select class="ra-input" bind:value={hotSwapRule}>
          <option value="always-confirm">Always ask before swapping</option>
          <option value="auto-on-error">
            Auto-swap on error (paid → paid still requires consent)
          </option>
          <option value="auto-to-local-only">Auto-swap to local runtimes only</option>
        </select>
      </label>
    </div>
    <p class="ra-help ra-help-warn">
      Paid → paid auto-fallback always requires explicit consent. Paid → local fallback (when
      available) is allowed if this rule permits it.
    </p>
  </section>
</div>

<style>
  .ra-page {
    padding: 1rem 2rem;
    max-width: 1000px;
    color: var(--cnp-fg);
  }

  .ra-header {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    margin-bottom: 1.5rem;
    gap: 1rem;
  }

  .ra-title {
    font-family: var(--cnp-font-serif, Georgia, serif);
    font-size: 1.5rem;
    font-weight: 500;
    letter-spacing: -0.02em;
    margin: 0 0 0.25rem 0;
  }

  .ra-sub {
    margin: 0;
    color: var(--cnp-fg-muted);
    font-size: 0.85rem;
  }

  .ra-card {
    background: var(--cnp-bg-elev);
    border: 1px solid var(--cnp-border);
    border-radius: 8px;
    padding: 1.25rem;
    margin-bottom: 1rem;
  }

  .ra-agent {
    background: color-mix(in oklch, oklch(0.72 0.16 30) 5%, var(--cnp-bg-elev));
  }

  .ra-agent-row {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .ra-agent-emoji {
    font-size: 1.5rem;
  }

  .ra-agent-body {
    flex: 1;
    min-width: 0;
  }

  .ra-agent-name {
    font-weight: 500;
  }

  .ra-agent-meta {
    color: var(--cnp-fg-muted);
    font-size: 0.8rem;
  }

  .ra-agent-link {
    color: var(--cnp-accent);
    font-size: 0.8rem;
    text-decoration: none;
  }

  .ra-agent-link:hover {
    text-decoration: underline;
  }

  .ra-card-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 0.5rem;
  }

  .ra-card-title {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.95rem;
    font-weight: 500;
    margin: 0;
  }

  .ra-card-meta {
    font-size: 0.8rem;
    color: var(--cnp-fg-muted);
  }

  .ra-help {
    color: var(--cnp-fg-muted);
    font-size: 0.8rem;
    margin: 0 0 0.75rem 0;
  }

  .ra-help-warn {
    margin-top: 0.5rem;
    color: #d97706;
  }

  .ra-form-title {
    font-size: 0.95rem;
    font-weight: 500;
    margin: 0 0 1rem 0;
  }

  .ra-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 0.75rem;
  }

  .ra-field {
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
  }

  .ra-field-checkbox {
    flex-direction: row;
    align-items: center;
    gap: 0.5rem;
  }

  .ra-label {
    font-size: 0.75rem;
    color: var(--cnp-fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .ra-input {
    background: var(--cnp-bg);
    border: 1px solid var(--cnp-border);
    border-radius: 4px;
    color: var(--cnp-fg);
    padding: 0.4rem 0.6rem;
    font-size: 0.85rem;
    font-family: inherit;
  }

  .ra-input:focus {
    outline: none;
    border-color: var(--cnp-accent);
  }

  .ra-actions {
    display: flex;
    gap: 0.5rem;
    justify-content: flex-end;
    margin-top: 1rem;
  }

  .ra-btn {
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

  .ra-btn:hover:not(:disabled) {
    border-color: var(--cnp-fg-muted);
  }

  .ra-btn-primary {
    background: var(--cnp-accent);
    color: var(--cnp-accent-fg, #fff);
    border-color: var(--cnp-accent);
  }

  .ra-btn-primary:hover:not(:disabled) {
    filter: brightness(1.1);
  }

  .ra-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .ra-error {
    color: #dc2626;
    font-size: 0.85rem;
    margin: 0.5rem 0 0 0;
  }

  .ra-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.85rem;
  }

  .ra-table th {
    text-align: left;
    font-weight: 500;
    color: var(--cnp-fg-muted);
    text-transform: uppercase;
    font-size: 0.7rem;
    letter-spacing: 0.04em;
    padding: 0.5rem 0.5rem;
    border-bottom: 1px solid var(--cnp-border);
  }

  .ra-table td {
    padding: 0.6rem 0.5rem;
    border-bottom: 1px solid var(--cnp-border);
    vertical-align: top;
  }

  .ra-mono {
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.8rem;
  }

  .ra-role {
    display: inline-block;
    padding: 0.1rem 0.5rem;
    border-radius: 3px;
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    border: 1px solid var(--cnp-border);
    color: var(--cnp-fg-muted);
  }

  .ra-empty {
    color: var(--cnp-fg-muted);
    font-size: 0.85rem;
    margin: 0.5rem 0;
  }

  .ra-local-badge {
    font-size: 0.7rem;
    font-style: italic;
    color: var(--cnp-fg-muted);
    opacity: 0.75;
  }
</style>
