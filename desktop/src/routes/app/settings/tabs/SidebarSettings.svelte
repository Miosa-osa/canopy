<!-- src/routes/app/settings/tabs/SidebarSettings.svelte -->
<script lang="ts">
  import { Eye, EyeOff } from 'lucide-svelte';
  import {
    sidebarStore,
    SIDEBAR_MODULE_OPTIONS,
    type SidebarModuleOption,
  } from '$lib/stores/sidebar.svelte';

  sidebarStore.load();

  const sidebarGroups = $derived.by(() => {
    const groups = new Map<SidebarModuleOption['group'], SidebarModuleOption[]>();
    for (const option of SIDEBAR_MODULE_OPTIONS) {
      groups.set(option.group, [...(groups.get(option.group) ?? []), option]);
    }
    return Array.from(groups.entries());
  });
</script>

<section class="ss-section">
  <div class="ss-head">
    <div>
      <p class="ss-eyebrow">Settings</p>
      <h2 class="ss-title">Sidebar</h2>
    </div>
    <button class="ss-reset" type="button" onclick={() => sidebarStore.reset()}>
      Reset to defaults
    </button>
  </div>

  <p class="ss-desc">
    Show or hide modules from the left sidebar. Changes apply immediately.
  </p>

  <div class="ss-groups">
    {#each sidebarGroups as [group, options] (group)}
      <section class="ss-group" aria-label="{group} sidebar modules">
        <header class="ss-group-head">
          <span>{group}</span>
        </header>

        <div class="ss-list">
          {#each options as option (option.id)}
            {@const visible = sidebarStore.isVisible(option.id)}
            <div class="ss-row" class:ss-row--primary={option.id === 'workbench'}>
              <span class="ss-row-spacer" aria-hidden="true"></span>
              <span class="ss-row-label">{option.label}</span>
              {#if option.id === 'workbench'}
                <span class="ss-pill">New</span>
              {/if}
              <button
                class="ss-eye"
                type="button"
                aria-label="{visible ? 'Hide' : 'Show'} {option.label}"
                title="{visible ? 'Hide' : 'Show'} {option.label}"
                onclick={() => sidebarStore.setVisible(option.id, !visible)}
              >
                {#if visible}
                  <Eye size={15} aria-hidden="true" />
                {:else}
                  <EyeOff size={15} aria-hidden="true" />
                {/if}
              </button>
            </div>
          {/each}
        </div>
      </section>
    {/each}
  </div>
</section>

<style>
  .ss-section {
    max-width: 720px;
  }

  .ss-head {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 16px;
  }

  .ss-eyebrow {
    margin: 0 0 6px;
    color: var(--text-tertiary);
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 0.12em;
    text-transform: uppercase;
  }

  .ss-title {
    margin: 0;
    color: var(--text-primary);
    font-size: 16px;
    font-weight: 650;
  }

  .ss-reset {
    height: 28px;
    padding: 0 12px;
    border: 1px solid var(--border-default);
    border-radius: var(--radius-full);
    background: transparent;
    color: var(--text-secondary);
    font: inherit;
    font-size: 12px;
    cursor: pointer;
  }

  .ss-reset:hover {
    color: var(--text-primary);
    border-color: var(--border-hover);
  }

  .ss-desc {
    margin: 34px 0 18px;
    color: var(--text-secondary);
    font-size: 13px;
    line-height: 1.5;
  }

  .ss-groups {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .ss-group {
    overflow: hidden;
    border: 1px solid var(--border-default);
    border-radius: var(--radius-md);
    background: var(--bg-surface);
  }

  .ss-group-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    min-height: 30px;
    padding: 0 12px;
    background: var(--bg-elevated);
    border-bottom: 1px solid var(--border-default);
    color: var(--text-tertiary);
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 0.12em;
    text-transform: uppercase;
  }

  .ss-list {
    padding: 4px 0;
  }

  .ss-row {
    display: flex;
    align-items: center;
    gap: 10px;
    min-height: 33px;
    padding: 0 12px;
    color: var(--text-secondary);
    font-size: 13px;
  }

  .ss-row--primary {
    color: var(--text-primary);
  }

  .ss-row:hover {
    background: var(--bg-elevated);
    color: var(--text-primary);
  }

  .ss-row-spacer {
    width: 18px;
    height: 18px;
    flex: 0 0 auto;
  }

  .ss-row-label {
    min-width: 0;
    flex: 1;
  }

  .ss-pill {
    flex: 0 0 auto;
    padding: 2px 6px;
    border: 1px solid rgba(59, 130, 246, 0.3);
    border-radius: var(--radius-full);
    background: rgba(59, 130, 246, 0.1);
    color: #93c5fd;
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
  }

  .ss-eye {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    border: 0;
    border-radius: var(--radius-sm);
    background: transparent;
    color: var(--text-tertiary);
    cursor: pointer;
  }

  .ss-eye:hover {
    background: var(--bg-surface);
    color: var(--text-primary);
  }
</style>
