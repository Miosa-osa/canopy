<script lang="ts">
  /**
   * HireAgentModal — configure and hire an agent from the library grid.
   * Shows runtime picker, capability preset, and optional budget before calling
   * POST /api/v1/agents/:slug/hire.
   * CSS prefix: ham- (hire-agent-modal)
   */
  import {
    type CreateMutationOptions,
    type CreateQueryOptions,
    createMutation,
    createQuery,
    useQueryClient,
  } from '@tanstack/svelte-query';
  import { writable } from 'svelte/store';
  import { X } from 'lucide-svelte';
  import { hireAgent } from '$lib/api/queries/agents.js';
  import { runtimesQuery } from '$lib/api/queries/runtimes.js';
  import {
    CAPABILITY_PRESETS,
    CAPABILITY_PRESET_META,
    type Capability,
    type CapabilityPreset,
  } from '$lib/domain/agents/config.js';
  import type { Agent } from '$lib/domain/agents/types.js';
  import type { Runtime } from '$lib/domain/runtimes/types.js';

  // ── Engineering categories — default to "developer" preset ─────────────────
  const ENGINEERING_CATEGORIES = new Set([
    'engineering',
    'technology',
    'testing',
    'game-development',
    'spatial-computing',
  ]);

  interface Props {
    agent: Agent;
    open: boolean;
    onClose: () => void;
    onHired: () => void;
  }

  let { agent, open, onClose, onHired }: Props = $props();

  // ── Runtime query ──────────────────────────────────────────────────────────
  const runtimesQ = createQuery<Runtime[]>(
    writable(runtimesQuery() as CreateQueryOptions<Runtime[]>)
  );
  const runtimes = $derived(($runtimesQ.data ?? []) as Runtime[]);

  // ── Form state ─────────────────────────────────────────────────────────────
  let selectedRuntime = $state<string>('');
  let selectedPreset = $state<CapabilityPreset>('reviewer');
  let budgetStr = $state<string>('');

  // Derive the default preset from the agent category
  const defaultPreset = $derived<CapabilityPreset>(
    ENGINEERING_CATEGORIES.has(agent.category) ? 'developer' : 'reviewer'
  );

  // Re-init form state when the target agent changes
  $effect(() => {
    // Track agent identity to reset on change
    const slug = agent.slug;
    const defRuntime = agent.defaultRuntime;
    const fallbackRuntime = runtimes[0]?.type ?? '';
    void slug;
    selectedRuntime = defRuntime ?? fallbackRuntime;
    selectedPreset = defaultPreset;
    budgetStr = '';
    submitError = null;
  });

  // ── Mutation (direct call — not TanStack mutation — so we can await cleanly)
  let isPending = $state(false);
  let submitError = $state<string | null>(null);

  async function handleSubmit(): Promise<void> {
    if (isPending) return;
    isPending = true;
    submitError = null;

    try {
      const budget = budgetStr.trim() ? parseFloat(budgetStr) : undefined;
      const body = {
        defaultRuntime: selectedRuntime || undefined,
        heartbeatCron: agent.heartbeatCron ?? undefined,
        budget: budget && !isNaN(budget) ? budget : undefined,
      };

      await hireAgent(agent.slug, body);

      // Persist capability preset to localStorage (matches detail page pattern)
      const lsKey = `canopy:agent-config:${agent.slug}`;
      const caps: Capability[] = [...CAPABILITY_PRESETS[selectedPreset]];
      try {
        const existing = localStorage.getItem(lsKey);
        const parsed = existing ? JSON.parse(existing) : {};
        localStorage.setItem(lsKey, JSON.stringify({ ...parsed, capabilities: caps }));
      } catch {
        // localStorage unavailable — silent fail
      }

      onHired();
    } catch (err) {
      submitError = err instanceof Error ? err.message : 'Failed to hire agent.';
    } finally {
      isPending = false;
    }
  }

  function handleBackdropClick(e: MouseEvent): void {
    if ((e.target as HTMLElement).classList.contains('ham-backdrop')) onClose();
  }

  function handleKeydown(e: KeyboardEvent): void {
    if (e.key === 'Escape') onClose();
  }

  // ── Category badge label ───────────────────────────────────────────────────
  function categoryLabel(cat: string): string {
    return cat.replace(/-/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
  }
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="ham-backdrop" onclick={handleBackdropClick}>
    <div
      class="ham-modal"
      role="dialog"
      aria-modal="true"
      aria-label="Hire {agent.name}"
    >
      <!-- ── Header ──────────────────────────────────────────────────────── -->
      <header class="ham-header">
        <div class="ham-header__identity">
          <span class="ham-agent-emoji" aria-hidden="true">{agent.emoji}</span>
          <div class="ham-header__meta">
            <span class="ham-agent-name">{agent.name}</span>
            <span class="ham-category-badge">{categoryLabel(agent.category)}</span>
          </div>
        </div>
        <button
          class="ham-close"
          onclick={onClose}
          aria-label="Close"
          disabled={isPending}
        >
          <X size={14} aria-hidden="true" />
        </button>
      </header>

      <!-- ── Body ───────────────────────────────────────────────────────── -->
      <div class="ham-body">

        <!-- Runtime picker -->
        <section class="ham-section">
          <h3 class="ham-section-label">Runtime</h3>

          {#if $runtimesQ.isLoading}
            <p class="ham-hint">Loading runtimes…</p>
          {:else if runtimes.length === 0}
            <p class="ham-hint">No runtimes available. Configure one in Settings.</p>
          {:else}
            <div class="ham-radio-cards" role="radiogroup" aria-label="Select runtime">
              {#each runtimes as rt (rt.type)}
                <label
                  class="ham-radio-card"
                  class:ham-radio-card--selected={selectedRuntime === rt.type}
                >
                  <input
                    type="radio"
                    name="ham-runtime"
                    value={rt.type}
                    bind:group={selectedRuntime}
                    class="ham-radio-hidden"
                    aria-label={rt.name}
                  />
                  <span class="ham-radio-card__name">{rt.name}</span>
                  <span class="ham-radio-card__desc">{rt.version ?? rt.type}</span>
                </label>
              {/each}
            </div>
          {/if}
        </section>

        <!-- Capability preset -->
        <section class="ham-section">
          <h3 class="ham-section-label">Capability preset</h3>
          <div class="ham-presets" role="group" aria-label="Capability preset">
            {#each Object.entries(CAPABILITY_PRESET_META) as [preset, meta] (preset)}
              <button
                class="ham-preset-btn"
                class:ham-preset-btn--active={selectedPreset === preset}
                onclick={() => { selectedPreset = preset as CapabilityPreset; }}
                title={meta.description}
                type="button"
              >
                {meta.label}
              </button>
            {/each}
          </div>
          <p class="ham-preset-desc">
            {CAPABILITY_PRESET_META[selectedPreset].description}
          </p>
        </section>

        <!-- Budget cap -->
        <section class="ham-section">
          <h3 class="ham-section-label">
            Monthly budget cap
            <span class="ham-optional">(optional)</span>
          </h3>
          <div class="ham-budget-wrap">
            <span class="ham-budget-prefix" aria-hidden="true">$</span>
            <input
              class="ham-budget-input"
              type="number"
              min="0"
              step="1"
              placeholder="No limit"
              bind:value={budgetStr}
              aria-label="Monthly budget cap in dollars"
            />
          </div>
          <p class="ham-hint">Leave empty for no spending limit.</p>
        </section>

        {#if submitError}
          <p class="ham-error" role="alert">{submitError}</p>
        {/if}
      </div>

      <!-- ── Footer ─────────────────────────────────────────────────────── -->
      <footer class="ham-footer">
        <button
          class="btn-pill btn-pill-secondary btn-pill-sm"
          type="button"
          onclick={onClose}
          disabled={isPending}
        >
          Cancel
        </button>
        <button
          class="btn-pill btn-pill-primary btn-pill-sm"
          type="button"
          onclick={handleSubmit}
          disabled={isPending}
          aria-busy={isPending}
        >
          {isPending ? 'Hiring…' : 'Hire Agent'}
        </button>
      </footer>
    </div>
  </div>
{/if}

<style>
  /* ── Backdrop ──────────────────────────────────────────────────────────── */

  .ham-backdrop {
    position: fixed;
    inset: 0;
    background: color-mix(in oklch, var(--bg) 40%, transparent);
    backdrop-filter: blur(4px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 900;
    padding: var(--space-4);
  }

  /* ── Modal card ────────────────────────────────────────────────────────── */

  .ham-modal {
    width: 100%;
    max-width: 480px;
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: var(--radius-xl, 16px);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    box-shadow: 0 24px 80px color-mix(in oklch, black 30%, transparent);
    max-height: calc(100vh - var(--space-8));
  }

  /* ── Header ────────────────────────────────────────────────────────────── */

  .ham-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-4) var(--space-5) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .ham-header__identity {
    display: flex;
    align-items: center;
    gap: var(--space-3);
  }

  .ham-agent-emoji {
    font-size: 28px;
    line-height: 1;
    flex-shrink: 0;
  }

  .ham-header__meta {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .ham-agent-name {
    font-family: var(--font-sans);
    font-size: var(--text-base);
    font-weight: 600;
    color: var(--fg);
    line-height: 1.2;
  }

  .ham-category-badge {
    display: inline-block;
    padding: 1px 8px;
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    border: 1px solid var(--border);
    border-radius: 9999px;
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 500;
    color: var(--fg-muted);
    letter-spacing: 0.03em;
    width: fit-content;
  }

  .ham-close {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    padding: 0;
    background: transparent;
    border: 1px solid transparent;
    border-radius: var(--radius-sm);
    color: var(--fg-muted);
    cursor: pointer;
    transition: background 0.1s, color 0.1s;
    flex-shrink: 0;
  }

  .ham-close:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg);
  }

  /* ── Body ──────────────────────────────────────────────────────────────── */

  .ham-body {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-4) var(--space-5);
    display: flex;
    flex-direction: column;
    gap: var(--space-5);
  }

  /* ── Sections ──────────────────────────────────────────────────────────── */

  .ham-section {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .ham-section-label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 500;
    letter-spacing: 0.05em;
    text-transform: uppercase;
    color: var(--fg-muted);
    margin: 0;
  }

  .ham-optional {
    font-size: 10px;
    font-weight: 400;
    text-transform: none;
    letter-spacing: 0;
    color: var(--fg-subtle);
  }

  /* ── Runtime radio cards ───────────────────────────────────────────────── */

  .ham-radio-cards {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-2);
  }

  .ham-radio-hidden {
    position: absolute;
    opacity: 0;
    width: 0;
    height: 0;
    pointer-events: none;
  }

  .ham-radio-card {
    display: flex;
    flex-direction: column;
    gap: 2px;
    padding: var(--space-3) var(--space-4);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm, 4px);
    cursor: pointer;
    min-width: 120px;
    transition: border-color 0.1s var(--ease-out, ease);
    position: relative;
  }

  .ham-radio-card:hover {
    border-color: var(--border-strong);
  }

  .ham-radio-card--selected {
    border: 2px solid var(--cnp-accent, oklch(0.55 0.18 250));
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.55 0.18 250)) 6%, var(--bg-inset));
  }

  .ham-radio-card__name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
  }

  .ham-radio-card__desc {
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-muted);
  }

  /* ── Capability presets ────────────────────────────────────────────────── */

  .ham-presets {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-2);
  }

  .ham-preset-btn {
    padding: 4px 12px;
    background: transparent;
    border: 1px solid var(--border);
    border-radius: 9999px;
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--fg-muted);
    cursor: pointer;
    transition: background 0.1s, color 0.1s, border-color 0.1s;
  }

  .ham-preset-btn:hover {
    background: color-mix(in oklch, var(--fg) 7%, transparent);
    color: var(--fg);
    border-color: var(--border-strong);
  }

  .ham-preset-btn--active {
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.55 0.18 250)) 12%, transparent);
    border-color: var(--cnp-accent, oklch(0.55 0.18 250));
    color: var(--fg);
  }

  .ham-preset-desc {
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
    margin: 0;
  }

  /* ── Budget input ──────────────────────────────────────────────────────── */

  .ham-budget-wrap {
    display: flex;
    align-items: center;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm, 4px);
    overflow: hidden;
    max-width: 160px;
    transition: border-color 0.1s;
  }

  .ham-budget-wrap:focus-within {
    border-color: var(--cnp-accent, oklch(0.55 0.18 250));
    box-shadow: 0 0 0 2px color-mix(in oklch, var(--cnp-accent, oklch(0.55 0.18 250)) 20%, transparent);
  }

  .ham-budget-prefix {
    padding: var(--space-2) var(--space-2) var(--space-2) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    flex-shrink: 0;
    user-select: none;
  }

  .ham-budget-input {
    flex: 1;
    padding: var(--space-2) var(--space-3) var(--space-2) 0;
    background: transparent;
    border: none;
    outline: none;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    min-width: 0;
  }

  .ham-budget-input::placeholder {
    color: var(--fg-subtle);
  }

  /* Remove browser number spinner */
  .ham-budget-input::-webkit-outer-spin-button,
  .ham-budget-input::-webkit-inner-spin-button {
    -webkit-appearance: none;
    margin: 0;
  }

  .ham-budget-input[type='number'] {
    -moz-appearance: textfield;
    appearance: textfield;
  }

  /* ── Hints & errors ────────────────────────────────────────────────────── */

  .ham-hint {
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
    margin: 0;
  }

  .ham-error {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--destructive, oklch(0.55 0.22 25));
    margin: 0;
  }

  /* ── Footer ────────────────────────────────────────────────────────────── */

  .ham-footer {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-5) var(--space-4);
    border-top: 1px solid var(--border);
    flex-shrink: 0;
  }
</style>
