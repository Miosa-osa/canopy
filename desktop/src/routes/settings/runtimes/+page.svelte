<script lang="ts">
/**
 * Settings › Runtimes — installed status, version, binary path, credential vault form.
 * Three runtimes: Claude Local, Codex Local, Gemini Local.
 * Per-runtime expand-in-place credential editor + test connection.
 *
 * All TanStack Query stores are declared at top level (Svelte 5 runes requirement).
 * Three explicit runtime blocks instead of #each to allow $store subscriptions.
 */

import { type CreateQueryOptions, createMutation, createQuery } from '@tanstack/svelte-query';
import { writable } from 'svelte/store';
import {
  runtimeCredentialsQuery,
  runtimesQuery,
  saveRuntimeCredentialsMutation,
  testEnvironmentMutation,
} from '$lib/api/queries/runtimes.js';
import type { Runtime, TestEnvironmentResult } from '$lib/domain/runtimes/types.js';

type CredQueryResult = { field_keys: string[] };
type CredQueryOpts = CreateQueryOptions<CredQueryResult>;

// ── Runtime list ──────────────────────────────────────────────────────────────
const runtimesResult = createQuery(runtimesQuery());

// ── Per-runtime expand state ──────────────────────────────────────────────────
let expanded0 = $state(false); // claude-code
let expanded1 = $state(false); // codex
let expanded2 = $state(false); // gemini

// ── Per-runtime credential values ────────────────────────────────────────────
let credValues0 = $state<Record<string, string>>({});
let credValues1 = $state<Record<string, string>>({});
let credValues2 = $state<Record<string, string>>({});

// ── Per-runtime test results ──────────────────────────────────────────────────
let testResult0 = $state<{ ok: boolean; message: string } | null>(null);
let testResult1 = $state<{ ok: boolean; message: string } | null>(null);
let testResult2 = $state<{ ok: boolean; message: string } | null>(null);

// ── Per-runtime credential queries (enabled only when expanded) ───────────────
const credOpts0 = writable<CredQueryOpts>(runtimeCredentialsQuery('') as CredQueryOpts);
const credOpts1 = writable<CredQueryOpts>(runtimeCredentialsQuery('') as CredQueryOpts);
const credOpts2 = writable<CredQueryOpts>(runtimeCredentialsQuery('') as CredQueryOpts);

$effect(() => {
  credOpts0.set(runtimeCredentialsQuery(expanded0 ? 'claude-code' : '') as CredQueryOpts);
});
$effect(() => {
  credOpts1.set(runtimeCredentialsQuery(expanded1 ? 'codex' : '') as CredQueryOpts);
});
$effect(() => {
  credOpts2.set(runtimeCredentialsQuery(expanded2 ? 'gemini' : '') as CredQueryOpts);
});

const credQuery0 = createQuery<CredQueryResult>(credOpts0);
const credQuery1 = createQuery<CredQueryResult>(credOpts1);
const credQuery2 = createQuery<CredQueryResult>(credOpts2);

// ── Per-runtime mutations ─────────────────────────────────────────────────────
const saveMut0 = createMutation(saveRuntimeCredentialsMutation('claude-code'));
const saveMut1 = createMutation(saveRuntimeCredentialsMutation('codex'));
const saveMut2 = createMutation(saveRuntimeCredentialsMutation('gemini'));

const testMut0 = createMutation(testEnvironmentMutation('claude-code'));
const testMut1 = createMutation(testEnvironmentMutation('codex'));
const testMut2 = createMutation(testEnvironmentMutation('gemini'));

// ── Helpers ───────────────────────────────────────────────────────────────────

function getRuntime(type: string): Runtime | undefined {
  return $runtimesResult.data?.find((r) => r.type === type);
}

function statusLabel(status: Runtime['status']): string {
  switch (status) {
    case 'installed': return 'Installed';
    case 'not_installed': return 'Not installed';
    case 'misconfigured': return 'Misconfigured';
    case 'error': return 'Error';
    default: return status;
  }
}

function onTestSuccess(
  result: TestEnvironmentResult,
  setter: (v: { ok: boolean; message: string } | null) => void
): void {
  setter({ ok: result.ok, message: result.checks.map((c) => c.message).join(' ') });
}

