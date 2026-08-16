<script lang="ts">
/**
 * Settings › Runtimes › [type] — single runtime detail.
 *
 * Renders per-runtime auth panels based on the backend's auth_profile.
 * Panel order matches the runtime's `methods` array priority.
 * Active method is shown in a top banner.
 *
 * No blue. Monochrome + var(--cnp-accent). CSS prefix: rd-
 */
import { type CreateQueryOptions, createQuery, useQueryClient } from '@tanstack/svelte-query';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { page } from '$app/state';
import { runtimeDetailQuery } from '$lib/api/queries/runtimes.js';
import {
  authStatusQuery,
  saveApiKey,
  revokeCredentials,
  testRuntime,
} from '$lib/queries/runtime-auth.js';
import type { RuntimeDetail, AuthMethod, AuthStatus } from '$lib/domain/runtimes/types.js';
import type { TestRuntimeResponse } from '$lib/queries/runtime-auth.js';
import SubscriptionDetectPanel from '$lib/design/patterns/runtime-auth/SubscriptionDetectPanel.svelte';
import CliLoginPanel from '$lib/design/patterns/runtime-auth/CliLoginPanel.svelte';
import ApiKeyPanel from '$lib/design/patterns/runtime-auth/ApiKeyPanel.svelte';
import TestConnectionButton from '$lib/design/patterns/runtime-auth/TestConnectionButton.svelte';

const runtimeId = $derived(page.params.type ?? '');

// ── Runtime detail ────────────────────────────────────────────────────────────

const detailOptsStore = writable(
  untrack(() => runtimeDetailQuery(runtimeId) as CreateQueryOptions<RuntimeDetail>),
);
$effect(() => {
  detailOptsStore.set(runtimeDetailQuery(runtimeId) as CreateQueryOptions<RuntimeDetail>);
});
const detailResult = createQuery<RuntimeDetail>(detailOptsStore);

// ── Auth status ───────────────────────────────────────────────────────────────

const authOptsStore = writable(
  untrack(() => authStatusQuery(runtimeId) as CreateQueryOptions<AuthStatus>),
);
$effect(() => {
  authOptsStore.set(authStatusQuery(runtimeId) as CreateQueryOptions<AuthStatus>);
});
const authResult = createQuery<AuthStatus>(authOptsStore);

const queryClient = useQueryClient();

// ── Local state ───────────────────────────────────────────────────────────────

let recheckingAuth = $state(false);
let isSavingKey = $state(false);
let isRevokingKey = $state(false);
let isTesting = $state(false);
let saveKeyError = $state<string | null>(null);
let testResults = $state<TestRuntimeResponse[]>([]);

async function handleRecheck() {
  recheckingAuth = true;
  try {
    await queryClient.invalidateQueries({ queryKey: ['runtimes', runtimeId, 'auth', 'status'] });
  } finally {
    recheckingAuth = false;
  }
}

async function handleSaveKey(key: string) {
  saveKeyError = null;
  isSavingKey = true;
  try {
    await saveApiKey(runtimeId, key);
    await queryClient.invalidateQueries({ queryKey: ['runtimes', runtimeId, 'auth', 'status'] });
  } catch (err: unknown) {
    saveKeyError = err instanceof Error ? err.message : String(err);
  } finally {
    isSavingKey = false;
  }
}

async function handleTestKey(_key: string) {
  isTesting = true;
  try {
    const r = await testRuntime(runtimeId);
    testResults = [r, ...testResults].slice(0, 5);
  } finally {
    isTesting = false;
  }
}

async function handleRevoke() {
  isRevokingKey = true;
  try {
    await revokeCredentials(runtimeId);
    await queryClient.invalidateQueries({ queryKey: ['runtimes', runtimeId, 'auth', 'status'] });
    await queryClient.invalidateQueries({ queryKey: ['runtimes', runtimeId] });
  } catch {
    // ignore
  } finally {
    isRevokingKey = false;
  }
}

function handleTestResult(r: TestRuntimeResponse) {
  testResults = [r, ...testResults].slice(0, 5);
}

// ── Derived display values ────────────────────────────────────────────────────

const authStatus = $derived($authResult.data);
const authProfile = $derived($detailResult.data?.authProfile ?? null);
const methods = $derived((authStatus?.methods ?? authProfile?.methods ?? []) as AuthMethod[]);

