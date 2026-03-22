<!-- src/lib/components/agents/AgentTable.svelte -->
<script lang="ts">
  import { goto } from '$app/navigation';
  import StatusDot from '$lib/components/shared/StatusDot.svelte';
  import TimeAgo from '$lib/components/shared/TimeAgo.svelte';
  import Badge from '$lib/components/shared/Badge.svelte';
  import type { CanopyAgent, AgentStatus } from '$api/types';

  interface Props {
    agents: CanopyAgent[];
  }

  let { agents }: Props = $props();

  type SortKey = 'name' | 'status' | 'role' | 'adapter' | 'model' | 'cost' | 'last_active';
  type SortDir = 'asc' | 'desc';

  let sortKey = $state<SortKey>('name');
  let sortDir = $state<SortDir>('asc');

  function toggleSort(key: SortKey) {
    if (sortKey === key) {
      sortDir = sortDir === 'asc' ? 'desc' : 'asc';
    } else {
      sortKey = key;
      sortDir = 'asc';
    }
  }

  const sorted = $derived.by(() => {
    const list = [...agents];
    list.sort((a, b) => {
      let cmp = 0;
      switch (sortKey) {
        case 'name':
          cmp = a.display_name.localeCompare(b.display_name);
          break;
        case 'status':
          cmp = a.status.localeCompare(b.status);
          break;
        case 'role':
          cmp = a.role.localeCompare(b.role);
          break;
        case 'adapter':
          cmp = a.adapter.localeCompare(b.adapter);
          break;
        case 'model':
          cmp = a.model.localeCompare(b.model);
          break;
        case 'cost':
          cmp = a.cost_today_cents - b.cost_today_cents;
          break;
        case 'last_active':
          cmp = (a.last_active_at ?? '').localeCompare(b.last_active_at ?? '');
          break;
      }
      return sortDir === 'asc' ? cmp : -cmp;
    });
    return list;
  });

  function statusToDot(s: AgentStatus): 'online' | 'idle' | 'busy' | 'error' | 'offline' | 'sleeping' {
    switch (s) {
      case 'running':    return 'busy';
      case 'active':     return 'busy';
      case 'working':    return 'busy';
      case 'idle':       return 'idle';
      case 'sleeping':   return 'sleeping';
      case 'paused':     return 'offline';
      case 'error':      return 'error';
      case 'terminated': return 'offline';
      default:           return 'offline';
    }
  }

  function formatCost(cents: number): string {
    if (cents === 0) return '$0.00';
    if (cents < 100) return `$0.${cents.toString().padStart(2, '0')}`;
    return `$${(cents / 100).toFixed(2)}`;
  }

  function adapterBadgeVariant(adapter: string): 'default' | 'info' | 'success' | 'accent' {
    switch (adapter) {
      case 'osa':         return 'accent';
      case 'claude_code': return 'info';
      case 'cursor':      return 'success';
      default:            return 'default';
    }
  }
</script>

