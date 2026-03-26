<!-- src/routes/app/secrets/+page.svelte -->
<script lang="ts">
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import { secretsStore } from '$lib/stores/secrets.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';
  import type { SecretType } from '$api/types';

  $effect(() => {
    const wsId = workspaceStore.activeWorkspaceId;
    void secretsStore.fetchSecrets(wsId ?? undefined);
  });

  // Create form state
  let showForm = $state(false);
  let formName = $state('');
  let formValue = $state('');
  let formType = $state<SecretType>('api_key');
  let formDescription = $state('');
  let creating = $state(false);
  let formError = $state<string | null>(null);

  // Rotate confirmation state
  let rotatingId = $state<string | null>(null);
  let confirmRotateId = $state<string | null>(null);

  // Delete confirmation state
  let confirmDeleteId = $state<string | null>(null);

  const SECRET_TYPES: { value: SecretType; label: string }[] = [
    { value: 'api_key', label: 'API Key' },
    { value: 'password', label: 'Password' },
    { value: 'token', label: 'Token' },
    { value: 'certificate', label: 'Certificate' },
    { value: 'other', label: 'Other' },
  ];

  async function handleCreate() {
    if (!formName.trim() || !formValue.trim()) return;
    creating = true;
    formError = null;
    const created = await secretsStore.createSecret({
      name: formName.trim(),
      value: formValue.trim(),
      type: formType,
      description: formDescription.trim() || undefined,
    });
    creating = false;
    if (created) {
      resetForm();
    } else {
      formError = secretsStore.error;
    }
  }

  function resetForm() {
    showForm = false;
    formName = '';
    formValue = '';
    formType = 'api_key';
    formDescription = '';
    formError = null;
  }

  async function handleRotate(id: string) {
    if (confirmRotateId !== id) {
      confirmRotateId = id;
      return;
    }
    confirmRotateId = null;
    rotatingId = id;
    await secretsStore.rotateSecret(id);
    rotatingId = null;
  }

  async function handleDelete(id: string) {
    if (confirmDeleteId !== id) {
      confirmDeleteId = id;
      return;
    }
    confirmDeleteId = null;
    await secretsStore.deleteSecret(id);
  }

  function typeLabel(type: SecretType): string {
    return SECRET_TYPES.find((t) => t.value === type)?.label ?? type;
  }

  function formatDate(dateStr: string | null): string {
    if (!dateStr) return '—';
    return new Date(dateStr).toLocaleDateString();
  }
</script>

<PageShell
  title="Secrets"
  subtitle="Encrypted values for agents and integrations"
  badge={secretsStore.totalCount > 0 ? secretsStore.totalCount : undefined}
