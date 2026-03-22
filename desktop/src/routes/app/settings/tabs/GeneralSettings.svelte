<!-- src/routes/app/settings/tabs/GeneralSettings.svelte -->
<script lang="ts">
  import { goto } from '$app/navigation';
  import { settingsStore } from '$lib/stores/settings.svelte';
  import { clearToken, clearCache } from '$api/client';

  let loggingOut = $state(false);

  async function handleLogout() {
    loggingOut = true;
    await clearToken();
    clearCache();
    try {
      localStorage.removeItem('canopy-workspaces');
      localStorage.removeItem('canopy-active-workspace');
      localStorage.removeItem('canopy-onboarding');
      localStorage.removeItem('canopy-onboarding-complete');
      localStorage.removeItem('canopy-offline-queue');
    } catch { /* non-fatal */ }
    goto('/');
  }

  const ADAPTER_OPTIONS: { value: string; label: string }[] = [
    { value: 'osa',         label: 'OSA (default)' },
    { value: 'claude_code', label: 'Claude Code' },
    { value: 'codex',       label: 'Codex' },
    { value: 'openclaw',    label: 'OpenClaw' },
    { value: 'jidoclaw',    label: 'JidoClaw' },
    { value: 'hermes',      label: 'Hermes' },
    { value: 'bash',        label: 'Bash' },
    { value: 'http',        label: 'HTTP' },
    { value: 'custom',      label: 'Custom' },
  ];
</script>

<section class="stg-section">
  <h2 class="stg-section-title">General</h2>

  <div class="stg-card">
    <div class="stg-field">
      <label class="stg-label" for="working-dir">Working Directory</label>
      <p class="stg-desc">Default workspace path for agent file operations.</p>
      <input
        id="working-dir"
        class="stg-input"
        type="text"
        placeholder="/Users/you/projects"
        value={settingsStore.data.working_directory}
        oninput={(e) => settingsStore.update('working_directory', (e.target as HTMLInputElement).value)}
      />
    </div>

    <div class="stg-sep"></div>

    <div class="stg-field">
      <label class="stg-label" for="default-adapter">Default Adapter</label>
      <p class="stg-desc">The execution adapter used when spawning new agents.</p>
      <select
        id="default-adapter"
        class="stg-select"
        value={settingsStore.data.default_adapter}
        onchange={(e) => settingsStore.update('default_adapter', (e.target as HTMLSelectElement).value as typeof settingsStore.data.default_adapter)}
      >
        {#each ADAPTER_OPTIONS as opt (opt.value)}
          <option value={opt.value}>{opt.label}</option>
        {/each}
      </select>
    </div>

    <div class="stg-sep"></div>

    <div class="stg-field">
      <label class="stg-label" for="default-model">Default Model</label>
      <p class="stg-desc">Model identifier used for new sessions (e.g. claude-sonnet-4-6).</p>
      <input
        id="default-model"
        class="stg-input"
        type="text"
        placeholder="claude-sonnet-4-6"
        value={settingsStore.data.default_model}
        oninput={(e) => settingsStore.update('default_model', (e.target as HTMLInputElement).value)}
      />
    </div>
  </div>
</section>

<section class="stg-logout-section">
  <div class="stg-logout-card">
    <div class="stg-logout-info">
      <span class="stg-logout-title">Log Out</span>
      <span class="stg-logout-desc">Sign out of your account and clear all local session data.</span>
    </div>
    <button
      class="stg-logout-btn"
      onclick={handleLogout}
      disabled={loggingOut}
    >
      {loggingOut ? 'Logging out...' : 'Log Out'}
    </button>
  </div>
</section>

<style>
  .stg-section { max-width: 640px; }

  .stg-section-title {
    font-size: 15px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0 0 4px;
  }

  .stg-card {
    background: var(--bg-surface);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-md);
    padding: 4px 0;
    margin-top: 16px;
  }

  .stg-sep {
    height: 1px;
    background: var(--border-default);
    margin: 0;
  }

  .stg-field {
    padding: 14px 16px;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .stg-label {
    font-size: 13px;
    font-weight: 500;
    color: var(--text-primary);
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .stg-desc {
    font-size: 12px;
    color: var(--text-tertiary);
    line-height: 1.5;
  }

  .stg-input {
    width: 100%;
    padding: 7px 10px;
    font-size: 13px;
    color: var(--text-primary);
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
    outline: none;
    transition: border-color var(--transition-fast);
  }

  .stg-input:focus { border-color: var(--border-focus); }
  .stg-input::placeholder { color: var(--text-muted); }

  .stg-select {
    width: 100%;
    padding: 7px 10px;
    font-size: 13px;
    color: var(--text-primary);
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
    outline: none;
    cursor: pointer;
    transition: border-color var(--transition-fast);
    appearance: auto;
  }

  .stg-select:focus { border-color: var(--border-focus); }

  .stg-logout-section {
    max-width: 640px;
    margin-top: 32px;
  }

  .stg-logout-card {
    background: var(--bg-surface);
    border: 1px solid var(--border-danger, #ef4444);
    border-radius: var(--radius-md);
    padding: 20px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 16px;
  }

  .stg-logout-info {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .stg-logout-title {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
  }

  .stg-logout-desc {
    font-size: 12px;
    color: var(--text-tertiary);
    line-height: 1.5;
  }

  .stg-logout-btn {
    padding: 8px 20px;
    font-size: 13px;
    font-weight: 500;
    color: #fff;
    background: var(--color-danger, #ef4444);
    border: none;
    border-radius: var(--radius-sm);
    cursor: pointer;
    white-space: nowrap;
    transition: opacity var(--transition-fast);
  }

  .stg-logout-btn:hover { opacity: 0.9; }
  .stg-logout-btn:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
