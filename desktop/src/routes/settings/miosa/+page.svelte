<script lang="ts">
/**
 * Settings › MIOSA — MIOSA cloud compute integration panel.
 * Configures connection so Canopy can provision Firecracker VMs for sessions.
 *
 * Sections:
 *   1. Health card — status dot, last-checked, test-connection button
 *   2. Settings form — api_url, api_key (write-only), tier, auto_provision, region
 *   3. "What runs where" explainer (collapsed)
 *
 * Defensive: if GET /miosa returns 404, shows backend-not-ready banner and
 * disables the form. Matches the /settings/runtimes defensive pattern.
 *
 * CSS prefix: mi-
 */

import { createMutation, createQuery, useQueryClient } from '@tanstack/svelte-query';
import { ApiError } from '$lib/api/client.js';
import StatusDot from '$lib/design/patterns/StatusDot.svelte';
import {
  MIOSA_QUERY_KEYS,
  miosaHealthQuery,
  miosaSettingsQuery,
  probeMiosaModule,
  saveMiosaSettingsMutation,
} from '$lib/queries/miosa.js';
import { toasts } from '$lib/stores/toasts.svelte.js';
import type { MiosaRegion, MiosaTier } from '$lib/types/miosa.js';

const qc = useQueryClient();

// ── Backend module probe ──────────────────────────────────────────────────────

let moduleReady = $state<boolean | null>(null);

$effect(() => {
  void probeMiosaModule().then((ready) => {
    moduleReady = ready;
  });
});

// ── Queries ───────────────────────────────────────────────────────────────────

const healthResult = createQuery(miosaHealthQuery());
const settingsResult = createQuery(miosaSettingsQuery());

// ── Health helpers ────────────────────────────────────────────────────────────

type DotColor = 'green' | 'amber' | 'red' | 'grey';

function statusDotColor(s: string | undefined): DotColor {
  if (!s) return 'grey';
  if (s === 'ok') return 'green';
  if (s === 'unconfigured') return 'amber';
  return 'red';
}

function statusLabel(s: string | undefined): string {
  if (!s) return 'Unknown';
  if (s === 'ok') return 'Connected';
  if (s === 'unconfigured') return 'Not configured';
  if (s === 'unreachable') return 'Unreachable';
  return s;
}

