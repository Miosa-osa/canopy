<script lang="ts">
/**
 * TestConnectionButton — runs POST /test, shows latency or error inline.
 * CSS prefix: tcb-
 */

import type { TestRuntimeResponse } from '$lib/queries/runtime-auth.js';
import { testRuntime } from '$lib/queries/runtime-auth.js';

interface Props {
  runtimeId: string;
  onResult?: (result: TestRuntimeResponse) => void;
}

let { runtimeId, onResult }: Props = $props();

let isPending = $state(false);
let lastResult = $state<TestRuntimeResponse | null>(null);
let lastError = $state<string | null>(null);

async function run() {
  lastResult = null;
  lastError = null;
  isPending = true;
  try {
    const r = await testRuntime(runtimeId);
    lastResult = r;
    onResult?.(r);
  } catch (err: unknown) {
    lastError = err instanceof Error ? err.message : String(err);
  } finally {
    isPending = false;
  }
}
</script>

<div class="tcb-wrap">
  <button
    class="tcb-btn"
    type="button"
    disabled={isPending}
    onclick={run}
    aria-label="Test connection for {runtimeId}"
  >
    {#if isPending}
      <span class="tcb-spinner" aria-hidden="true"></span>
      Testing…
    {:else}
      Test connection
    {/if}
  </button>

  {#if lastResult}
    <span
      class="tcb-result"
      class:tcb-result--ok={lastResult.ok}
      class:tcb-result--err={!lastResult.ok}
    >
      {#if lastResult.ok}
        {lastResult.latency_ms != null ? `${lastResult.latency_ms}ms` : 'OK'}
        {#if lastResult.model}&nbsp;· {lastResult.model}{/if}
      {:else}
        {lastResult.error ?? 'Failed'}
      {/if}
    </span>
  {/if}

  {#if lastError}
    <span class="tcb-result tcb-result--err">{lastError}</span>
  {/if}
</div>

<style>
  .tcb-wrap {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-wrap: wrap;
  }

  .tcb-btn {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
    padding: var(--space-1) var(--space-3);
    border-radius: 9999px;
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    cursor: pointer;
    white-space: nowrap;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .tcb-btn:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
    border-color: var(--border-strong);
  }

  .tcb-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .tcb-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .tcb-spinner {
    display: inline-block;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    border: 1.5px solid color-mix(in oklch, var(--fg) 20%, transparent 80%);
    border-top-color: var(--cnp-accent);
    animation: tcb-spin 0.8s linear infinite;
  }

  @keyframes tcb-spin {
    to { transform: rotate(360deg); }
  }

  .tcb-result {
    font-family: var(--font-mono);
    font-size: 11px;
    padding: 2px var(--space-2);
    border-radius: var(--radius-sm);
  }

  .tcb-result--ok {
    background: color-mix(in oklch, oklch(70% 0.15 145) 12%, transparent 88%);
    color: oklch(50% 0.15 145);
  }

  .tcb-result--err {
    background: color-mix(in oklch, oklch(60% 0.2 25) 10%, transparent 90%);
    color: oklch(50% 0.2 25);
  }
</style>