>
  {#snippet actions()}
    <button
      class="sc-create-btn"
      onclick={() => showForm = true}
      type="button"
      aria-label="Add secret"
    >
      + Add Secret
    </button>
  {/snippet}

  {#if secretsStore.loading && secretsStore.secrets.length === 0}
    <div class="sc-loading" role="status" aria-live="polite">
      <div class="sc-spinner" aria-hidden="true"></div>
      <span>Loading secrets…</span>
    </div>
  {:else if secretsStore.error && secretsStore.secrets.length === 0}
    <div class="sc-empty" role="alert">
      <p>Failed to load secrets: {secretsStore.error}</p>
      <button class="sc-retry-btn" onclick={() => void secretsStore.fetchSecrets()}>Retry</button>
    </div>
  {:else if secretsStore.secrets.length === 0}
    <div class="sc-empty" role="status">
      <svg class="sc-empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true">
        <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
      </svg>
      <p>No secrets stored yet.</p>
      <button class="sc-create-btn" onclick={() => showForm = true}>Add your first secret</button>
    </div>
  {:else}
    <div class="sc-list" role="list" aria-label="Secrets">
      {#each secretsStore.secrets as secret (secret.id)}
        <div class="sc-item" role="listitem">
          <div class="sc-icon-col" aria-hidden="true">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="16" height="16">
              <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
            </svg>
          </div>
          <div class="sc-info">
            <div class="sc-name">{secret.name}</div>
            {#if secret.description}
              <div class="sc-desc">{secret.description}</div>
            {/if}
            <div class="sc-meta">
              <span class="sc-type">{typeLabel(secret.type)}</span>
              <span class="sc-dot" aria-hidden="true">·</span>
              <span class="sc-masked" aria-label="Value hidden">••••••••••••</span>
            </div>
          </div>
          <div class="sc-dates">
            <div class="sc-date-row">
              <span class="sc-date-label">Created</span>
              <time class="sc-date-val" datetime={secret.created_at}>{formatDate(secret.created_at)}</time>
            </div>
            {#if secret.last_rotated_at}
              <div class="sc-date-row">
                <span class="sc-date-label">Rotated</span>
                <time class="sc-date-val" datetime={secret.last_rotated_at}>{formatDate(secret.last_rotated_at)}</time>
              </div>
            {/if}
            {#if secret.expires_at}
              <div class="sc-date-row">
                <span class="sc-date-label">Expires</span>
                <time
                  class="sc-date-val"
                  class:sc-date-val--warning={secretsStore.expiringSoon.some((s) => s.id === secret.id)}
                  datetime={secret.expires_at}
                >
                  {formatDate(secret.expires_at)}
                </time>
              </div>
            {/if}
          </div>
          <div class="sc-actions">
            <button
              class="sc-action-btn sc-rotate-btn"
              class:sc-action-btn--confirm={confirmRotateId === secret.id}
              onclick={() => void handleRotate(secret.id)}
              disabled={rotatingId === secret.id}
              aria-label={confirmRotateId === secret.id ? 'Confirm rotate' : `Rotate secret ${secret.name}`}
              type="button"
            >
              {#if rotatingId === secret.id}
                Rotating…
              {:else if confirmRotateId === secret.id}
                Confirm rotate?
              {:else}
                Rotate
              {/if}
            </button>
            <button
              class="sc-action-btn sc-delete-btn"
              class:sc-action-btn--confirm={confirmDeleteId === secret.id}
              onclick={() => void handleDelete(secret.id)}
              aria-label={confirmDeleteId === secret.id ? 'Confirm delete' : `Delete secret ${secret.name}`}
              type="button"
            >
              {confirmDeleteId === secret.id ? 'Confirm?' : 'Delete'}
            </button>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</PageShell>

<!-- Add Secret dialog -->
{#if showForm}
  <div
    class="sc-overlay"
    role="dialog"
    aria-modal="true"
    aria-label="Add secret"
    onclick={(e) => { if (e.target === e.currentTarget) resetForm(); }}
  >
    <div class="sc-dialog">
      <h2 class="sc-dialog-title">New Secret</h2>

      <div class="sc-field">
        <label class="sc-label" for="sc-name-input">Name</label>
        <input
          id="sc-name-input"
          class="sc-input"
          type="text"
          placeholder="MY_API_KEY"
          bind:value={formName}
          autofocus
        />
      </div>

      <div class="sc-field">
        <label class="sc-label" for="sc-value-input">Value</label>
        <input
          id="sc-value-input"
          class="sc-input"
          type="password"
          placeholder="The secret value (never shown again)"
          bind:value={formValue}
        />
      </div>

      <div class="sc-field">
        <label class="sc-label" for="sc-type-select">Type</label>
        <select id="sc-type-select" class="sc-input sc-select" bind:value={formType}>
          {#each SECRET_TYPES as t (t.value)}
            <option value={t.value}>{t.label}</option>
          {/each}
        </select>
      </div>

      <div class="sc-field">
        <label class="sc-label" for="sc-desc-input">
          Description <span class="sc-label-hint">(optional)</span>
        </label>
        <input
          id="sc-desc-input"
          class="sc-input"
          type="text"
          placeholder="What is this secret used for?"
          bind:value={formDescription}
        />
      </div>

      {#if formError}
        <p class="sc-form-error" role="alert">{formError}</p>
      {/if}

      <div class="sc-dialog-actions">
        <button class="sc-btn-ghost" onclick={resetForm} disabled={creating} type="button">Cancel</button>
        <button
          class="sc-btn-primary"
          onclick={handleCreate}
          disabled={creating || !formName.trim() || !formValue.trim()}
          type="button"
        >
          {creating ? 'Storing…' : 'Store Secret'}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .sc-create-btn {
    height: 28px; padding: 0 12px; border-radius: 6px; font-size: 12px; font-weight: 500;
    background: #6366f1; border: none; color: white; cursor: pointer; transition: background 120ms ease;
  }
  .sc-create-btn:hover { background: #4f46e5; }

  .sc-loading, .sc-empty {
    display: flex; flex-direction: column; align-items: center;
    justify-content: center; gap: 12px; height: 240px;
    color: var(--dt3); font-size: 13px;
  }
  .sc-empty-icon { width: 32px; height: 32px; color: var(--dt4); }
  .sc-spinner {
    width: 24px; height: 24px; border-radius: 50%;
    border: 2px solid var(--dbd); border-top-color: var(--dt2);
    animation: sc-spin 0.8s linear infinite;
  }
  @keyframes sc-spin { to { transform: rotate(360deg); } }
  .sc-retry-btn {
    padding: 6px 14px; border-radius: 6px; font-size: 12px; cursor: pointer;
    border: 1px solid var(--dbd); background: var(--dbg2); color: var(--dt2);
  }

  .sc-list { display: flex; flex-direction: column; gap: 6px; padding: 24px; }
  .sc-item {
    display: flex; align-items: center; gap: 14px;
    padding: 14px 16px; border-radius: 8px;
    background: var(--dbg2); border: 1px solid var(--dbd);
    transition: background 120ms ease;
  }
  .sc-item:hover { background: var(--dbg3); }

  .sc-icon-col {
    width: 28px; height: 28px; border-radius: 6px;
    background: color-mix(in srgb, #6366f1 12%, var(--dbg3));
    display: flex; align-items: center; justify-content: center;
    color: #a5b4fc; flex-shrink: 0;
  }

  .sc-info { flex: 1; min-width: 0; }
  .sc-name { font-size: 13px; font-weight: 500; color: var(--dt); font-family: var(--font-mono); }
  .sc-desc { font-size: 11px; color: var(--dt3); margin-top: 2px; }
  .sc-meta { display: flex; align-items: center; gap: 6px; margin-top: 4px; }
  .sc-type {
    font-size: 10px; padding: 1px 6px; border-radius: 4px;
    background: var(--dbg3); color: var(--dt3); text-transform: capitalize;
  }
  .sc-dot { color: var(--dt4); }
  .sc-masked { font-size: 12px; color: var(--dt4); letter-spacing: 2px; }

  .sc-dates { display: flex; flex-direction: column; gap: 4px; min-width: 130px; }
  .sc-date-row { display: flex; justify-content: space-between; gap: 8px; }
  .sc-date-label { font-size: 10px; color: var(--dt4); }
  .sc-date-val { font-size: 11px; color: var(--dt3); }
  .sc-date-val--warning { color: #fbbf24; }

  .sc-actions { display: flex; gap: 6px; flex-shrink: 0; }
  .sc-action-btn {
    padding: 5px 10px; border-radius: 5px; font-size: 11px; font-weight: 500;
    cursor: pointer; border: 1px solid var(--dbd); background: transparent;
    color: var(--dt3); transition: all 120ms ease; white-space: nowrap;
  }
  .sc-action-btn:disabled { opacity: 0.5; cursor: not-allowed; }
  .sc-rotate-btn:hover:not(:disabled) { border-color: rgba(99,102,241,0.4); color: #a5b4fc; background: rgba(99,102,241,0.08); }
  .sc-rotate-btn.sc-action-btn--confirm { border-color: rgba(251,191,36,0.4); color: #fbbf24; background: rgba(251,191,36,0.08); }
  .sc-delete-btn:hover:not(:disabled) { border-color: rgba(239,68,68,0.4); color: #fca5a5; background: rgba(239,68,68,0.08); }
  .sc-delete-btn.sc-action-btn--confirm { border-color: rgba(239,68,68,0.6); color: #fca5a5; background: rgba(239,68,68,0.12); }

  /* Dialog */
  .sc-overlay {
    position: fixed; inset: 0; background: rgba(0,0,0,0.5);
    display: flex; align-items: center; justify-content: center; z-index: 1000;
  }
  .sc-dialog {
    background: var(--dbg2); border: 1px solid var(--dbd); border-radius: 12px;
    padding: 24px; width: 440px; max-width: calc(100vw - 40px);
    display: flex; flex-direction: column; gap: 16px;
  }
  .sc-dialog-title { font-size: 16px; font-weight: 600; color: var(--dt); margin: 0; }
  .sc-field { display: flex; flex-direction: column; gap: 6px; }
  .sc-label { font-size: 12px; font-weight: 500; color: var(--dt2); }
  .sc-label-hint { font-weight: 400; color: var(--dt4); }
  .sc-input {
    height: 34px; padding: 0 10px; border-radius: 6px; font-size: 13px;
    background: var(--dbg3); border: 1px solid var(--dbd); color: var(--dt);
    width: 100%; box-sizing: border-box;
  }
  .sc-select { appearance: none; cursor: pointer; }
  .sc-input:focus { outline: none; border-color: #6366f1; }
  .sc-form-error { font-size: 12px; color: #fca5a5; margin: 0; }
  .sc-dialog-actions { display: flex; gap: 8px; justify-content: flex-end; margin-top: 4px; }
  .sc-btn-ghost, .sc-btn-primary {
    padding: 7px 16px; border-radius: 6px; font-size: 13px; font-weight: 500; cursor: pointer;
    transition: all 120ms ease;
  }
  .sc-btn-ghost { background: transparent; border: 1px solid var(--dbd); color: var(--dt3); }
  .sc-btn-ghost:hover:not(:disabled) { background: var(--dbg3); color: var(--dt2); }
  .sc-btn-primary { background: #6366f1; border: none; color: #fff; }
  .sc-btn-primary:hover:not(:disabled) { background: #4f46e5; }
  .sc-btn-ghost:disabled, .sc-btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