function formatLastChecked(ts: string | null | undefined): string {
  if (!ts) return 'Never';
  const diff = Date.now() - new Date(ts).getTime();
  const mins = Math.floor(diff / 60_000);
  if (mins < 1) return 'Just now';
  if (mins === 1) return '1 minute ago';
  if (mins < 60) return `${mins} minutes ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs === 1) return '1 hour ago';
  return `${hrs} hours ago`;
}

// ── Test-connection action ────────────────────────────────────────────────────

let testingConnection = $state(false);

async function handleTestConnection() {
  if (testingConnection) return;
  testingConnection = true;
  try {
    await qc.refetchQueries({ queryKey: MIOSA_QUERY_KEYS.health });
    const data = $healthResult.data;
    if (data?.status === 'ok') {
      toasts.success('MIOSA connection verified.');
    } else if (data?.status === 'unreachable') {
      toasts.error('MIOSA is unreachable. Check the API URL and key.');
    } else {
      toasts.warning('MIOSA is not configured.');
    }
  } catch {
    toasts.error('Health check failed — backend may be unreachable.');
  } finally {
    testingConnection = false;
  }
}

// ── Form state ────────────────────────────────────────────────────────────────

// Seeded from the settings query once it loads.
let formApiUrl = $state('');
let formApiKey = $state(''); // Write-only: never pre-populated from GET
let formTier = $state<MiosaTier>('free');
let formAutoProvision = $state(false);
let formRegion = $state<MiosaRegion>(null);

// Track whether settings have been seeded so we only do it once.
let formSeeded = $state(false);

$effect(() => {
  const data = $settingsResult.data;
  if (!data || formSeeded) return;
  formApiUrl = data.api_url ?? '';
  // formApiKey intentionally left blank — write-only per API contract
  formTier = data.default_tier ?? 'free';
  formAutoProvision = data.auto_provision ?? false;
  formRegion = data.region ?? null;
  formSeeded = true;
});

// Snapshot of what was last saved (used for dirty detection).
let savedApiUrl = $derived($settingsResult.data?.api_url ?? '');
let savedTier = $derived($settingsResult.data?.default_tier ?? 'free');
let savedAutoProvision = $derived($settingsResult.data?.auto_provision ?? false);
let savedRegion = $derived($settingsResult.data?.region ?? null);

/**
 * Dirty if any editable field has changed from the persisted value.
 * api_key is always "dirty" when non-empty (it's never returned from GET).
 */
const isDirty = $derived(
  formApiKey.trim().length > 0 ||
    formApiUrl !== savedApiUrl ||
    formTier !== savedTier ||
    formAutoProvision !== savedAutoProvision ||
    formRegion !== savedRegion
);

// ── Mutation ──────────────────────────────────────────────────────────────────

let saveError = $state<string | null>(null);
let apiKeyVisible = $state(false);

const saveMut = createMutation({
  ...saveMiosaSettingsMutation(),
  onSuccess: async (res) => {
    // Update local snapshot from the returned settings
    formApiUrl = res.settings.api_url ?? '';
    formTier = res.settings.default_tier ?? 'free';
    formAutoProvision = res.settings.auto_provision ?? false;
    formRegion = res.settings.region ?? null;
    // Clear the key field on success — it was accepted and stored server-side
    formApiKey = '';
    saveError = null;
    await qc.invalidateQueries({ queryKey: MIOSA_QUERY_KEYS.health });
    await qc.invalidateQueries({ queryKey: MIOSA_QUERY_KEYS.settings });
    toasts.success('MIOSA settings saved.');
  },
  onError: (err: unknown) => {
    saveError =
      err instanceof ApiError
        ? err.message
        : err instanceof Error
          ? err.message
          : 'Save failed — unknown error.';
  },
});

async function handleSave() {
  if (!isDirty || $saveMut.isPending) return;
  saveError = null;

  // Only include api_key if the user explicitly typed one
  const trimmedKey = formApiKey.trim();

  await $saveMut.mutateAsync({
    api_url: formApiUrl || undefined,
    ...(trimmedKey.length > 0 ? { api_key: trimmedKey } : {}),
    default_tier: formTier,
    auto_provision: formAutoProvision,
    region: formRegion,
  });
}

function handleDiscard() {
  const data = $settingsResult.data;
  formApiUrl = data?.api_url ?? '';
  formApiKey = '';
  formTier = data?.default_tier ?? 'free';
  formAutoProvision = data?.auto_provision ?? false;
  formRegion = data?.region ?? null;
  saveError = null;
}

// ── Explainer toggle ──────────────────────────────────────────────────────────

let explainerOpen = $state(false);
</script>

<div class="mi-page">

  <!-- Backend not ready banner -->
  {#if moduleReady === false}
    <div class="mi-not-ready" role="status">
      MIOSA backend module not ready — endpoints are not available on this build.
    </div>
  {/if}

  <!-- Description -->
  <p class="mi-desc">
    Configure connection to MIOSA cloud compute — provisions Firecracker VMs for sessions.
  </p>

  <!-- ── Health card ──────────────────────────────────────────────────────── -->
  <section class="mi-card" aria-label="MIOSA connection health">
    <div class="mi-card-header">
      <span class="mi-card-title">Connection status</span>

      <div class="mi-health-right">
        <StatusDot
          color={statusDotColor($healthResult.data?.status)}
          label={statusLabel($healthResult.data?.status)}
          pulse={$healthResult.data?.status === "ok"}
        />
        <span class="mi-last-checked">
          Last checked: {formatLastChecked($healthResult.data?.last_check_at)}
        </span>
      </div>

      <button
        class="mi-btn mi-btn--ghost"
        onclick={handleTestConnection}
        disabled={testingConnection || moduleReady === false}
        aria-busy={testingConnection}
      >
        {testingConnection ? "Checking…" : "Test connection"}
      </button>
    </div>

    {#if $healthResult.data?.status === "unreachable"}
      <div class="mi-alert mi-alert--error" role="alert">
        MIOSA is unreachable. Verify the API URL and key are correct, then test again.
        {#if $healthResult.data.detail}
          <span class="mi-alert-detail">{$healthResult.data.detail}</span>
        {/if}
      </div>
    {/if}
  </section>

  <!-- ── Settings form ────────────────────────────────────────────────────── -->
  <section class="mi-card" aria-label="MIOSA settings">
    <span class="mi-card-title">Connection settings</span>

    <div class="mi-form">

      <!-- api_url -->
      <div class="mi-field">
        <label class="mi-field-label" for="mi-api-url">API URL</label>
        <input
          id="mi-api-url"
          type="url"
          class="mi-input"
          placeholder="https://api.miosa.com"
          bind:value={formApiUrl}
          autocomplete="off"
          disabled={moduleReady === false}
        />
      </div>

      <!-- api_key — write-only, never pre-populated -->
      <div class="mi-field">
        <label class="mi-field-label" for="mi-api-key">
          API Key
          <span class="mi-field-badge">write-only</span>
        </label>
        <div class="mi-input-row">
          {#if apiKeyVisible}
            <input
              id="mi-api-key"
              type="text"
              class="mi-input mi-input--key"
              placeholder="miosa_sk_… (leave blank to keep current key)"
              bind:value={formApiKey}
              autocomplete="off"
              spellcheck={false}
              disabled={moduleReady === false}
            />
          {:else}
            <input
              id="mi-api-key"
              type="password"
              class="mi-input mi-input--key"
              placeholder="miosa_sk_… (leave blank to keep current key)"
              bind:value={formApiKey}
              autocomplete="off"
              disabled={moduleReady === false}
            />
          {/if}
          <button
            type="button"
            class="mi-reveal-btn"
            onclick={() => { apiKeyVisible = !apiKeyVisible; }}
            aria-label={apiKeyVisible ? "Hide API key" : "Reveal API key"}
          >
            {apiKeyVisible ? "Hide" : "Show"}
          </button>
        </div>
      </div>

      <!-- default_tier -->
      <div class="mi-field">
        <label class="mi-field-label" for="mi-tier">Default VM tier</label>
        <select
          id="mi-tier"
          class="mi-select"
          bind:value={formTier}
          disabled={moduleReady === false}
        >
          <option value="free">Free</option>
          <option value="pro">Pro — $40/mo</option>
          <option value="growth">Growth — $100/mo</option>
          <option value="business">Business — $200/mo</option>
        </select>
      </div>

      <!-- region -->
      <div class="mi-field">
        <label class="mi-field-label" for="mi-region">Preferred region</label>
        <select
          id="mi-region"
          class="mi-select"
          bind:value={formRegion}
          disabled={moduleReady === false}
        >
          <option value={null}>Auto (let MIOSA choose)</option>
          <option value="us-east">US East</option>
          <option value="us-west">US West</option>
          <option value="eu-central">EU Central</option>
        </select>
      </div>

      <!-- auto_provision toggle -->
      <div class="mi-field mi-field--toggle">
        <div class="mi-toggle-label-col">
          <span class="mi-field-label">Auto-provision VM for new sessions</span>
          <span class="mi-toggle-desc">
            When enabled, each new session spawns a MIOSA VM automatically.
            When disabled, sessions use the local pty path.
          </span>
        </div>
        <button
          type="button"
          class="mi-toggle"
          class:mi-toggle--on={formAutoProvision}
          role="switch"
          aria-checked={formAutoProvision}
          aria-label="Auto-provision VM for new sessions"
          onclick={() => { formAutoProvision = !formAutoProvision; }}
          disabled={moduleReady === false}
        >
          <span class="mi-toggle-thumb"></span>
        </button>
      </div>

    </div>

    <!-- Save error banner -->
    {#if saveError}
      <div class="mi-alert mi-alert--error" role="alert">{saveError}</div>
    {/if}

    <!-- Form actions -->
    <div class="mi-actions">
      <button
        class="mi-btn mi-btn--primary"
        onclick={handleSave}
        disabled={!isDirty || $saveMut.isPending || moduleReady === false}
        aria-busy={$saveMut.isPending}
      >
        {$saveMut.isPending ? "Saving…" : "Save"}
      </button>
      <button
        class="mi-btn mi-btn--ghost"
        onclick={handleDiscard}
        disabled={!isDirty || $saveMut.isPending}
      >
        Discard changes
      </button>
    </div>
  </section>

  <!-- ── What runs where explainer ─────────────────────────────────────────── -->
  <div class="mi-explainer">
    <button
      class="mi-explainer-toggle"
      onclick={() => { explainerOpen = !explainerOpen; }}
      aria-expanded={explainerOpen}
    >
      <span class="mi-explainer-arrow" class:mi-explainer-arrow--open={explainerOpen}>▶</span>
      What runs where?
    </button>
    {#if explainerOpen}
      <p class="mi-explainer-body">
        When Auto-provision is ON, every new Canopy session requests a fresh Firecracker
        microVM from MIOSA. The agent pty runs inside that VM, and a Phoenix Channel bridges
        stdin/stdout back to the desktop app — giving you cloud-isolated execution with
        your local UI. When Auto-provision is OFF, sessions spawn a local pty directly on
        your machine via portable-pty, which is faster to start but shares your local
        environment.
      </p>
    {/if}
  </div>

</div>

<style>
  .mi-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-5);
    max-width: 680px;
  }

  .mi-desc {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
  }

  /* ── Backend not-ready banner ── */

  .mi-not-ready {
    padding: var(--space-2) var(--space-3);
    border-radius: var(--radius-sm);
    background: color-mix(in oklch, oklch(75% 0.18 80) 12%, transparent 88%);
    color: oklch(50% 0.18 80);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
  }

  /* ── Cards ── */

  .mi-card {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-4) var(--space-5);
  }

  .mi-card-title {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--fg-subtle);
  }

  .mi-card-header {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    flex-wrap: wrap;
  }

  .mi-health-right {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    flex: 1;
  }

  .mi-last-checked {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  /* ── Alert banners ── */

  .mi-alert {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
    padding: var(--space-2) var(--space-3);
    border-radius: var(--radius-sm);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
  }

  .mi-alert--error {
    background: color-mix(in oklch, oklch(60% 0.2 25) 10%, transparent 90%);
    color: oklch(50% 0.2 25);
  }

  .mi-alert-detail {
    font-weight: 400;
    opacity: 0.85;
  }

  /* ── Form ── */

  .mi-form {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }

  .mi-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .mi-field--toggle {
    flex-direction: row;
    align-items: flex-start;
    justify-content: space-between;
    gap: var(--space-4);
    padding-top: var(--space-1);
  }

  .mi-field-label {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--fg-subtle);
  }

  .mi-field-badge {
    font-size: 9px;
    font-weight: 500;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    padding: 1px 5px;
    border-radius: 3px;
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg-subtle);
  }

  .mi-toggle-label-col {
    display: flex;
    flex-direction: column;
    gap: 3px;
    flex: 1;
    min-width: 0;
  }

  .mi-toggle-desc {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    line-height: 1.5;
  }

  /* ── Inputs ── */

  .mi-input {
    width: 100%;
    padding: var(--space-2) var(--space-3);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--bg-inset);
    color: var(--fg);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    outline: none;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .mi-input:focus {
    border-color: var(--cnp-accent);
  }

  .mi-input:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .mi-input--key {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
  }

  .mi-input-row {
    display: flex;
    gap: var(--space-2);
    align-items: center;
  }

  .mi-input-row .mi-input {
    flex: 1;
  }

  .mi-reveal-btn {
    flex-shrink: 0;
    padding: var(--space-1) var(--space-3);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--bg-inset);
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    cursor: pointer;
    white-space: nowrap;
    transition:
      color var(--dur-instant) var(--ease-out),
      border-color var(--dur-instant) var(--ease-out);
  }

  .mi-reveal-btn:hover {
    color: var(--fg);
    border-color: var(--border-strong, var(--border));
  }

  .mi-reveal-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  .mi-select {
    width: 100%;
    max-width: 320px;
    padding: var(--space-2) var(--space-3);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--bg-inset);
    color: var(--fg);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    outline: none;
    cursor: pointer;
    transition: border-color var(--dur-instant) var(--ease-out);
    appearance: none;
  }

  .mi-select:focus {
    border-color: var(--cnp-accent);
  }

  .mi-select:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  /* ── Toggle switch ── */

  .mi-toggle {
    flex-shrink: 0;
    position: relative;
    width: 36px;
    height: 20px;
    border-radius: 10px;
    border: 1px solid var(--border);
    background: color-mix(in oklch, var(--fg) 10%, transparent 90%);
    cursor: pointer;
    transition:
      background var(--dur-fast) var(--ease-out),
      border-color var(--dur-fast) var(--ease-out);
    margin-top: 2px;
  }

  .mi-toggle--on {
    background: var(--cnp-accent);
    border-color: var(--cnp-accent);
  }

  .mi-toggle:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .mi-toggle:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .mi-toggle-thumb {
    position: absolute;
    top: 2px;
    left: 2px;
    width: 14px;
    height: 14px;
    border-radius: 50%;
    background: var(--fg-subtle);
    transition: transform var(--dur-fast) var(--ease-out), background var(--dur-fast) var(--ease-out);
  }

  .mi-toggle--on .mi-toggle-thumb {
    transform: translateX(16px);
    background: white;
  }

  /* ── Action buttons ── */

  .mi-actions {
    display: flex;
    gap: var(--space-2);
    padding-top: var(--space-1);
  }

  .mi-btn {
    padding: var(--space-2) var(--space-4);
    border-radius: var(--radius-sm);
    border: 1px solid transparent;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    cursor: pointer;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out),
      opacity var(--dur-instant) var(--ease-out);
    white-space: nowrap;
  }

  .mi-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .mi-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .mi-btn--primary {
    background: var(--fg);
    color: var(--bg);
    border-color: var(--fg);
  }

  .mi-btn--primary:hover:not(:disabled) {
    opacity: 0.85;
  }

  .mi-btn--ghost {
    background: transparent;
    color: var(--fg-muted);
    border-color: var(--border);
  }

  .mi-btn--ghost:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 5%, transparent 95%);
    color: var(--fg);
  }

  /* ── Explainer ── */

  .mi-explainer {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .mi-explainer-toggle {
    display: inline-flex;
    align-items: center;
    gap: var(--space-2);
    background: none;
    border: none;
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    padding: 0;
    transition: color var(--dur-instant) var(--ease-out);
  }

  .mi-explainer-toggle:hover {
    color: var(--fg);
  }

  .mi-explainer-toggle:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
    border-radius: 2px;
  }

  .mi-explainer-arrow {
    font-size: 9px;
    transition: transform var(--dur-fast) var(--ease-out);
  }

  .mi-explainer-arrow--open {
    transform: rotate(90deg);
  }

  .mi-explainer-body {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    line-height: 1.6;
    margin: 0;
    padding: var(--space-3) var(--space-4);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: color-mix(in oklch, var(--fg) 2%, transparent 98%);
  }
</style>
