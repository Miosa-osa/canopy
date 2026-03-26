<!-- src/routes/app/webhooks/+page.svelte -->
<script lang="ts">
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import { webhooksStore } from '$lib/stores/webhooks.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';

  // Re-fetch whenever the active workspace changes (covers onMount + workspace switches)
  $effect(() => {
    const wsId = workspaceStore.activeWorkspaceId ?? undefined;
    void webhooksStore.fetchWebhooks(wsId);
  });

  const AVAILABLE_EVENTS = [
    'agent.started',
    'agent.completed',
    'agent.failed',
    'issue.created',
    'issue.dispatched',
  ] as const;

  function generateSecret(): string {
    const arr = new Uint8Array(24);
    crypto.getRandomValues(arr);
    return Array.from(arr, (b) => b.toString(16).padStart(2, '0')).join('');
  }

  // Create form state
  let showForm = $state(false);
  let formName = $state('');
  let formUrl = $state('');
  let formSelectedEvents = $state<Record<string, boolean>>({});
  let formSecret = $state('');
  let creating = $state(false);
  let formError = $state<string | null>(null);

  function openForm() {
    formSelectedEvents = Object.fromEntries(AVAILABLE_EVENTS.map((e) => [e, false]));
    formSecret = generateSecret();
    showForm = true;
  }

  async function handleCreate() {
    if (!formName.trim() || !formUrl.trim()) return;
    creating = true;
    formError = null;
    const events = AVAILABLE_EVENTS.filter((e) => formSelectedEvents[e]);
    const created = await webhooksStore.createWebhook({
      name: formName.trim(),
      url: formUrl.trim(),
      events: [...events],
      secret: formSecret.trim() || null,
    });
    creating = false;
    if (created) {
      resetForm();
    } else {
      formError = webhooksStore.error;
    }
  }

  function resetForm() {
    showForm = false;
    formName = '';
    formUrl = '';
    formSelectedEvents = {};
    formSecret = '';
    formError = null;
  }
</script>

