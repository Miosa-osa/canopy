<!-- src/routes/app/settings/tabs/AppearanceSettings.svelte -->
<script lang="ts">
  import { settingsStore } from '$lib/stores/settings.svelte';
  import {
    sidebarStore,
    SIDEBAR_MODULE_OPTIONS,
    type SidebarModuleOption,
  } from '$lib/stores/sidebar.svelte';
  import { themeStore, type ThemeMode } from '$lib/stores/theme.svelte';

  const THEMES: { id: ThemeMode; label: string; bg: string; accent: string; surface: string }[] = [
    { id: 'dark',   label: 'Dark',   bg: '#0a0a0a',              accent: '#3b82f6', surface: '#1a1a1a' },
    { id: 'glass',  label: 'Glass',  bg: 'rgba(10,10,14,0.6)',   accent: '#8b5cf6', surface: 'rgba(255,255,255,0.06)' },
    { id: 'color',  label: 'Color',  bg: '#050510',              accent: '#3b82f6', surface: 'rgba(59,130,246,0.08)' },
    { id: 'light',  label: 'Light',  bg: '#fafafa',              accent: '#3b82f6', surface: '#ffffff' },
    { id: 'system', label: 'System', bg: 'linear-gradient(135deg,#0a0a0a 50%,#fafafa 50%)', accent: '#3b82f6', surface: '#888' },
  ];

  function handleThemeSelect(mode: ThemeMode) {
    themeStore.setMode(mode);
    settingsStore.update('theme', mode);
  }

  sidebarStore.load();

  const sidebarGroups = $derived.by(() => {
    const groups = new Map<SidebarModuleOption['group'], SidebarModuleOption[]>();
    for (const option of SIDEBAR_MODULE_OPTIONS) {
      groups.set(option.group, [...(groups.get(option.group) ?? []), option]);
    }
    return Array.from(groups.entries());
  });
</script>