function onTestError(
  err: unknown,
  setter: (v: { ok: boolean; message: string } | null) => void
): void {
  setter({ ok: false, message: String(err) });
}
</script>

<div class="rt-page">
  <p class="rt-desc">
    Configure local AI runtime binaries and store credentials in the vault.
    Credentials are encrypted with AES-GCM + HKDF and never returned from the server.
  </p>

  <div class="rt-list">

    <!-- ── Claude Local ────────────────────────────────────────────────────── -->
    <div class="rt-card" class:rt-card--expanded={expanded0}>
      <div class="rt-card-header">
        <div class="rt-card-meta">
          <span class="rt-card-name">Claude Local</span>
          {#if getRuntime('claude-code')}
            <span class="rt-status-chip"
              class:rt-status-chip--ok={getRuntime('claude-code')!.status === 'installed'}
              class:rt-status-chip--warn={getRuntime('claude-code')!.status === 'misconfigured'}
              class:rt-status-chip--err={getRuntime('claude-code')!.status === 'error' || getRuntime('claude-code')!.status === 'not_installed'}
            >{statusLabel(getRuntime('claude-code')!.status)}</span>
          {:else if $runtimesResult.isLoading}
            <span class="rt-status-chip rt-status-chip--loading">Loading…</span>
          {:else}
            <span class="rt-status-chip rt-status-chip--err">Not installed</span>
          {/if}
        </div>
        <div class="rt-card-right">
          {#if getRuntime('claude-code')?.version}<span class="rt-mono rt-version">{getRuntime('claude-code')!.version}</span>{/if}
          <button class="rt-expand-btn" onclick={() => { expanded0 = !expanded0; }}
            aria-expanded={expanded0} aria-label="{expanded0 ? 'Collapse' : 'Expand'} Claude Local settings">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"
              style="transition: transform var(--dur-instant) var(--ease-out); transform: rotate({expanded0 ? '0deg' : '-90deg'})">
              <path d="M6 9l6 6 6-6" />
            </svg>
          </button>
        </div>
      </div>
      {#if getRuntime('claude-code')?.binaryPath}
        <p class="rt-binary-path"><span class="rt-field-label">Binary</span><code class="rt-mono">{getRuntime('claude-code')!.binaryPath}</code></p>
      {/if}
      {#if expanded0}
        <div class="rt-cred-section">
          <div class="rt-cred-divider"></div>
          {#if $credQuery0.isLoading}
            <p class="rt-loading-text">Loading credential fields…</p>
          {:else}
            {@const keys0 = $credQuery0.data?.field_keys ?? []}
            <p class="rt-cred-hint">{keys0.length > 0 ? `Stored fields: ${keys0.join(', ')}` : 'No credentials stored yet.'}</p>
            {#each (keys0.length > 0 ? keys0 : ['api_key']) as fieldKey (fieldKey)}
              <div class="rt-field-row">
                <label class="rt-field-label" for="rt-cred-claude-code-{fieldKey}">{fieldKey.replace(/_/g, ' ')}</label>
                <input id="rt-cred-claude-code-{fieldKey}" type="password" class="rt-input" placeholder="••••••••" autocomplete="off"
                  value={credValues0[fieldKey] ?? ''}
                  oninput={(e) => { credValues0 = { ...credValues0, [fieldKey]: (e.currentTarget as HTMLInputElement).value }; }} />
              </div>
            {/each}
            <div class="rt-cred-actions">
              <button class="rt-pill-btn rt-pill-btn--primary" disabled={$saveMut0.isPending}
                onclick={() => { testResult0 = null; $saveMut0.mutate(credValues0); }}>
                {$saveMut0.isPending ? 'Saving…' : 'Save credentials'}
              </button>
              <button class="rt-pill-btn" disabled={$testMut0.isPending}
                onclick={() => $testMut0.mutate(undefined, { onSuccess: (r) => onTestSuccess(r, (v) => { testResult0 = v; }), onError: (e) => onTestError(e, (v) => { testResult0 = v; }) })}>
                {$testMut0.isPending ? 'Testing…' : 'Test connection'}
              </button>
            </div>
            {#if testResult0}<p class="rt-test-result" class:rt-test-result--ok={testResult0.ok} class:rt-test-result--err={!testResult0.ok}>{testResult0.ok ? 'Connected.' : 'Failed.'} {testResult0.message}</p>{/if}
            {#if $saveMut0.isError}<p class="rt-test-result rt-test-result--err">Save failed: {String($saveMut0.error)}</p>{/if}
          {/if}
        </div>
      {/if}
    </div>

    <!-- ── Codex Local ─────────────────────────────────────────────────────── -->
    <div class="rt-card" class:rt-card--expanded={expanded1}>
      <div class="rt-card-header">
        <div class="rt-card-meta">
          <span class="rt-card-name">Codex Local</span>
          {#if getRuntime('codex')}
            <span class="rt-status-chip"
              class:rt-status-chip--ok={getRuntime('codex')!.status === 'installed'}
              class:rt-status-chip--warn={getRuntime('codex')!.status === 'misconfigured'}
              class:rt-status-chip--err={getRuntime('codex')!.status === 'error' || getRuntime('codex')!.status === 'not_installed'}
            >{statusLabel(getRuntime('codex')!.status)}</span>
          {:else if $runtimesResult.isLoading}
            <span class="rt-status-chip rt-status-chip--loading">Loading…</span>
          {:else}
            <span class="rt-status-chip rt-status-chip--err">Not installed</span>
          {/if}
        </div>
        <div class="rt-card-right">
          {#if getRuntime('codex')?.version}<span class="rt-mono rt-version">{getRuntime('codex')!.version}</span>{/if}
          <button class="rt-expand-btn" onclick={() => { expanded1 = !expanded1; }}
            aria-expanded={expanded1} aria-label="{expanded1 ? 'Collapse' : 'Expand'} Codex Local settings">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"
              style="transition: transform var(--dur-instant) var(--ease-out); transform: rotate({expanded1 ? '0deg' : '-90deg'})">
              <path d="M6 9l6 6 6-6" />
            </svg>
          </button>
        </div>
      </div>
      {#if getRuntime('codex')?.binaryPath}
        <p class="rt-binary-path"><span class="rt-field-label">Binary</span><code class="rt-mono">{getRuntime('codex')!.binaryPath}</code></p>
      {/if}
      {#if expanded1}
        <div class="rt-cred-section">
          <div class="rt-cred-divider"></div>
          {#if $credQuery1.isLoading}
            <p class="rt-loading-text">Loading credential fields…</p>
          {:else}
            {@const keys1 = $credQuery1.data?.field_keys ?? []}
            <p class="rt-cred-hint">{keys1.length > 0 ? `Stored fields: ${keys1.join(', ')}` : 'No credentials stored yet.'}</p>
            {#each (keys1.length > 0 ? keys1 : ['api_key']) as fieldKey (fieldKey)}
              <div class="rt-field-row">
                <label class="rt-field-label" for="rt-cred-codex-{fieldKey}">{fieldKey.replace(/_/g, ' ')}</label>
                <input id="rt-cred-codex-{fieldKey}" type="password" class="rt-input" placeholder="••••••••" autocomplete="off"
                  value={credValues1[fieldKey] ?? ''}
                  oninput={(e) => { credValues1 = { ...credValues1, [fieldKey]: (e.currentTarget as HTMLInputElement).value }; }} />
              </div>
            {/each}
            <div class="rt-cred-actions">
              <button class="rt-pill-btn rt-pill-btn--primary" disabled={$saveMut1.isPending}
                onclick={() => { testResult1 = null; $saveMut1.mutate(credValues1); }}>
                {$saveMut1.isPending ? 'Saving…' : 'Save credentials'}
              </button>
              <button class="rt-pill-btn" disabled={$testMut1.isPending}
                onclick={() => $testMut1.mutate(undefined, { onSuccess: (r) => onTestSuccess(r, (v) => { testResult1 = v; }), onError: (e) => onTestError(e, (v) => { testResult1 = v; }) })}>
                {$testMut1.isPending ? 'Testing…' : 'Test connection'}
              </button>
            </div>
            {#if testResult1}<p class="rt-test-result" class:rt-test-result--ok={testResult1.ok} class:rt-test-result--err={!testResult1.ok}>{testResult1.ok ? 'Connected.' : 'Failed.'} {testResult1.message}</p>{/if}
            {#if $saveMut1.isError}<p class="rt-test-result rt-test-result--err">Save failed: {String($saveMut1.error)}</p>{/if}
          {/if}
        </div>
      {/if}
    </div>

    <!-- ── Gemini Local ────────────────────────────────────────────────────── -->
    <div class="rt-card" class:rt-card--expanded={expanded2}>
      <div class="rt-card-header">
        <div class="rt-card-meta">
          <span class="rt-card-name">Gemini Local</span>
          {#if getRuntime('gemini')}
            <span class="rt-status-chip"
              class:rt-status-chip--ok={getRuntime('gemini')!.status === 'installed'}
              class:rt-status-chip--warn={getRuntime('gemini')!.status === 'misconfigured'}
              class:rt-status-chip--err={getRuntime('gemini')!.status === 'error' || getRuntime('gemini')!.status === 'not_installed'}
            >{statusLabel(getRuntime('gemini')!.status)}</span>
          {:else if $runtimesResult.isLoading}
            <span class="rt-status-chip rt-status-chip--loading">Loading…</span>
          {:else}
            <span class="rt-status-chip rt-status-chip--err">Not installed</span>
          {/if}
        </div>
        <div class="rt-card-right">
          {#if getRuntime('gemini')?.version}<span class="rt-mono rt-version">{getRuntime('gemini')!.version}</span>{/if}
          <button class="rt-expand-btn" onclick={() => { expanded2 = !expanded2; }}
            aria-expanded={expanded2} aria-label="{expanded2 ? 'Collapse' : 'Expand'} Gemini Local settings">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"
              style="transition: transform var(--dur-instant) var(--ease-out); transform: rotate({expanded2 ? '0deg' : '-90deg'})">
              <path d="M6 9l6 6 6-6" />
            </svg>
          </button>
        </div>
      </div>
      {#if getRuntime('gemini')?.binaryPath}
        <p class="rt-binary-path"><span class="rt-field-label">Binary</span><code class="rt-mono">{getRuntime('gemini')!.binaryPath}</code></p>
      {/if}
      {#if expanded2}
        <div class="rt-cred-section">
          <div class="rt-cred-divider"></div>
          {#if $credQuery2.isLoading}
            <p class="rt-loading-text">Loading credential fields…</p>
          {:else}
            {@const keys2 = $credQuery2.data?.field_keys ?? []}
            <p class="rt-cred-hint">{keys2.length > 0 ? `Stored fields: ${keys2.join(', ')}` : 'No credentials stored yet.'}</p>
            {#each (keys2.length > 0 ? keys2 : ['api_key']) as fieldKey (fieldKey)}
              <div class="rt-field-row">
                <label class="rt-field-label" for="rt-cred-gemini-{fieldKey}">{fieldKey.replace(/_/g, ' ')}</label>
                <input id="rt-cred-gemini-{fieldKey}" type="password" class="rt-input" placeholder="••••••••" autocomplete="off"
                  value={credValues2[fieldKey] ?? ''}
                  oninput={(e) => { credValues2 = { ...credValues2, [fieldKey]: (e.currentTarget as HTMLInputElement).value }; }} />
              </div>
            {/each}
            <div class="rt-cred-actions">
              <button class="rt-pill-btn rt-pill-btn--primary" disabled={$saveMut2.isPending}
                onclick={() => { testResult2 = null; $saveMut2.mutate(credValues2); }}>
                {$saveMut2.isPending ? 'Saving…' : 'Save credentials'}
              </button>
              <button class="rt-pill-btn" disabled={$testMut2.isPending}
                onclick={() => $testMut2.mutate(undefined, { onSuccess: (r) => onTestSuccess(r, (v) => { testResult2 = v; }), onError: (e) => onTestError(e, (v) => { testResult2 = v; }) })}>
                {$testMut2.isPending ? 'Testing…' : 'Test connection'}
              </button>
            </div>
            {#if testResult2}<p class="rt-test-result" class:rt-test-result--ok={testResult2.ok} class:rt-test-result--err={!testResult2.ok}>{testResult2.ok ? 'Connected.' : 'Failed.'} {testResult2.message}</p>{/if}
            {#if $saveMut2.isError}<p class="rt-test-result rt-test-result--err">Save failed: {String($saveMut2.error)}</p>{/if}
          {/if}
        </div>
      {/if}
    </div>

  </div>
</div>

<style>
  .rt-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-6);
    max-width: 720px;
  }

  .rt-desc {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
  }

  /* ── Runtime card ────────────────────────────────────────────────────────── */

  .rt-list {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .rt-card {
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-3) var(--space-4);
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .rt-card--expanded {
    border-color: var(--border-strong);
  }

  .rt-card-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
  }

  .rt-card-meta {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .rt-card-name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
  }

  .rt-card-right {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  /* ── Status chip ─────────────────────────────────────────────────────────── */

  .rt-status-chip {
    display: inline-flex;
    align-items: center;
    padding: 0 var(--space-2);
    height: 18px;
    border-radius: 9999px;
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.04em;
    text-transform: uppercase;
  }

  .rt-status-chip--ok {
    background: color-mix(in oklch, oklch(70% 0.15 145) 15%, transparent 85%);
    color: oklch(55% 0.15 145);
  }

  .rt-status-chip--warn {
    background: color-mix(in oklch, oklch(75% 0.18 80) 15%, transparent 85%);
    color: oklch(55% 0.18 80);
  }

  .rt-status-chip--err {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg-subtle);
  }

  .rt-status-chip--loading {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg-subtle);
  }

  /* ── Binary path ─────────────────────────────────────────────────────────── */

  .rt-binary-path {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    margin: 0;
  }

  /* ── Mono / version ──────────────────────────────────────────────────────── */

  .rt-mono {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-muted);
  }

  .rt-version {
    background: color-mix(in oklch, var(--fg) 5%, transparent 95%);
    padding: 1px var(--space-1);
    border-radius: var(--radius-sm);
  }

  /* ── Expand button ───────────────────────────────────────────────────────── */

  .rt-expand-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    border-radius: var(--radius-sm);
    border: none;
    background: transparent;
    color: var(--fg-subtle);
    cursor: pointer;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .rt-expand-btn:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
  }

  .rt-expand-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  /* ── Credential section ──────────────────────────────────────────────────── */

  .rt-cred-section {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .rt-cred-divider {
    height: 1px;
    background: var(--border);
    margin: var(--space-1) 0;
  }

  .rt-loading-text {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    margin: 0;
  }

  .rt-cred-hint {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-subtle);
    margin: 0;
  }

  /* ── Field row ───────────────────────────────────────────────────────────── */

  .rt-field-row {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .rt-field-label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--fg-subtle);
  }

  .rt-input {
    width: 100%;
    max-width: 400px;
    padding: var(--space-2) var(--space-3);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--bg-inset);
    color: var(--fg);
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    outline: none;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .rt-input:focus {
    border-color: var(--cnp-accent);
  }

  /* ── Credential actions ──────────────────────────────────────────────────── */

  .rt-cred-actions {
    display: flex;
    gap: var(--space-2);
    flex-wrap: wrap;
  }

  .rt-pill-btn {
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
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
    white-space: nowrap;
  }

  .rt-pill-btn:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
    border-color: var(--border-strong);
  }

  .rt-pill-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .rt-pill-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .rt-pill-btn--primary {
    background: var(--cnp-accent);
    border-color: var(--cnp-accent);
    color: oklch(100% 0 0);
  }

  .rt-pill-btn--primary:hover:not(:disabled) {
    background: color-mix(in oklch, var(--cnp-accent) 85%, oklch(0% 0 0) 15%);
    border-color: color-mix(in oklch, var(--cnp-accent) 85%, oklch(0% 0 0) 15%);
    color: oklch(100% 0 0);
  }

  /* ── Test result ─────────────────────────────────────────────────────────── */

  .rt-test-result {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    margin: 0;
    padding: var(--space-2) var(--space-3);
    border-radius: var(--radius-sm);
  }

  .rt-test-result--ok {
    background: color-mix(in oklch, oklch(70% 0.15 145) 12%, transparent 88%);
    color: oklch(50% 0.15 145);
  }

  .rt-test-result--err {
    background: color-mix(in oklch, oklch(60% 0.2 25) 12%, transparent 88%);
    color: oklch(50% 0.2 25);
  }
</style>
