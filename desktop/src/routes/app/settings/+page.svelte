<!-- src/routes/app/settings/+page.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import { settingsStore } from '$lib/stores/settings.svelte';
  import { toastStore } from '$lib/stores/toasts.svelte';

  import GeneralSettings from './tabs/GeneralSettings.svelte';
  import AppearanceSettings from './tabs/AppearanceSettings.svelte';
  import SidebarSettings from './tabs/SidebarSettings.svelte';
  import AgentsSettings from './tabs/AgentsSettings.svelte';
  import BudgetSettings from './tabs/BudgetSettings.svelte';
  import NotificationsSettings from './tabs/NotificationsSettings.svelte';
  import IntegrationsSettings from './tabs/IntegrationsSettings.svelte';
  import AdvancedSettings from './tabs/AdvancedSettings.svelte';

  type TabId = 'general' | 'appearance' | 'sidebar' | 'agents' | 'budget' | 'notifications' | 'integrations' | 'advanced';

  const tabs: { id: TabId; label: string }[] = [
    { id: 'general',       label: 'General' },
    { id: 'appearance',    label: 'Appearance' },
    { id: 'sidebar',       label: 'Sidebar' },
    { id: 'agents',        label: 'Agents' },
    { id: 'budget',        label: 'Budget' },
    { id: 'notifications', label: 'Notifications' },
    { id: 'integrations',  label: 'Integrations' },
    { id: 'advanced',      label: 'Advanced' },
  ];

  let activeTab = $state<TabId>('general');

  onMount(() => {
    void settingsStore.fetch();
  });

  async function handleSave() {
    await settingsStore.save();
    if (!settingsStore.error) {
      toastStore.success('Settings saved');
    } else {
      toastStore.error('Failed to save settings', settingsStore.error);
    }
  }
</script>

<PageShell title="Settings" subtitle={settingsStore.dirty ? 'Unsaved changes' : undefined}>
  <div class="stg-layout">

    <!-- Left tab nav -->
    <nav class="stg-tabs" aria-label="Settings sections">
      {#each tabs as tab (tab.id)}
        <button
          class="stg-tab"
          class:stg-tab--active={activeTab === tab.id}
          onclick={() => { activeTab = tab.id; }}
          aria-current={activeTab === tab.id ? 'page' : undefined}
        >
          {tab.label}
        </button>
      {/each}
    </nav>

    <!-- Right content panel -->
    <div class="stg-panel">
      {#if activeTab === 'general'}
        <GeneralSettings />
      {:else if activeTab === 'appearance'}
        <AppearanceSettings />
      {:else if activeTab === 'sidebar'}
        <SidebarSettings />
      {:else if activeTab === 'agents'}
        <AgentsSettings />
      {:else if activeTab === 'budget'}
        <BudgetSettings />
      {:else if activeTab === 'notifications'}
        <NotificationsSettings />
      {:else if activeTab === 'integrations'}
        <IntegrationsSettings />
      {:else if activeTab === 'advanced'}
        <AdvancedSettings />
      {/if}
    </div>

  </div>

  {#snippet actions()}
    <button
      class="stg-save-btn"
      class:stg-save-btn--active={settingsStore.dirty}
      disabled={settingsStore.loading || !settingsStore.dirty}
      onclick={handleSave}
      aria-label="Save settings"
    >
      {settingsStore.loading ? 'Saving…' : settingsStore.dirty ? 'Save Changes' : 'Saved'}
    </button>
  {/snippet}
</PageShell>

<style>
  /* Layout */

  .stg-layout {
    display: flex;
    height: 100%;
    overflow: hidden;
  }

  /* Tab Sidebar */

  .stg-tabs {
    display: flex;
    flex-direction: column;
    width: 160px;
    min-width: 160px;
    padding: 8px 8px 8px 0;
    border-right: 1px solid var(--border-default);
    overflow-y: auto;
    flex-shrink: 0;
    gap: 2px;
  }

  .stg-tab {
    display: block;
    width: 100%;
    padding: 8px 12px;
    text-align: left;
    font-size: 13px;
    font-weight: 500;
    color: var(--text-secondary);
    background: transparent;
    border: none;
    border-radius: var(--radius-sm);
    cursor: pointer;
    transition: background var(--transition-fast), color var(--transition-fast);
    white-space: nowrap;
  }

  .stg-tab:hover {
    background: var(--bg-elevated);
    color: var(--text-primary);
  }

  .stg-tab--active {
    background: var(--bg-elevated);
    color: var(--text-primary);
    position: relative;
  }

  .stg-tab--active::before {
    content: '';
    position: absolute;
    left: 0;
    top: 6px;
    bottom: 6px;
    width: 2px;
    background: var(--accent-primary);
    border-radius: 0 2px 2px 0;
  }

  /* Content Panel */

  .stg-panel {
    flex: 1;
    overflow-y: auto;
    padding: 20px 24px 80px;
    min-width: 0;
  }

  .stg-panel::-webkit-scrollbar { width: 6px; }
  .stg-panel::-webkit-scrollbar-track { background: transparent; }
  .stg-panel::-webkit-scrollbar-thumb { background: var(--border-default); border-radius: 3px; }
  .stg-panel::-webkit-scrollbar-thumb:hover { background: var(--border-hover); }

  /* Save Button (PageShell actions slot) */

  .stg-save-btn {
    padding: 6px 16px;
    font-size: 13px;
    font-weight: 500;
    color: var(--text-tertiary);
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
    cursor: default;
    transition: background var(--transition-fast), color var(--transition-fast), border-color var(--transition-fast);
  }

  .stg-save-btn--active {
    color: #fff;
    background: var(--accent-primary);
    border-color: var(--accent-primary);
    cursor: pointer;
  }

  .stg-save-btn--active:hover {
    background: #2563eb;
    border-color: #2563eb;
  }

  .stg-save-btn:disabled:not(.stg-save-btn--active) {
    opacity: 0.5;
    cursor: default;
  }
</style>
