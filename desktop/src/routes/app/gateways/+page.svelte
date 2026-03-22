<!-- src/routes/app/gateways/+page.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import { gatewaysStore } from '$lib/stores/gateways.svelte';

  onMount(() => {
    void gatewaysStore.fetchGateways();
  });

  // Create form state
  let showForm = $state(false);
  let formName = $state('');
  let formEndpoint = $state('');
  let formApiKey = $state('');
  let creating = $state(false);
  let formError = $state<string | null>(null);

  async function handleCreate() {
    if (!formName.trim() || !formEndpoint.trim()) return;
    creating = true;
    formError = null;
    const created = await gatewaysStore.createGateway({
      name: formName.trim(),
      endpoint: formEndpoint.trim(),
      // api_key is write-only; the store/API will handle it
      // We pass it under a loose partial since Gateway type tracks api_key_set (bool)
      ...(formApiKey.trim() ? { api_key: formApiKey.trim() } : {}),
    } as Parameters<typeof gatewaysStore.createGateway>[0]);
    creating = false;
    if (created) {
      resetForm();
    } else {
      formError = gatewaysStore.error;
    }
  }

  function resetForm() {
    showForm = false;
    formName = '';
    formEndpoint = '';
    formApiKey = '';
    formError = null;
  }
</script>

<PageShell
  title="Gateways"
  subtitle="{gatewaysStore.healthyCount} healthy"
  badge={gatewaysStore.totalCount > 0 ? gatewaysStore.totalCount : undefined}
