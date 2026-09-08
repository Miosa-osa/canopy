<script lang="ts">
/**
 * InvocationLog — tail of recent tool calls.
 *
 * Source of truth: `Canopy.Agents.ToolCalls.list/1` (cross-session,
 * cross-agent persistent audit trail). Polled every 5s via `toolInvocationsQuery`.
 * No PubSub yet — pane is single-tab in practice and polling matches the
 * existing analytics pattern. See mcp-wiring.md for Phase B PubSub plan.
 *
 * CSS prefix: il-
 */
import { createQuery } from '@tanstack/svelte-query';
import { CircleAlert, CircleCheck, Clock } from 'lucide-svelte';
import { toolInvocationsQuery } from '$lib/api/queries/mcp.js';
import type { ToolInvocation } from '$lib/domain/mcp/types.js';

interface Props {
  /** When set, only show invocations of this tool. */
  filterTool?: string | null;
}

let { filterTool = null }: Props = $props();

const log = createQuery(toolInvocationsQuery({ limit: 100 }));

const visible = $derived<ToolInvocation[]>(
  filterTool ? ($log.data ?? []).filter((row) => row.toolName === filterTool) : ($log.data ?? [])
);

function summarizeArgs(params: Record<string, unknown>): string {
  const keys = Object.keys(params);
  if (keys.length === 0) return '∅';
  return keys
    .map((k) => {
      const v = params[k];
      const s =
        typeof v === 'string'
          ? `"${v.length > 24 ? v.slice(0, 24) + '…' : v}"`
          : typeof v === 'object'
            ? '{…}'
            : String(v);
      return `${k}=${s}`;
    })
    .join(' ');
}

function formatTs(iso: string): string {
  try {
    const d = new Date(iso);
    const hh = String(d.getHours()).padStart(2, '0');
    const mm = String(d.getMinutes()).padStart(2, '0');
    const ss = String(d.getSeconds()).padStart(2, '0');
    return `${hh}:${mm}:${ss}`;
  } catch {
    return iso;
  }
}
</script>

<div class="il-root" aria-label="Tool invocation log">
  <header class="il-header">
    <h3 class="il-title">Invocation log</h3>
    <span class="il-meta">
      {visible.length}{filterTool ? ` for ${filterTool}` : ''}
      {#if $log.isFetching}<span class="il-meta__spinner" aria-hidden="true">↻</span>{/if}
    </span>
  </header>

  <div class="il-body">
    {#if $log.isLoading}
      <p class="il-empty">Loading…</p>
    {:else if $log.isError}
      <p class="il-empty il-empty--err">Failed to load tool calls: {$log.error?.message ?? 'unknown'}</p>
    {:else if visible.length === 0}
      <p class="il-empty">No invocations yet.</p>
    {:else}
      <ul class="il-list">
        {#each visible as row (row.id)}
          {@const status = row.status}
          <li class="il-row" data-status={status}>
            <span class="il-row__status" aria-label={status}>
              {#if status === 'ok'}
                <CircleCheck size={11} aria-hidden="true" />
              {:else if status === 'error'}
                <CircleAlert size={11} aria-hidden="true" />
              {:else}
                <Clock size={11} aria-hidden="true" />
              {/if}
            </span>
            <span class="il-row__ts">{formatTs(row.insertedAt)}</span>
            <span class="il-row__tool">{row.toolName}</span>
            <span class="il-row__args" title={JSON.stringify(row.params)}>
              {summarizeArgs(row.params)}
            </span>
            {#if row.runId}
              <span class="il-row__run" title={'run ' + row.runId}>
                {row.runId.slice(0, 8)}
              </span>
            {/if}
            {#if row.error}
              <span class="il-row__err">{row.error}</span>
            {/if}
          </li>
        {/each}
      </ul>
    {/if}
  </div>
</div>

<style>
  .il-root {
    display: flex;
    flex-direction: column;
    height: 100%;
    min-height: 0;
    font-family: var(--font-sans);
  }

  .il-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 8px 12px;
    border-bottom: 1px solid var(--border);
  }

  .il-title {
    margin: 0;
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--fg-muted);
  }

  .il-meta {
    font-size: 11px;
    color: var(--fg-subtle);
    display: inline-flex;
    align-items: center;
    gap: 6px;
  }

  .il-meta__spinner {
    display: inline-block;
    animation: il-spin 1.2s linear infinite;
  }

  @keyframes il-spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }

  .il-body {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
  }

  .il-empty {
    margin: 0;
    padding: 24px 12px;
    text-align: center;
    color: var(--fg-subtle);
    font-size: var(--text-sm);
  }
  .il-empty--err { color: oklch(0.6 0.18 25); }

  .il-list {
    list-style: none;
    margin: 0;
    padding: 4px 0;
  }

  .il-row {
    display: grid;
    grid-template-columns: 16px 56px minmax(120px, 1fr) minmax(120px, 2fr) auto auto;
    gap: 8px;
    align-items: center;
    padding: 4px 12px;
    font-size: 11px;
    line-height: 1.3;
    border-bottom: 1px solid color-mix(in oklch, var(--border) 50%, transparent);
  }

  .il-row[data-status='error'] { background: color-mix(in oklch, oklch(0.6 0.18 25) 6%, transparent); }
  .il-row[data-status='pending_review'] { background: color-mix(in oklch, oklch(0.7 0.14 80) 8%, transparent); }

  .il-row__status { display: inline-flex; align-items: center; }
  .il-row[data-status='ok'] .il-row__status { color: oklch(0.65 0.16 145); }
  .il-row[data-status='error'] .il-row__status { color: oklch(0.6 0.18 25); }

  .il-row__ts {
    font-family: var(--font-mono, ui-monospace, monospace);
    color: var(--fg-subtle);
  }

  .il-row__tool {
    font-family: var(--font-mono, ui-monospace, monospace);
    color: var(--fg);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .il-row__args {
    font-family: var(--font-mono, ui-monospace, monospace);
    color: var(--fg-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .il-row__run {
    font-family: var(--font-mono, ui-monospace, monospace);
    color: var(--fg-subtle);
    font-size: 10px;
  }

  .il-row__err {
    color: oklch(0.6 0.18 25);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
</style>
