<!-- src/lib/components/costs/BudgetIncidentLog.svelte -->
<script lang="ts">
  import { costsStore } from '$lib/stores/costs.svelte';
  import type { BudgetIncident } from '$api/types';

  const PAGE_SIZE = 10;
  let page = $state(0);
  let expandedId = $state<string | null>(null);

  // Sort newest first
  const sorted = $derived(
    [...costsStore.incidents].sort(
      (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
    )
  );

  const totalPages = $derived(Math.ceil(sorted.length / PAGE_SIZE));

  const pageItems = $derived(
    sorted.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE)
  );

  function fmtTime(iso: string): string {
    const d = new Date(iso);
    const now = Date.now();
    const diff = now - d.getTime();
    if (diff < 60_000) return 'Just now';
    if (diff < 3_600_000) return Math.floor(diff / 60_000) + 'm ago';
    if (diff < 86_400_000) return Math.floor(diff / 3_600_000) + 'h ago';
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  }

  function fmtCents(cents: number): string {
    return '$' + (cents / 100).toFixed(2);
  }

  function typeLabel(type: BudgetIncident['type']): string {
    if (type === 'hard_stop') return 'Hard Stop';
    if (type === 'anomaly') return 'Anomaly';
    return 'Warning';
  }

  function toggleExpand(id: string) {
    expandedId = expandedId === id ? null : id;
  }

  let resolvingId = $state<string | null>(null);

  async function handleResolve(id: string) {
    resolvingId = id;
    try {
      await costsStore.resolveIncident(id);
    } finally {
      resolvingId = null;
    }
  }
</script>