>
  {#snippet actions()}
    <button
      class="gw-create-btn"
      onclick={() => showForm = true}
      type="button"
      aria-label="Create gateway"
    >
      + Create
    </button>
  {/snippet}

  {#if gatewaysStore.loading && gatewaysStore.gateways.length === 0}
    <div class="gw-loading" role="status" aria-live="polite">
      <div class="gw-spinner" aria-hidden="true"></div>
      <span>Loading gateways…</span>
    </div>
  {:else if gatewaysStore.error && gatewaysStore.gateways.length === 0}
    <div class="gw-error" role="alert">
      <p>Failed to load gateways: {gatewaysStore.error}</p>
      <button onclick={() => void gatewaysStore.fetchGateways()}>Retry</button>
    </div>
  {:else if gatewaysStore.gateways.length === 0}
    <div class="gw-empty" role="status">
      <p>No gateways configured.</p>
    </div>
  {:else}
    <div class="gw-list" role="list" aria-label="Gateways">
      {#each gatewaysStore.gateways as gw (gw.id)}
        <div class="gw-card" role="listitem">
          <div class="gw-header">
            <div class="gw-name">
              {gw.name}
              {#if gw.is_primary}
                <span class="gw-primary">Primary</span>
              {/if}
            </div>
            <span class="gw-status gw-status--{gw.status}">{gw.status}</span>
          </div>
          <div class="gw-meta">
            <span class="gw-provider">{gw.provider}</span>
            <span class="gw-endpoint">{gw.endpoint}</span>
          </div>
          {#if gw.latency_ms !== null}
            <div class="gw-latency">{gw.latency_ms}ms latency</div>
          {/if}
          {#if gw.models.length > 0}
            <div class="gw-models">
              {#each gw.models.slice(0, 4) as model}
                <span class="gw-model">{model}</span>
              {/each}
              {#if gw.models.length > 4}
                <span class="gw-model-more">+{gw.models.length - 4} more</span>
              {/if}
            </div>
          {/if}
          <div class="gw-actions">
            <button
              class="gw-probe-btn"
              onclick={() => void gatewaysStore.probeGateway(gw.id)}
              aria-label="Probe gateway {gw.name}"
              type="button"
            >
              Probe
            </button>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</PageShell>

<!-- Create gateway dialog -->
{#if showForm}
  <div
    class="gw-overlay"
    role="dialog"
    aria-modal="true"
    aria-label="Create gateway"
    onclick={(e) => { if (e.target === e.currentTarget) resetForm(); }}
  >
    <div class="gw-dialog">
      <h2 class="gw-dialog-title">New Gateway</h2>

      <div class="gw-field">
        <label class="gw-label" for="gw-name-input">Name</label>
        <input
          id="gw-name-input"
          class="gw-input"
          type="text"
          placeholder="My LLM Gateway"
          bind:value={formName}
          autofocus
        />
      </div>

      <div class="gw-field">
        <label class="gw-label" for="gw-endpoint-input">Endpoint URL</label>
        <input
          id="gw-endpoint-input"
          class="gw-input"
          type="url"
          placeholder="https://api.example.com/v1"
          bind:value={formEndpoint}
        />
      </div>

      <div class="gw-field">
        <label class="gw-label" for="gw-apikey-input">API Key</label>
        <input
          id="gw-apikey-input"
          class="gw-input"
          type="password"
          placeholder="sk-…"
          bind:value={formApiKey}
          autocomplete="new-password"
        />
      </div>

      {#if formError}
        <p class="gw-form-error" role="alert">{formError}</p>
      {/if}

      <div class="gw-dialog-actions">
        <button class="gw-btn-ghost" onclick={resetForm} disabled={creating}>Cancel</button>
        <button
          class="gw-btn-primary"
          onclick={handleCreate}
          disabled={creating || !formName.trim() || !formEndpoint.trim()}
        >
          {creating ? 'Creating…' : 'Create Gateway'}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .gw-create-btn {
    height: 28px; padding: 0 12px; border-radius: 6px; font-size: 12px; font-weight: 500;
    background: #6366f1; border: none; color: white; cursor: pointer; transition: background 120ms ease;
  }
  .gw-create-btn:hover { background: #4f46e5; }

  .gw-loading, .gw-empty, .gw-error {
    display: flex; flex-direction: column; align-items: center;
    justify-content: center; gap: 12px; height: 200px;
    color: var(--dt3); font-size: 13px;
  }
  .gw-spinner {
    width: 24px; height: 24px; border-radius: 50%;
    border: 2px solid var(--dbd); border-top-color: var(--dt2);
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }
  .gw-list { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 12px; padding: 24px; }
  .gw-card { background: var(--dbg2); border: 1px solid var(--dbd); border-radius: 10px; padding: 16px; }
  .gw-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px; }
  .gw-name { font-size: 15px; font-weight: 600; color: var(--dt); display: flex; align-items: center; gap: 8px; }
  .gw-primary { font-size: 10px; padding: 2px 6px; border-radius: 4px; background: rgba(99, 102, 241, 0.15); color: #a5b4fc; font-weight: 500; }
  .gw-status { font-size: 11px; padding: 2px 8px; border-radius: 4px; }
  .gw-status--healthy { background: rgba(34, 197, 94, 0.12); color: rgba(134, 239, 172, 0.8); }
  .gw-status--degraded { background: rgba(245, 158, 11, 0.12); color: #fbbf24; }
  .gw-status--down { background: rgba(239, 68, 68, 0.12); color: #fca5a5; }
  .gw-meta { display: flex; gap: 12px; margin-bottom: 8px; }
  .gw-provider { font-size: 12px; color: var(--dt3); font-weight: 500; }
  .gw-endpoint { font-size: 11px; color: var(--dt4); font-family: var(--font-mono); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .gw-latency { font-size: 11px; color: var(--dt3); margin-bottom: 8px; font-variant-numeric: tabular-nums; }
  .gw-models { display: flex; gap: 4px; flex-wrap: wrap; margin-bottom: 12px; }
  .gw-model { font-size: 10px; padding: 1px 6px; border-radius: 4px; background: var(--dbg3); color: var(--dt3); }
  .gw-model-more { font-size: 10px; color: var(--dt4); }
  .gw-actions { display: flex; justify-content: flex-end; }
  .gw-probe-btn {
    padding: 5px 12px; border-radius: 6px; font-size: 12px; cursor: pointer;
    border: 1px solid var(--dbd); background: transparent; color: var(--dt2);
    transition: all 120ms ease;
  }
  .gw-probe-btn:hover { background: var(--dbg3); border-color: var(--dbd2); }

  /* Dialog */
  .gw-overlay {
    position: fixed; inset: 0; background: rgba(0,0,0,0.5);
    display: flex; align-items: center; justify-content: center; z-index: 1000;
  }
  .gw-dialog {
    background: var(--dbg2); border: 1px solid var(--dbd); border-radius: 12px;
    padding: 24px; width: 440px; max-width: calc(100vw - 40px);
    display: flex; flex-direction: column; gap: 16px;
  }
  .gw-dialog-title { font-size: 16px; font-weight: 600; color: var(--dt); margin: 0; }
  .gw-field { display: flex; flex-direction: column; gap: 6px; }
  .gw-label { font-size: 12px; font-weight: 500; color: var(--dt2); }
  .gw-input {
    height: 34px; padding: 0 10px; border-radius: 6px; font-size: 13px;
    background: var(--dbg3); border: 1px solid var(--dbd); color: var(--dt);
    width: 100%; box-sizing: border-box;
  }
  .gw-input:focus { outline: none; border-color: #6366f1; }
  .gw-form-error { font-size: 12px; color: #fca5a5; margin: 0; }
  .gw-dialog-actions { display: flex; gap: 8px; justify-content: flex-end; margin-top: 4px; }
  .gw-btn-ghost, .gw-btn-primary {
    padding: 7px 16px; border-radius: 6px; font-size: 13px; font-weight: 500; cursor: pointer;
    transition: all 120ms ease;
  }
  .gw-btn-ghost { background: transparent; border: 1px solid var(--dbd); color: var(--dt3); }
  .gw-btn-ghost:hover:not(:disabled) { background: var(--dbg3); color: var(--dt2); }
  .gw-btn-primary { background: #6366f1; border: none; color: #fff; }
  .gw-btn-primary:hover:not(:disabled) { background: #4f46e5; }
  .gw-btn-ghost:disabled, .gw-btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
