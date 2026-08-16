<script lang="ts">
  /**
   * CapabilitiesPanel — checkbox list with risk warnings for dangerous perms.
   * Stored in config.capabilities[] via localStorage draft.
   * CSS prefix: cap- (CapabilitiesPanel)
   */
  import {
    CAPABILITY_META,
    CAPABILITY_RISK,
    CAPABILITY_PRESETS,
    CAPABILITY_PRESET_META,
    type Capability,
    type CapabilityPreset,
  } from '$lib/domain/agents/config.js';

  interface Props {
    enabled: Capability[];
    onChange: (caps: Capability[]) => void;
    isLocalDraft: boolean;
  }

  let { enabled, onChange, isLocalDraft }: Props = $props();

  const ALL_CAPS = Object.keys(CAPABILITY_META) as Capability[];
  const HIGH_RISK = ALL_CAPS.filter((c) => CAPABILITY_RISK[c] === 'high');
  const hasHighRisk = $derived(HIGH_RISK.some((c) => enabled.includes(c)));

  function toggle(cap: Capability) {
    if (enabled.includes(cap)) {
      onChange(enabled.filter((c) => c !== cap));
    } else {
      onChange([...enabled, cap]);
    }
  }

  function applyPreset(preset: CapabilityPreset) {
    onChange([...CAPABILITY_PRESETS[preset]]);
  }
</script>

<div class="cap-root">
  {#if isLocalDraft}
    <div class="cap-draft-banner" role="note">
      Local draft — will sync when backend supports capability storage.
    </div>
  {/if}

  <!-- Preset quick-picks -->
  <div class="cap-presets" role="group" aria-label="Capability presets">
    <span class="cap-presets-label">Preset:</span>
    {#each Object.entries(CAPABILITY_PRESET_META) as [preset, meta] (preset)}
      <button
        class="cap-preset-btn"
        onclick={() => applyPreset(preset as CapabilityPreset)}
        title={meta.description}
      >
        {meta.label}
      </button>
    {/each}
  </div>

  <!-- Risk banner -->
  {#if hasHighRisk}
    <div class="cap-risk-banner" role="alert">
      <span class="cap-risk-icon" aria-hidden="true">⚠</span>
      <span>
        One or more high-risk capabilities are enabled. These grant the agent elevated access to
        your system. Ensure this agent is trusted and audited regularly.
      </span>
    </div>
  {/if}

  <!-- Capability list -->
  <div class="cap-list" role="list">
    {#each ALL_CAPS as cap (cap)}
      {@const meta = CAPABILITY_META[cap]}
      {@const risk = CAPABILITY_RISK[cap]}
      {@const isEnabled = enabled.includes(cap)}
      <label
        class="cap-row"
        class:cap-row--high={risk === 'high'}
        class:cap-row--medium={risk === 'medium'}
        role="listitem"
      >
        <input
          type="checkbox"
          class="cap-checkbox"
          checked={isEnabled}
          onchange={() => toggle(cap)}
          aria-label="{meta.label} capability"
        />
        <div class="cap-row-body">
          <div class="cap-row-header">
            <span class="cap-row-name">{meta.label}</span>
            {#if risk !== 'low'}
              <span
                class="cap-risk-pill"
                class:cap-risk-pill--high={risk === 'high'}
                class:cap-risk-pill--medium={risk === 'medium'}
                aria-label="Risk level: {risk}"
              >
                {risk}
              </span>
            {/if}
          </div>
          <p class="cap-row-desc">{meta.description}</p>
          {#if isEnabled && meta.risk_note}
            <p class="cap-risk-note">{meta.risk_note}</p>
          {/if}
        </div>
      </label>
    {/each}
  </div>
</div>

<style>
  .cap-root {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-6);
    max-width: 700px;
  }

  .cap-draft-banner {
    padding: var(--space-2) var(--space-4);
    background: color-mix(in oklch, oklch(0.75 0.12 85) 12%, transparent);
    border: 1px solid color-mix(in oklch, oklch(0.75 0.12 85) 30%, transparent);
    border-radius: var(--radius-sm);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: oklch(0.75 0.12 85);
  }

  /* Presets */
  .cap-presets {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: var(--space-2);
  }

  .cap-presets-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    font-weight: 500;
  }

  .cap-preset-btn {
    padding: 3px 10px;
    background: transparent;
    border: 1px solid var(--border);
    border-radius: 9999px;
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-muted);
    cursor: pointer;
    transition: background 0.1s, color 0.1s, border-color 0.1s;
  }

  .cap-preset-btn:hover {
    background: color-mix(in oklch, var(--fg) 7%, transparent);
    color: var(--fg);
    border-color: var(--border-strong, var(--border));
  }

  /* Risk banner */
  .cap-risk-banner {
    display: flex;
    align-items: flex-start;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-4);
    background: color-mix(in oklch, var(--destructive, oklch(0.55 0.22 25)) 10%, transparent);
    border: 1px solid color-mix(in oklch, var(--destructive, oklch(0.55 0.22 25)) 30%, transparent);
    border-radius: var(--radius-sm);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--destructive, oklch(0.55 0.22 25));
    line-height: 1.5;
  }

  .cap-risk-icon {
    font-size: var(--text-base);
    flex-shrink: 0;
    margin-top: 1px;
  }

  /* Capability rows */
  .cap-list {
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .cap-row {
    display: flex;
    align-items: flex-start;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-3);
    border-radius: var(--radius-sm);
    cursor: pointer;
    transition: background 0.1s;
  }

  .cap-row:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }

  .cap-row--high {
    border-left: 2px solid color-mix(in oklch, var(--destructive, oklch(0.55 0.22 25)) 60%, transparent);
    padding-left: calc(var(--space-3) - 2px);
  }

  .cap-row--medium {
    border-left: 2px solid color-mix(in oklch, oklch(0.7 0.15 55) 60%, transparent);
    padding-left: calc(var(--space-3) - 2px);
  }

  .cap-checkbox {
    margin-top: 2px;
    flex-shrink: 0;
    accent-color: var(--cnp-accent, oklch(0.55 0.18 250));
    width: 14px;
    height: 14px;
    cursor: pointer;
  }

  .cap-row-body {
    display: flex;
    flex-direction: column;
    gap: 2px;
    flex: 1;
  }

  .cap-row-header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .cap-row-name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
  }

  .cap-risk-pill {
    padding: 1px 6px;
    border-radius: 9999px;
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.03em;
  }

  .cap-risk-pill--high {
    background: color-mix(in oklch, var(--destructive, oklch(0.55 0.22 25)) 15%, transparent);
    color: var(--destructive, oklch(0.55 0.22 25));
    border: 1px solid color-mix(in oklch, var(--destructive, oklch(0.55 0.22 25)) 30%, transparent);
  }

  .cap-risk-pill--medium {
    background: color-mix(in oklch, oklch(0.7 0.15 55) 15%, transparent);
    color: oklch(0.7 0.15 55);
    border: 1px solid color-mix(in oklch, oklch(0.7 0.15 55) 30%, transparent);
  }

  .cap-row-desc {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    margin: 0;
    line-height: 1.5;
  }

  .cap-risk-note {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--destructive, oklch(0.55 0.22 25));
    margin: var(--space-1) 0 0;
    line-height: 1.5;
  }
</style>