const activeMethodLabel = $derived<string | null>(
  authStatus?.active_method === 'subscription_detect'
    ? 'Subscription'
    : authStatus?.active_method === 'cli_login'
      ? 'CLI login'
      : authStatus?.active_method === 'api_key'
        ? 'API key'
        : null,
);

function statusText(s: string) {
  return s === 'installed'
    ? 'Installed'
    : s === 'misconfigured'
      ? 'Misconfigured'
      : s === 'error'
        ? 'Error'
        : 'Not installed';
}

function kindLabel(kind: string) {
  return kind === 'cli' ? 'CLI' : kind === 'api' ? 'API' : kind === 'local_model' ? 'Local' : kind;
}
</script>

<div class="rd-page">
  {#if $detailResult.isLoading}
    <span class="rd-muted">Loading…</span>
  {:else if $detailResult.isError}
    <p class="rd-msg rd-msg--err">Failed to load runtime: {String($detailResult.error)}</p>
  {:else if $detailResult.data}
    {@const rt = $detailResult.data}

    <!-- Runtime header -->
    <div class="rd-header">
      <div class="rd-meta">
        <h2 class="rd-name">{rt.name}</h2>
        {#if rt.version}<span class="rd-mono">{rt.version}</span>{/if}
      </div>
      <div class="rd-chips">
        <span class="rd-chip">{kindLabel(rt.kind ?? 'cli')}</span>
        <span
          class="rd-chip"
          class:rd-chip--ok={rt.status === 'installed'}
          class:rd-chip--warn={rt.status === 'misconfigured'}
        >{statusText(rt.status)}</span>
      </div>
    </div>

    {#if rt.binaryPath}
      <div class="rd-section">
        <span class="rd-label">Binary</span>
        <div class="rd-row">
          <code class="rd-mono">{rt.binaryPath}</code>
          <button
            class="rd-ghost-btn"
            onclick={() => void navigator.clipboard.writeText(rt.binaryPath ?? '')}
            aria-label="Copy binary path"
          >Copy</button>
        </div>
      </div>
    {/if}

    <!-- Active method banner -->
    {#if activeMethodLabel}
      <div class="rd-active-banner">
        <span class="rd-active-dot" aria-hidden="true"></span>
        <span>Active: <strong>{activeMethodLabel}</strong> — sessions will launch using this method.</span>
      </div>
    {:else if !$authResult.isLoading && methods.length > 0}
      <div class="rd-inactive-banner">
        Not authenticated — choose an auth method below.
      </div>
    {/if}

    <!-- Auth panels — one per method the runtime supports -->
    {#if methods.length > 0}
      <div class="rd-section">
        <span class="rd-label">Authentication</span>

        <div class="rd-auth-panels">
          {#each methods as method (method)}
            {#if method === 'subscription_detect'}
              <div class="rd-auth-panel-wrap">
                <SubscriptionDetectPanel
                  runtimeName={rt.name}
                  detected={authStatus?.subscription_detected ?? null}
                  checkPath={authProfile?.subscription_detect?.check_path ?? null}
                  checking={recheckingAuth}
                  onRecheck={handleRecheck}
                />
              </div>
            {:else if method === 'cli_login'}
              <div class="rd-auth-panel-wrap">
                <CliLoginPanel
                  loginCommand={authProfile?.cli_login?.command ?? `${rt.type} auth login`}
                  loggedIn={authStatus?.cli_logged_in ?? null}
                  checking={recheckingAuth}
                  onRecheck={handleRecheck}
                />
              </div>
            {:else if method === 'api_key'}
              <div class="rd-auth-panel-wrap">
                <ApiKeyPanel
                  {runtimeId}
                  stored={authStatus?.api_key_stored ?? null}
                  signupUrl={authProfile?.api_key?.signup_url ?? null}
                  placeholder={authProfile?.api_key?.placeholder ?? 'Paste your API key…'}
                  isSaving={isSavingKey}
                  isTesting={isTesting}
                  saveError={saveKeyError}
                  testResult={testResults[0] ?? null}
                  onSave={handleSaveKey}
                  onTest={handleTestKey}
                  onRevoke={handleRevoke}
                />
              </div>
            {/if}
          {/each}
        </div>
      </div>
    {:else if authProfile?.note}
      <div class="rd-section">
        <span class="rd-label">Authentication</span>
        <p class="rd-muted">{authProfile.note}</p>
      </div>
    {/if}

    <!-- Connection test -->
    <div class="rd-section">
      <span class="rd-label">Connection test</span>
      <TestConnectionButton {runtimeId} onResult={handleTestResult} />
      {#if testResults.length > 0}
        <div class="rd-history">
          {#each testResults as r, i (i)}
            {@const latLabel =
              r.ok
                ? (r.latency_ms != null ? `${r.latency_ms}ms` : 'OK') +
                  (r.model ? ` · ${r.model}` : '')
                : (r.error ?? 'Failed')}
            <div class="rd-row">
              <span class="rd-dot" class:rd-dot--ok={r.ok} class:rd-dot--err={!r.ok} aria-hidden="true"></span>
              <span class="rd-mono">{latLabel}</span>
            </div>
          {/each}
        </div>
      {/if}
    </div>

    <!-- Sessions link -->
    <div class="rd-section">
      <span class="rd-label">Sessions</span>
      <a href="/sessions?runtime={runtimeId}" class="rd-pill rd-pill--link">
        View sessions for {rt.name}
      </a>
    </div>
  {/if}
</div>

<style>
  .rd-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-5);
    max-width: 640px;
  }

  /* ── Header ── */

  .rd-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-4);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
  }

  .rd-meta {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }

  .rd-name {
    font-family: var(--font-sans);
    font-size: var(--text-base);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
  }

  .rd-mono {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-muted);
  }

  .rd-chips {
    display: flex;
    gap: var(--space-1);
    flex-shrink: 0;
    flex-wrap: wrap;
    justify-content: flex-end;
  }

  .rd-chip {
    display: inline-flex;
    align-items: center;
    height: 18px;
    padding: 0 var(--space-2);
    border-radius: 9999px;
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    background: color-mix(in oklch, var(--fg) 7%, transparent 93%);
    color: var(--fg-subtle);
    flex-shrink: 0;
  }

  .rd-chip--ok {
    background: color-mix(in oklch, oklch(70% 0.15 145) 14%, transparent 86%);
    color: oklch(50% 0.15 145);
  }

  .rd-chip--warn {
    background: color-mix(in oklch, oklch(75% 0.18 80) 14%, transparent 86%);
    color: oklch(50% 0.18 80);
  }

  /* ── Active / inactive banners ── */

  .rd-active-banner {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-3);
    border: 1px solid color-mix(in oklch, oklch(70% 0.15 145) 30%, transparent 70%);
    border-radius: var(--radius-sm);
    background: color-mix(in oklch, oklch(70% 0.15 145) 8%, transparent 92%);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: oklch(45% 0.15 145);
  }

  .rd-active-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    flex-shrink: 0;
    background: oklch(60% 0.15 145);
  }

  .rd-inactive-banner {
    padding: var(--space-2) var(--space-3);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: color-mix(in oklch, var(--fg) 3%, transparent 97%);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  /* ── Section ── */

  .rd-section {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-4);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
  }

  .rd-label {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--fg-subtle);
  }

  /* ── Auth panels list ── */

  .rd-auth-panels {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }

  .rd-auth-panel-wrap {
    padding: var(--space-3);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: color-mix(in oklch, var(--fg) 1.5%, transparent 98.5%);
  }

  /* ── Misc ── */

  .rd-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .rd-muted {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  .rd-ghost-btn {
    flex-shrink: 0;
    padding: 2px var(--space-2);
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-subtle);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    cursor: pointer;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .rd-ghost-btn:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
  }

  .rd-ghost-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  .rd-history {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .rd-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    flex-shrink: 0;
    background: color-mix(in oklch, var(--fg) 20%, transparent 80%);
  }

  .rd-dot--ok {
    background: oklch(60% 0.15 145);
  }

  .rd-dot--err {
    background: oklch(60% 0.2 25);
  }

  .rd-pill {
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
    text-decoration: none;
    white-space: nowrap;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .rd-pill:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
    border-color: var(--border-strong);
  }

  .rd-pill:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .rd-pill--link {
    color: var(--cnp-accent);
    border-color: color-mix(in oklch, var(--cnp-accent) 30%, transparent 70%);
  }

  .rd-msg {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    margin: 0;
    padding: var(--space-2) var(--space-3);
    border-radius: var(--radius-sm);
  }

  .rd-msg--err {
    background: color-mix(in oklch, oklch(60% 0.2 25) 10%, transparent 90%);
    color: oklch(50% 0.2 25);
  }
</style>