<div class="at-wrapper" role="region" aria-label="Agents table">
  <table class="at-table">
    <thead>
      <tr>
        {#each [
          { key: 'name' as SortKey, label: 'Name' },
          { key: 'status' as SortKey, label: 'Status' },
          { key: 'role' as SortKey, label: 'Role' },
          { key: 'adapter' as SortKey, label: 'Adapter' },
          { key: 'model' as SortKey, label: 'Model' },
          { key: 'cost' as SortKey, label: 'Cost Today' },
          { key: 'last_active' as SortKey, label: 'Last Active' },
        ] as col}
          <th
            class="at-th"
            class:at-th--sorted={sortKey === col.key}
            aria-sort={sortKey === col.key ? (sortDir === 'asc' ? 'ascending' : 'descending') : 'none'}
          >
            <button
              class="at-sort-btn"
              onclick={() => toggleSort(col.key)}
              aria-label="Sort by {col.label}"
            >
              {col.label}
              <span class="at-sort-icon" aria-hidden="true">
                {#if sortKey === col.key}
                  {sortDir === 'asc' ? '↑' : '↓'}
                {:else}
                  <span class="at-sort-inactive">↕</span>
                {/if}
              </span>
            </button>
          </th>
        {/each}
      </tr>
    </thead>
    <tbody>
      {#each sorted as agent (agent.id)}
        <tr
          class="at-row"
          onclick={() => goto(`/app/agents/${agent.id}`)}
          onkeydown={(e) => { if (e.key === 'Enter') void goto(`/app/agents/${agent.id}`); }}
          tabindex="0"
          role="button"
          aria-label="Open agent {agent.display_name}"
        >
          <!-- Name -->
          <td class="at-td at-td--name">
            <span class="at-emoji" aria-hidden="true">{agent.avatar_emoji}</span>
            <span class="at-name">{agent.display_name}</span>
          </td>

          <!-- Status -->
          <td class="at-td">
            <div class="at-status-cell">
              <StatusDot
                status={statusToDot(agent.status)}
                pulse={agent.status === 'running'}
                size="sm"
              />
              <span class="at-status-text">{agent.status}</span>
            </div>
          </td>

          <!-- Role -->
          <td class="at-td at-td--muted">
            {agent.role}
          </td>

          <!-- Adapter -->
          <td class="at-td">
            <Badge value={agent.adapter} variant={adapterBadgeVariant(agent.adapter)} size="sm" />
          </td>

          <!-- Model -->
          <td class="at-td at-td--mono">
            {agent.model}
          </td>

          <!-- Cost -->
          <td class="at-td at-td--num">
            {formatCost(agent.cost_today_cents)}
          </td>

          <!-- Last Active -->
          <td class="at-td">
            {#if agent.last_active_at}
              <TimeAgo date={agent.last_active_at} short />
            {:else}
              <span class="at-td--muted">—</span>
            {/if}
          </td>
        </tr>
      {/each}

      {#if sorted.length === 0}
        <tr>
          <td colspan="7" class="at-empty">No agents match the current filter.</td>
        </tr>
      {/if}
    </tbody>
  </table>
</div>

<style>
  .at-wrapper {
    overflow-x: auto;
    border: 1px solid var(--border-default);
    border-radius: var(--radius-md);
    background: var(--bg-surface);
  }

  .at-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
    font-family: var(--font-sans);
  }

  .at-th {
    padding: 0;
    border-bottom: 1px solid var(--border-default);
    background: var(--bg-elevated);
    white-space: nowrap;
    font-weight: 500;
    text-align: left;
  }

  .at-th--sorted .at-sort-btn {
    color: var(--text-primary);
  }

  .at-sort-btn {
    display: flex;
    align-items: center;
    gap: 4px;
    width: 100%;
    padding: 8px 12px;
    background: none;
    border: none;
    font-family: inherit;
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.4px;
    color: var(--text-tertiary);
    cursor: pointer;
    white-space: nowrap;
    transition: color 120ms ease;
  }

  .at-sort-btn:hover {
    color: var(--text-primary);
  }

  .at-sort-icon {
    font-size: 10px;
    opacity: 0.7;
  }

  .at-sort-inactive {
    opacity: 0.3;
  }

  .at-row {
    height: 36px;
    cursor: pointer;
    transition: background 100ms ease;
    outline: none;
    border-bottom: 1px solid var(--border-default);
  }

  .at-row:last-child {
    border-bottom: none;
  }

  .at-row:hover {
    background: var(--bg-elevated);
  }

  .at-row:focus-visible {
    outline: 2px solid var(--accent-primary);
    outline-offset: -2px;
  }

  .at-td {
    padding: 0 12px;
    color: var(--text-secondary);
    white-space: nowrap;
    vertical-align: middle;
  }

  .at-td--name {
    display: flex;
    align-items: center;
    gap: 8px;
    color: var(--text-primary);
    font-weight: 500;
    min-width: 140px;
  }

  .at-td--muted {
    color: var(--text-tertiary);
  }

  .at-td--mono {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--text-tertiary);
  }

  .at-td--num {
    font-variant-numeric: tabular-nums;
    text-align: right;
  }

  .at-emoji {
    font-size: 16px;
    line-height: 1;
    flex-shrink: 0;
  }

  .at-name {
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 120px;
  }

  .at-status-cell {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .at-status-text {
    text-transform: capitalize;
  }

  .at-empty {
    padding: 32px 12px;
    text-align: center;
    color: var(--text-muted);
    font-style: italic;
  }
</style>