<article class="bil-panel" aria-label="Budget incident log">
  <header class="bil-header">
    <span class="bil-title">Budget Incidents</span>
    <span class="bil-count">{costsStore.incidents.length} total</span>
  </header>

  {#if costsStore.incidents.length === 0}
    <div class="bil-empty">No budget incidents in the last 30 days</div>
  {:else}
    <div class="bil-table-wrap" role="region" aria-label="Budget incidents">
      <table class="bil-table">
        <thead>
          <tr>
            <th class="bil-th">Time</th>
            <th class="bil-th">Agent</th>
            <th class="bil-th">Type</th>
            <th class="bil-th bil-th--num">Amount</th>
            <th class="bil-th bil-th--num">Limit</th>
            <th class="bil-th">Status</th>
            <th class="bil-th bil-th--actions">Detail</th>
          </tr>
        </thead>
        <tbody>
          {#each pageItems as incident (incident.id)}
            <tr
              class="bil-row bil-row--{incident.type}"
              class:bil-row--resolved={incident.resolved}
            >
              <td class="bil-td bil-td--time">{fmtTime(incident.created_at)}</td>
              <td class="bil-td">
                <span class="bil-agent">{incident.agent_name}</span>
              </td>
              <td class="bil-td">
                <span class="bil-type bil-type--{incident.type}">
                  {typeLabel(incident.type)}
                </span>
              </td>
              <td class="bil-td bil-td--num bil-td--amount">
                {fmtCents(incident.amount_cents)}
              </td>
              <td class="bil-td bil-td--num">
                {fmtCents(incident.limit_cents)}
              </td>
              <td class="bil-td">
                <span class="bil-resolved bil-resolved--{incident.resolved ? 'yes' : 'no'}">
                  {incident.resolved ? 'Resolved' : 'Active'}
                </span>
              </td>
              <td class="bil-td bil-td--actions">
                <button
                  class="bil-expand-btn"
                  onclick={() => toggleExpand(incident.id)}
                  aria-expanded={expandedId === incident.id}
                  aria-label="Toggle detail for incident {incident.id}"
                >
                  <svg
                    width="12"
                    height="12"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2.5"
                    aria-hidden="true"
                    style="transform: rotate({expandedId === incident.id ? 180 : 0}deg); transition: transform 150ms ease"
                  >
                    <path d="M6 9l6 6 6-6" />
                  </svg>
                </button>
              </td>
            </tr>

            {#if expandedId === incident.id}
              <tr class="bil-detail-row">
                <td colspan="7" class="bil-detail-cell">
                  <div class="bil-detail-inner">
                    <p class="bil-detail-msg">{incident.message}</p>
                    {#if !incident.resolved}
                      <button
                        class="bil-resolve-btn"
                        onclick={() => handleResolve(incident.id)}
                        disabled={resolvingId === incident.id}
                        aria-label="Resolve incident {incident.id}"
                      >
                        {#if resolvingId === incident.id}
                          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true" class="bil-spinner">
                            <path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83" />
                          </svg>
                          Resolving…
                        {:else}
                          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true">
                            <polyline points="20 6 9 17 4 12" />
                          </svg>
                          Resolve
                        {/if}
                      </button>
                    {/if}
                  </div>
                </td>
              </tr>
            {/if}
          {/each}
        </tbody>
      </table>
    </div>

    {#if totalPages > 1}
      <div class="bil-pagination" role="navigation" aria-label="Incident log pagination">
        <button
          class="bil-page-btn"
          onclick={() => page = Math.max(0, page - 1)}
          disabled={page === 0}
          aria-label="Previous page"
        >
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true">
            <path d="M15 18l-6-6 6-6" />
          </svg>
        </button>
        <span class="bil-page-info">{page + 1} / {totalPages}</span>
        <button
          class="bil-page-btn"
          onclick={() => page = Math.min(totalPages - 1, page + 1)}
          disabled={page === totalPages - 1}
          aria-label="Next page"
        >
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true">
            <path d="M9 18l6-6-6-6" />
          </svg>
        </button>
      </div>
    {/if}
  {/if}
</article>

<style>
  .bil-panel {
    background: var(--bg-surface);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-lg);
    padding: var(--space-4);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .bil-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .bil-title {
    font-family: var(--font-sans);
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary);
  }

  .bil-count {
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--text-tertiary);
  }

  .bil-empty {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 60px;
    font-size: 13px;
    color: var(--text-tertiary);
  }

  .bil-table-wrap {
    overflow-x: auto;
  }

  .bil-table {
    width: 100%;
    border-collapse: collapse;
    font-family: var(--font-sans);
    font-size: 12px;
  }

  .bil-th {
    padding: var(--space-2);
    text-align: left;
    color: var(--text-tertiary);
    font-weight: 500;
    font-size: 11px;
    letter-spacing: 0.3px;
    border-bottom: 1px solid var(--border-default);
    white-space: nowrap;
  }

  .bil-th--num { text-align: right; }
  .bil-th--actions { width: 40px; }

  .bil-row {
    border-bottom: 1px solid var(--border-default);
    transition: background 120ms ease;
  }

  .bil-row:hover { background: var(--bg-elevated); }

  .bil-row--resolved { opacity: 0.6; }

  .bil-row--warning  { border-left: 2px solid rgba(245, 158, 11, 0.4); }
  .bil-row--hard_stop { border-left: 2px solid rgba(239, 68, 68, 0.5); }
  .bil-row--anomaly  { border-left: 2px solid rgba(167, 139, 250, 0.5); }

  .bil-td {
    padding: var(--space-2);
    color: var(--text-secondary);
    vertical-align: middle;
  }

  .bil-td--num { text-align: right; font-variant-numeric: tabular-nums; }
  .bil-td--time { color: var(--text-tertiary); white-space: nowrap; }
  .bil-td--amount { color: var(--text-primary); font-weight: 600; }
  .bil-td--actions { text-align: center; }

  .bil-agent {
    color: var(--text-primary);
    font-weight: 500;
  }

  .bil-type {
    display: inline-flex;
    align-items: center;
    padding: 2px 6px;
    border-radius: var(--radius-xs);
    font-size: 11px;
    font-weight: 500;
  }

  .bil-type--warning  { color: #f59e0b; background: rgba(245,158,11,0.1); }
  .bil-type--hard_stop { color: #ef4444; background: rgba(239,68,68,0.1); }
  .bil-type--anomaly  { color: #a78bfa; background: rgba(167,139,250,0.1); }

  .bil-resolved {
    font-size: 11px;
    font-weight: 500;
    padding: 2px 6px;
    border-radius: var(--radius-xs);
  }

  .bil-resolved--yes { color: rgba(34, 197, 94, 0.7); background: rgba(34,197,94,0.08); }
  .bil-resolved--no  { color: #f59e0b; background: rgba(245,158,11,0.1); }

  .bil-expand-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 26px;
    height: 26px;
    background: none;
    border: 1px solid var(--border-default);
    border-radius: var(--radius-xs);
    color: var(--text-tertiary);
    cursor: pointer;
    transition: border-color 120ms ease, color 120ms ease;
  }

  .bil-expand-btn:hover {
    border-color: var(--border-hover);
    color: var(--text-primary);
  }

  .bil-detail-row {
    background: var(--bg-elevated);
  }

  .bil-detail-cell {
    padding: var(--space-2) var(--space-4);
  }

  .bil-detail-inner {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: var(--space-3);
    flex-wrap: wrap;
  }

  .bil-detail-msg {
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--text-secondary);
    margin: 0;
    line-height: 1.5;
    flex: 1;
  }

  .bil-resolve-btn {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
    background: rgba(34, 197, 94, 0.1);
    border: 1px solid rgba(34, 197, 94, 0.3);
    border-radius: var(--radius-xs);
    color: rgba(34, 197, 94, 0.8);
    font-family: var(--font-sans);
    font-size: 12px;
    font-weight: 500;
    padding: 4px 10px;
    cursor: pointer;
    white-space: nowrap;
    transition: background 120ms ease, border-color 120ms ease;
    flex-shrink: 0;
  }

  .bil-resolve-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .bil-resolve-btn:not(:disabled):hover {
    background: rgba(34, 197, 94, 0.18);
    border-color: rgba(34, 197, 94, 0.5);
  }

  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }

  .bil-spinner {
    animation: spin 800ms linear infinite;
  }

  .bil-pagination {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: var(--space-3);
  }

  .bil-page-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    background: none;
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
    color: var(--text-secondary);
    cursor: pointer;
    transition: border-color 120ms ease, color 120ms ease;
  }

  .bil-page-btn:hover:not(:disabled) {
    border-color: var(--border-hover);
    color: var(--text-primary);
  }

  .bil-page-btn:disabled {
    opacity: 0.3;
    cursor: not-allowed;
  }

  .bil-page-info {
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--text-tertiary);
  }
</style>
