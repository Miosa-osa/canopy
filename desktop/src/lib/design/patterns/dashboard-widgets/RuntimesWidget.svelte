<script lang="ts">
/**
 * RuntimesWidget — authenticated/installed/error status matrix.
 * CSS prefix: rw- (RuntimesWidget)
 */

import type { CreateQueryOptions } from '@tanstack/svelte-query';
import { createQuery } from '@tanstack/svelte-query';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import { runtimesQuery } from '$lib/api/queries/runtimes.js';
import type { Runtime, RuntimeStatus } from '$lib/domain/runtimes/types.js';

const optsStore = writable(untrack(() => runtimesQuery() as CreateQueryOptions<Runtime[]>));
const query = createQuery<Runtime[]>(optsStore);

const runtimes = $derived(($query.data ?? []) as Runtime[]);

function statusLabel(s: RuntimeStatus): string {
  switch (s) {
    case 'installed':
      return 'OK';
    case 'not_installed':
      return 'Not installed';
    case 'misconfigured':
      return 'Misconfigured';
    case 'error':
      return 'Error';
  }
}

function statusClass(s: RuntimeStatus): string {
  switch (s) {
    case 'installed':
      return 'rw-dot--ok';
    case 'not_installed':
      return 'rw-dot--missing';
    case 'misconfigured':
      return 'rw-dot--warn';
    case 'error':
      return 'rw-dot--error';
  }
}
</script>

<div class="rw-widget">
  {#if $query.isLoading}
    <p class="rw-empty">Loading…</p>
  {:else if $query.isError}
    <p class="rw-error">Failed to load runtimes</p>
  {:else if runtimes.length === 0}
    <p class="rw-empty">No runtimes configured</p>
  {:else}
    <ul class="rw-list" aria-label="Runtime status">
      {#each runtimes as rt (rt.type)}
        <li>
          <button
            class="rw-row"
            onclick={() => goto(`/settings/runtimes/${rt.type}`)}
            aria-label="{rt.name}: {statusLabel(rt.status)}"
          >
            <span class="rw-dot {statusClass(rt.status)}" aria-hidden="true"></span>
            <span class="rw-name">{rt.name}</span>
            <span class="rw-status">{statusLabel(rt.status)}</span>
            {#if rt.version}
              <span class="rw-version">{rt.version}</span>
            {/if}
          </button>
        </li>
      {/each}
    </ul>
  {/if}
</div>

<style>
  .rw-widget {
    padding: var(--space-3);
    display: flex;
    flex-direction: column;
  }

  .rw-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .rw-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    width: 100%;
    padding: 5px var(--space-1);
    background: transparent;
    border: none;
    cursor: pointer;
    border-radius: var(--radius-sm);
    transition: background var(--dur-instant) ease;
    font-family: inherit;
  }

  .rw-row:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent);
  }

  .rw-row:focus-visible {
    outline: 2px solid var(--fg-muted);
    outline-offset: 1px;
  }

  .rw-dot {
    width: 7px;
    height: 7px;
    border-radius: 9999px;
    flex-shrink: 0;
  }

  .rw-dot--ok      { background: oklch(0.78 0.18 145); }
  .rw-dot--warn    { background: oklch(0.75 0.15 60); }
  .rw-dot--error   { background: oklch(0.65 0.20 25); }
  .rw-dot--missing { background: var(--fg-subtle); }

  .rw-name {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg);
    font-weight: 500;
    flex: 1;
    text-align: left;
  }

  .rw-status {
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--fg-muted);
    white-space: nowrap;
  }

  .rw-version {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    white-space: nowrap;
  }

  .rw-empty,
  .rw-error {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
  }

  .rw-empty { color: var(--fg-subtle); }
  .rw-error { color: var(--signal-error, oklch(0.65 0.20 25)); }
</style>
