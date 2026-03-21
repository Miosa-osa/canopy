<script lang="ts">
  import StatusDot from '$lib/components/shared/StatusDot.svelte';
  import { dashboardStore } from '$lib/stores/dashboard.svelte';

  interface Props {
    class?: string;
  }

  let { class: className = '' }: Props = $props();

  type BackendStatus = 'ok' | 'degraded' | 'error' | string;
  type GatewayStatus = 'healthy' | 'degraded' | 'down' | string;

  function backendToDot(status: BackendStatus): 'online' | 'busy' | 'error' {
    if (status === 'ok')       return 'online';
    if (status === 'degraded') return 'busy';
    return 'error';
  }

  function gatewayToDot(status: GatewayStatus): 'online' | 'busy' | 'error' {
    if (status === 'healthy')  return 'online';
    if (status === 'degraded') return 'busy';
    return 'error';
  }

  const health = $derived(dashboardStore.systemHealth);

  const memoryWarning = $derived(health !== null && health.memory_mb > 500);
  const cpuWarning    = $derived(health !== null && health.cpu_pct > 80);

  const backendDot  = $derived(health ? backendToDot(health.backend) : 'idle' as const);
  const gatewayDot  = $derived(health ? gatewayToDot(health.gateway_status) : 'idle' as const);
  const gatewayName = $derived(health?.primary_gateway ?? 'No gateway');
</script>

{#if dashboardStore.isLoading && !health}
  <div
    class="shb-bar shb-bar--loading {className}"
    role="status"
    aria-label="System health loading"
    aria-busy="true"
  >
    <span class="shb-loading-text">Loading system health…</span>
  </div>
{:else if !health}
  <div
    class="shb-bar {className}"
    role="status"
    aria-label="System health unavailable"
  >
    <span class="shb-label shb-label--muted">System health unavailable</span>
  </div>
{:else}
  <div
    class="shb-bar {className}"
    role="status"
    aria-label="System health: backend {health.backend}, memory {health.memory_mb} MB, CPU {health.cpu_pct}%"
  >
    <!-- Backend -->
    <div class="shb-item">
      <StatusDot status={backendDot} size="sm" />
      <span class="shb-label">
        Backend: <span class="shb-val shb-val--{health.backend === 'ok' ? 'ok' : 'warn'}">{health.backend}</span>
      </span>
    </div>

    <div class="shb-sep" aria-hidden="true"></div>

    <!-- Gateway -->
    <div class="shb-item">
      <StatusDot status={gatewayDot} size="sm" />
      <span class="shb-label" title={gatewayName}>
        {gatewayName}
      </span>
    </div>

    <div class="shb-sep" aria-hidden="true"></div>

    <!-- Memory -->
    <div class="shb-item" aria-label="Memory usage: {health.memory_mb} megabytes">
      <svg
        width="12"
        height="12"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        aria-hidden="true"
      >
        <rect x="2" y="6" width="20" height="12" rx="2" />
        <path d="M6 12h.01M10 12h.01M14 12h.01M18 12h.01" />
      </svg>
      <span class="shb-label" class:shb-label--warn={memoryWarning}>
        {health.memory_mb} MB
      </span>
    </div>

    <div class="shb-sep" aria-hidden="true"></div>

    <!-- CPU -->
    <div class="shb-item" aria-label="CPU usage: {health.cpu_pct} percent">
      <svg
        width="12"
        height="12"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        aria-hidden="true"
      >
        <rect x="4" y="4" width="16" height="16" rx="2" />
        <rect x="9" y="9" width="6" height="6" />
        <path d="M9 2v2M15 2v2M9 20v2M15 20v2M2 9h2M2 15h2M20 9h2M20 15h2" />
      </svg>
      <span class="shb-label" class:shb-label--warn={cpuWarning}>
        {health.cpu_pct}%
      </span>
    </div>
  </div>
{/if}

<style>
  .shb-bar {
    display: flex;
    flex-direction: row;
    align-items: center;
    gap: var(--space-5);
    height: 36px;
    padding: 0 var(--space-4);
    background: var(--bg-surface);
    border-top: 1px solid var(--border-default);
    backdrop-filter: blur(8px);
    -webkit-backdrop-filter: blur(8px);
  }

  .shb-item {
    display: flex;
    align-items: center;
    gap: var(--space-1);
  }

  .shb-label {
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--text-secondary);
    white-space: nowrap;
  }

  .shb-label--warn {
    color: var(--accent-warning);
  }

  .shb-val--ok   { color: var(--accent-success); }
  .shb-val--warn { color: var(--accent-warning); }

  .shb-sep {
    width: 1px;
    height: 14px;
    background: var(--border-default);
    flex-shrink: 0;
  }

  .shb-bar--loading {
    opacity: 0.6;
  }

  .shb-loading-text,
  .shb-label--muted {
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--text-tertiary);
  }
</style>
