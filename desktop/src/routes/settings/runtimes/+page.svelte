<script lang="ts">
/**
 * Settings › Runtimes — list + overview.
 * Dense table: name, kind, installed, version, auth status, actions.
 * Filter bar: all | authenticated | not authenticated.
 *
 * Auth status is derived from runtime.authProfile until per-row /auth/status
 * calls are wired (that happens on the detail page). Auth status pills replace
 * the generic blue "Sign in" button.
 *
 * CSS prefix: rl-
 */
import { createQuery } from '@tanstack/svelte-query';
import { runtimesQuery } from '$lib/api/queries/runtimes.js';
import RuntimeAuthCard from '$lib/design/patterns/runtime-auth/RuntimeAuthCard.svelte';
import type { Runtime } from '$lib/domain/runtimes/types.js';
import { testRuntime } from '$lib/queries/runtime-auth.js';

// ── Data ─────────────────────────────────────────────────────────────────────

const runtimesResult = createQuery(runtimesQuery());

// ── Filter ────────────────────────────────────────────────────────────────────

type Filter = 'all' | 'authenticated' | 'unauthenticated';
let filter = $state<Filter>('all');

/**
 * Derive a simple auth bucket from runtime.authProfile.
 * The detailed per-method detection happens on the detail page.
 * Here we only need a coarse signal for filtering.
 */
function inferAuthBucket(r: Runtime): 'subscription' | 'cli_login' | 'api_key' | 'none' | 'error' {
  if (r.status === 'error') return 'error';
  if (!r.authProfile || r.authProfile.methods.length === 0) return 'none';
  const methods = r.authProfile.methods;
  if (methods.includes('subscription_detect')) return 'subscription';
  if (methods.includes('cli_login')) return 'cli_login';
  if (methods.includes('api_key')) return 'api_key';
  return 'none';
}

function applyFilter(all: Runtime[], f: Filter): Runtime[] {
  if (f === 'authenticated')
    return all.filter((r) => {
      const s = inferAuthBucket(r);
      return s === 'subscription' || s === 'cli_login' || s === 'api_key';
    });
  if (f === 'unauthenticated') return all.filter((r) => inferAuthBucket(r) === 'none');
  return all;
}

const filteredRuntimes = $derived(applyFilter($runtimesResult.data ?? [], filter));

// ── Helpers ───────────────────────────────────────────────────────────────────

const filterLabels: Record<Filter, string> = {
  all: 'All',
  authenticated: 'Authenticated',
  unauthenticated: 'Not authenticated',
};

const FILTERS: Filter[] = ['all', 'authenticated', 'unauthenticated'];
</script>

<div class="rl-page">
  <!-- Filter bar -->
  <div class="rl-filter-bar" role="group" aria-label="Filter runtimes">
    {#each FILTERS as f (f)}
      <button
        class="rl-filter-btn"
        class:rl-filter-btn--active={filter === f}
        onclick={() => {
          filter = f;
        }}
        aria-pressed={filter === f}
      >{filterLabels[f]}</button>
    {/each}
  </div>

  <!-- Table -->
  {#if $runtimesResult.isLoading}
    <div class="rl-loading" aria-live="polite">Loading runtimes…</div>
  {:else if $runtimesResult.isError}
    <p class="rl-error">Failed to load runtimes: {String($runtimesResult.error)}</p>
  {:else}
    <div class="rl-table-wrap">
      <table class="rl-table">
        <thead>
          <tr class="rl-thead-row">
            <th class="rl-th">Name</th>
            <th class="rl-th">Kind</th>
            <th class="rl-th">Status</th>
            <th class="rl-th">Version</th>
            <th class="rl-th">Auth</th>
            <th class="rl-th rl-th--right">Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredRuntimes as runtime (runtime.type)}
            <RuntimeAuthCard
              {runtime}
              authStatus={inferAuthBucket(runtime)}
              onTest={() => void testRuntime(runtime.type)}
            />
          {:else}
            <tr>
              <td class="rl-empty" colspan="6">No runtimes match this filter.</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>

<style>
  .rl-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    max-width: 860px;
  }

  /* ── Filter bar ── */

  .rl-filter-bar {
    display: flex;
    gap: 2px;
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    border-radius: var(--radius-md);
    padding: 2px;
    align-self: flex-start;
  }

  .rl-filter-btn {
    padding: var(--space-1) var(--space-3);
    border-radius: calc(var(--radius-md) - 2px);
    border: none;
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

  .rl-filter-btn:hover:not(.rl-filter-btn--active) {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
  }

  .rl-filter-btn--active {
    background: var(--bg-elevated);
    color: var(--fg);
    box-shadow: 0 1px 3px oklch(0 0 0 / 12%);
  }

  .rl-filter-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  /* ── Table ── */

  .rl-table-wrap {
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    overflow: hidden;
  }

  .rl-table {
    width: 100%;
    border-collapse: collapse;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
  }

  .rl-thead-row {
    border-bottom: 1px solid var(--border);
    background: color-mix(in oklch, var(--fg) 2%, transparent 98%);
  }

  .rl-th {
    padding: var(--space-2) var(--space-3);
    text-align: left;
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--fg-subtle);
    white-space: nowrap;
  }

  .rl-th--right {
    text-align: right;
  }

  /* ── Empty / loading / error ── */

  .rl-loading {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    padding: var(--space-4) 0;
  }

  .rl-empty {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    padding: var(--space-6) var(--space-3);
    text-align: center;
  }

  .rl-error {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: oklch(50% 0.2 25);
    margin: 0;
    padding: var(--space-2) var(--space-3);
    background: color-mix(in oklch, oklch(60% 0.2 25) 10%, transparent 90%);
    border-radius: var(--radius-sm);
  }
</style>