<PageShell title="Webhooks" badge={webhooksStore.totalCount > 0 ? webhooksStore.totalCount : undefined}>
  {#snippet actions()}
    <button
      class="wh-create-btn"
      onclick={openForm}
      type="button"
      aria-label="Create webhook"
    >
      + Create
    </button>
  {/snippet}

  {#if webhooksStore.loading && webhooksStore.webhooks.length === 0}
    <div class="wh-loading" role="status" aria-live="polite">
      <div class="wh-spinner" aria-hidden="true"></div>
      <span>Loading webhooks…</span>
    </div>
  {:else if webhooksStore.error && webhooksStore.webhooks.length === 0}
    <div class="wh-error" role="alert">
      <p>Failed to load webhooks: {webhooksStore.error}</p>
      <button onclick={() => void webhooksStore.fetchWebhooks()}>Retry</button>
    </div>
  {:else if webhooksStore.webhooks.length === 0}
    <div class="wh-empty" role="status">
      <p>No webhooks configured yet.</p>
    </div>
  {:else}
    <div class="wh-list" role="list" aria-label="Webhooks">
      {#each webhooksStore.webhooks as webhook (webhook.id)}
        <div class="wh-item" role="listitem">
          <div class="wh-info">
            <div class="wh-name">{webhook.name}</div>
            <div class="wh-url">{webhook.url}</div>
            <div class="wh-events">
              {#each webhook.events as ev}
                <span class="wh-ev">{ev}</span>
              {/each}
            </div>
          </div>
          <div class="wh-status">
            <span class="wh-active" class:wh-active--on={webhook.enabled}>
              {webhook.enabled ? 'Active' : 'Inactive'}
            </span>
          </div>
          <button
            class="wh-delete"
            onclick={() => void webhooksStore.deleteWebhook(webhook.id)}
            aria-label="Delete webhook {webhook.name}"
            type="button"
          >
            Delete
          </button>
        </div>
      {/each}
    </div>
  {/if}
</PageShell>

<!-- Create webhook dialog -->
{#if showForm}
  <div
    class="wh-overlay"
    role="dialog"
    aria-modal="true"
    aria-label="Create webhook"
    onclick={(e) => { if (e.target === e.currentTarget) resetForm(); }}
  >
    <div class="wh-dialog">
      <h2 class="wh-dialog-title">New Webhook</h2>

      <div class="wh-field">
        <label class="wh-label" for="wh-name-input">Name</label>
        <input
          id="wh-name-input"
          class="wh-input"
          type="text"
          placeholder="My webhook"
          bind:value={formName}
          autofocus
        />
      </div>

      <div class="wh-field">
        <label class="wh-label" for="wh-url-input">URL</label>
        <input
          id="wh-url-input"
          class="wh-input"
          type="url"
          placeholder="https://example.com/hook"
          bind:value={formUrl}
        />
      </div>

      <fieldset class="wh-fieldset">
        <legend class="wh-label">Events</legend>
        <div class="wh-checkboxes">
          {#each AVAILABLE_EVENTS as ev (ev)}
            <label class="wh-checkbox-label">
              <input type="checkbox" bind:checked={formSelectedEvents[ev]} />
              <span>{ev}</span>
            </label>
          {/each}
        </div>
      </fieldset>

      <div class="wh-field">
        <label class="wh-label" for="wh-secret-input">Secret <span class="wh-label-hint">(auto-generated)</span></label>
        <input
          id="wh-secret-input"
          class="wh-input wh-input--mono"
          type="text"
          bind:value={formSecret}
          readonly
        />
      </div>

      {#if formError}
        <p class="wh-form-error" role="alert">{formError}</p>
      {/if}

      <div class="wh-dialog-actions">
        <button class="wh-btn-ghost" onclick={resetForm} disabled={creating}>Cancel</button>
        <button
          class="wh-btn-primary"
          onclick={handleCreate}
          disabled={creating || !formName.trim() || !formUrl.trim()}
        >
          {creating ? 'Creating…' : 'Create Webhook'}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .wh-create-btn {
    height: 28px; padding: 0 12px; border-radius: 6px; font-size: 12px; font-weight: 500;
    background: #6366f1; border: none; color: white; cursor: pointer; transition: background 120ms ease;
  }
  .wh-create-btn:hover { background: #4f46e5; }

  .wh-loading, .wh-empty, .wh-error {
    display: flex; flex-direction: column; align-items: center;
    justify-content: center; gap: 12px; height: 200px;
    color: var(--dt3); font-size: 13px;
  }
  .wh-spinner {
    width: 24px; height: 24px; border-radius: 50%;
    border: 2px solid var(--dbd); border-top-color: var(--dt2);
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }
  .wh-list { display: flex; flex-direction: column; gap: 8px; padding: 24px; }
  .wh-item {
    display: flex; align-items: center; gap: 16px;
    padding: 14px 16px; border-radius: 8px;
    background: var(--dbg2); border: 1px solid var(--dbd);
  }
  .wh-info { flex: 1; }
  .wh-name { font-size: 14px; font-weight: 500; color: var(--dt); margin-bottom: 2px; }
  .wh-url { font-size: 11px; color: var(--dt3); font-family: var(--font-mono); margin-bottom: 6px; }
  .wh-events { display: flex; gap: 4px; flex-wrap: wrap; }
  .wh-ev { font-size: 10px; padding: 1px 6px; border-radius: 4px; background: var(--dbg3); color: var(--dt3); }
  .wh-status { min-width: 70px; text-align: center; }
  .wh-active { font-size: 12px; padding: 3px 8px; border-radius: 4px; background: var(--dbg3); color: var(--dt3); }
  .wh-active--on { background: rgba(34, 197, 94, 0.12); color: rgba(134, 239, 172, 0.8); }
  .wh-delete {
    padding: 6px 12px; border-radius: 6px; font-size: 12px; cursor: pointer;
    border: 1px solid var(--dbd); background: transparent; color: var(--dt3);
    transition: all 120ms ease;
  }
  .wh-delete:hover { border-color: rgba(239,68,68,0.4); color: #fca5a5; background: rgba(239,68,68,0.08); }

  /* Dialog */
  .wh-overlay {
    position: fixed; inset: 0; background: rgba(0,0,0,0.5);
    display: flex; align-items: center; justify-content: center; z-index: 1000;
  }
  .wh-dialog {
    background: var(--dbg2); border: 1px solid var(--dbd); border-radius: 12px;
    padding: 24px; width: 440px; max-width: calc(100vw - 40px);
    display: flex; flex-direction: column; gap: 16px;
  }
  .wh-dialog-title { font-size: 16px; font-weight: 600; color: var(--dt); margin: 0; }
  .wh-field { display: flex; flex-direction: column; gap: 6px; }
  .wh-label { font-size: 12px; font-weight: 500; color: var(--dt2); }
  .wh-label-hint { font-weight: 400; color: var(--dt4); }
  .wh-input {
    height: 34px; padding: 0 10px; border-radius: 6px; font-size: 13px;
    background: var(--dbg3); border: 1px solid var(--dbd); color: var(--dt);
    width: 100%; box-sizing: border-box;
  }
  .wh-input:focus { outline: none; border-color: #6366f1; }
  .wh-input--mono { font-family: var(--font-mono); font-size: 11px; }
  .wh-fieldset { border: none; padding: 0; margin: 0; }
  .wh-checkboxes { display: flex; flex-direction: column; gap: 6px; margin-top: 4px; }
  .wh-checkbox-label {
    display: flex; align-items: center; gap: 8px; font-size: 13px; color: var(--dt);
    cursor: pointer;
  }
  .wh-checkbox-label input[type="checkbox"] { accent-color: #6366f1; }
  .wh-form-error { font-size: 12px; color: #fca5a5; margin: 0; }
  .wh-dialog-actions { display: flex; gap: 8px; justify-content: flex-end; margin-top: 4px; }
  .wh-btn-ghost, .wh-btn-primary {
    padding: 7px 16px; border-radius: 6px; font-size: 13px; font-weight: 500; cursor: pointer;
    transition: all 120ms ease;
  }
  .wh-btn-ghost { background: transparent; border: 1px solid var(--dbd); color: var(--dt3); }
  .wh-btn-ghost:hover:not(:disabled) { background: var(--dbg3); color: var(--dt2); }
  .wh-btn-primary { background: #6366f1; border: none; color: #fff; }
  .wh-btn-primary:hover:not(:disabled) { background: #4f46e5; }
  .wh-btn-ghost:disabled, .wh-btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