<section class="stg-section">
  <h2 class="stg-section-title">Appearance</h2>

  <div class="stg-card">
    <div class="stg-field">
      <span class="stg-label">Theme</span>
      <p class="stg-desc">Choose your interface theme.</p>
      <div class="stg-theme-grid" role="radiogroup" aria-label="Theme selection">
        {#each THEMES as theme (theme.id)}
          {@const isActive = themeStore.mode === theme.id}
          <button
            class="stg-theme-card"
            class:stg-theme-card--active={isActive}
            onclick={() => handleThemeSelect(theme.id)}
            role="radio"
            aria-checked={isActive}
            aria-label="{theme.label} theme"
          >
            <div class="stg-theme-swatch" style="background: {theme.bg};">
              <div class="stg-theme-swatch-inner" style="background: {theme.surface}; border-color: {theme.accent}33;"></div>
              <div class="stg-theme-dot" style="background: {theme.accent};"></div>
            </div>
            <span class="stg-theme-name">{theme.label}</span>
          </button>
        {/each}
      </div>
    </div>

    <div class="stg-sep"></div>

    <div class="stg-field">
      <label class="stg-label" for="font-size">
        Font Size
        <span class="stg-value-badge">{settingsStore.data.font_size}px</span>
      </label>
      <p class="stg-desc">Base font size for the interface (12–20px).</p>
      <input
        id="font-size"
        class="stg-slider"
        type="range"
        min="12"
        max="20"
        step="1"
        value={settingsStore.data.font_size}
        oninput={(e) => settingsStore.update('font_size', Number((e.target as HTMLInputElement).value))}
      />
      <div class="stg-slider-labels">
        <span>12px</span>
        <span>20px</span>
      </div>
    </div>

    <div class="stg-sep"></div>

    <div class="stg-field stg-field--row">
      <div class="stg-field-text">
        <label class="stg-label" for="sidebar-collapsed">Sidebar Collapsed by Default</label>
        <p class="stg-desc">Start with the sidebar in collapsed state on launch.</p>
      </div>
      <label class="stg-toggle" aria-label="Sidebar collapsed by default">
        <input
          id="sidebar-collapsed"
          type="checkbox"
          checked={settingsStore.data.sidebar_default_collapsed}
          onchange={(e) => settingsStore.update('sidebar_default_collapsed', (e.target as HTMLInputElement).checked)}
        />
        <span class="stg-toggle-track">
          <span class="stg-toggle-thumb"></span>
        </span>
      </label>
    </div>

    <div class="stg-sep"></div>

    <div class="stg-field">
      <div class="stg-field-head">
        <div>
          <span class="stg-label">Sidebar Modules</span>
          <p class="stg-desc">Choose which command-center modules appear in the left sidebar.</p>
        </div>
        <button
          class="stg-mini-btn"
          type="button"
          onclick={() => sidebarStore.reset()}
        >
          Show All
        </button>
      </div>

      <div class="stg-module-groups">
        {#each sidebarGroups as [group, options] (group)}
          <section class="stg-module-group" aria-label="{group} sidebar modules">
            <h3 class="stg-module-group-title">{group}</h3>
            <div class="stg-module-grid">
              {#each options as option (option.id)}
                <label class="stg-module-toggle">
                  <input
                    type="checkbox"
                    checked={sidebarStore.isVisible(option.id)}
                    onchange={(e) => {
                      sidebarStore.setVisible(option.id, (e.target as HTMLInputElement).checked);
                    }}
                  />
                  <span>{option.label}</span>
                </label>
              {/each}
            </div>
          </section>
        {/each}
      </div>
    </div>
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

  .stg-field--row {
    flex-direction: row;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
  }

  .stg-field-text {
    display: flex;
    flex-direction: column;
    gap: 4px;
    flex: 1;
    min-width: 0;
  }

  .stg-field-head {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 16px;
  }

  .stg-mini-btn {
    flex-shrink: 0;
    height: 28px;
    padding: 0 10px;
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
    background: var(--bg-elevated);
    color: var(--text-secondary);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: 12px;
    font-weight: 500;
  }

  .stg-mini-btn:hover {
    color: var(--text-primary);
    border-color: var(--border-hover);
  }

  .stg-module-groups {
    display: flex;
    flex-direction: column;
    gap: 14px;
    margin-top: 8px;
  }

  .stg-module-group {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .stg-module-group-title {
    margin: 0;
    color: var(--text-tertiary);
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .stg-module-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 6px;
  }

  .stg-module-toggle {
    display: flex;
    align-items: center;
    gap: 8px;
    min-height: 32px;
    padding: 6px 8px;
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
    background: var(--bg-primary);
    color: var(--text-secondary);
    cursor: pointer;
    font-size: 12px;
  }

  .stg-module-toggle:hover {
    border-color: var(--border-hover);
    color: var(--text-primary);
  }

  .stg-module-toggle input {
    width: 14px;
    height: 14px;
    accent-color: var(--accent-primary);
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

  .stg-value-badge {
    font-size: 11px;
    font-weight: 500;
    color: var(--accent-primary);
    background: rgba(59, 130, 246, 0.12);
    border: 1px solid rgba(59, 130, 246, 0.2);
    border-radius: var(--radius-full);
    padding: 1px 7px;
  }

  .stg-slider {
    width: 100%;
    height: 4px;
    appearance: none;
    background: var(--border-default);
    border-radius: var(--radius-full);
    outline: none;
    cursor: pointer;
    accent-color: var(--accent-primary);
  }

  .stg-slider::-webkit-slider-thumb {
    appearance: none;
    width: 16px;
    height: 16px;
    border-radius: 50%;
    background: var(--accent-primary);
    cursor: pointer;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.2);
    transition: box-shadow var(--transition-fast);
  }

  .stg-slider::-webkit-slider-thumb:hover {
    box-shadow: 0 0 0 5px rgba(59, 130, 246, 0.25);
  }

  .stg-slider-labels {
    display: flex;
    justify-content: space-between;
    font-size: 11px;
    color: var(--text-muted);
    margin-top: 4px;
  }

  .stg-toggle {
    display: flex;
    align-items: center;
    cursor: pointer;
    flex-shrink: 0;
  }

  .stg-toggle input {
    position: absolute;
    width: 1px;
    height: 1px;
    opacity: 0;
    pointer-events: none;
  }

  .stg-toggle-track {
    position: relative;
    display: inline-block;
    width: 36px;
    height: 20px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-full);
    transition: background var(--transition-fast), border-color var(--transition-fast);
  }

  .stg-toggle input:checked ~ .stg-toggle-track {
    background: var(--accent-primary);
    border-color: var(--accent-primary);
  }

  .stg-toggle-thumb {
    position: absolute;
    top: 2px;
    left: 2px;
    width: 14px;
    height: 14px;
    background: var(--text-tertiary);
    border-radius: 50%;
    transition: transform var(--transition-fast), background var(--transition-fast);
  }

  .stg-toggle input:checked ~ .stg-toggle-track .stg-toggle-thumb {
    transform: translateX(16px);
    background: #fff;
  }

  /* Theme Picker */

  .stg-theme-grid {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
  }

  .stg-theme-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    padding: 0;
    background: transparent;
    border: 2px solid var(--border-default);
    border-radius: var(--radius-md);
    cursor: pointer;
    transition: border-color var(--transition-fast), transform var(--transition-fast);
    overflow: hidden;
    width: 96px;
  }

  .stg-theme-card:hover {
    border-color: var(--border-hover);
    transform: translateY(-1px);
  }

  .stg-theme-card--active { border-color: var(--accent-primary); }

  .stg-theme-swatch {
    position: relative;
    width: 100%;
    height: 52px;
    overflow: hidden;
  }

  .stg-theme-swatch-inner {
    position: absolute;
    top: 8px;
    left: 8px;
    right: 8px;
    bottom: 0;
    border-radius: var(--radius-sm) var(--radius-sm) 0 0;
    border: 1px solid;
  }

  .stg-theme-dot {
    position: absolute;
    bottom: 8px;
    right: 8px;
    width: 8px;
    height: 8px;
    border-radius: 50%;
  }

  .stg-theme-name {
    font-size: 11px;
    font-weight: 500;
    color: var(--text-secondary);
    padding: 0 8px 8px;
  }

  .stg-theme-card--active .stg-theme-name { color: var(--accent-primary); }
</style>
