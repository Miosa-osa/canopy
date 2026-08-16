<script lang="ts">
  /**
   * AgentOrgChart — tree/grid of agent cards grouped by category/department.
   * Agents with no category default to "General".
   * CSS prefix: aoc-
   */
  import { goto } from '$app/navigation';
  import { Bot } from 'lucide-svelte';
  import type { Agent } from '$lib/domain/agents/types.js';

  interface Props {
    agents: Agent[];
  }

  let { agents }: Props = $props();

  /** Derive departments from agent.category — capitalize and de-hyphenate. */
  function deptLabel(cat: string): string {
    return cat.replace(/-/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
  }

  /** Group agents by category. */
  const departments = $derived.by(() => {
    const map = new Map<string, Agent[]>();
    for (const agent of agents) {
      const key = agent.category ?? 'general';
      const bucket = map.get(key) ?? [];
      bucket.push(agent);
      map.set(key, bucket);
    }
    // Sort depts alphabetically; put 'general' last
    return [...map.entries()].sort(([a], [b]) => {
      if (a === 'general') return 1;
      if (b === 'general') return -1;
      return a.localeCompare(b);
    });
  });

  function statusLabel(agent: Agent): string {
    if (agent.runCount > 0 && agent.hired) return 'running';
    if (agent.hired) return 'hired';
    return 'idle';
  }

  function handleCardClick(slug: string): void {
    void goto(`/agents/${slug}`);
  }

  function handleCardKeydown(e: KeyboardEvent, slug: string): void {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      void goto(`/agents/${slug}`);
    }
  }
</script>

<div class="aoc-root">
  {#each departments as [dept, deptAgents] (dept)}
    <section class="aoc-dept">
      <header class="aoc-dept__header">
        <span class="aoc-dept__label">{deptLabel(dept)}</span>
        <span class="aoc-dept__count">{deptAgents.length}</span>
      </header>

      <div class="aoc-dept__cards">
        {#each deptAgents as agent (agent.slug)}
          {@const status = statusLabel(agent)}
          <div
            class="aoc-card"
            class:aoc-card--hired={agent.hired}
            role="link"
            tabindex="0"
            aria-label="View {agent.name}"
            onclick={() => handleCardClick(agent.slug)}
            onkeydown={(e) => handleCardKeydown(e, agent.slug)}
          >
            <!-- Avatar -->
            <div class="aoc-card__avatar" aria-hidden="true">
              <Bot size={16} strokeWidth={1.8} />
            </div>

            <!-- Name + slug -->
            <div class="aoc-card__meta">
              <span class="aoc-card__name">{agent.name}</span>
              <span class="aoc-card__slug">{agent.slug}</span>
            </div>

            <!-- Footer: status pill + activity beacon -->
            <div class="aoc-card__footer">
              <span
                class="aoc-status-pill aoc-status-pill--{status}"
                aria-label="Status: {status}"
              >
                {status}
              </span>
              {#if status === 'running'}
                <span class="aoc-beacon" aria-label="Active session" aria-hidden="true"></span>
              {/if}
            </div>
          </div>
        {/each}

        <!-- Empty dept placeholder card -->
        <button
          class="aoc-card aoc-card--add"
          aria-label="Add agent to {deptLabel(dept)}"
          onclick={() => void goto('/agents/new')}
          type="button"
        >
          <span class="aoc-card__add-icon" aria-hidden="true">+</span>
          <span class="aoc-card__add-label">Add to {deptLabel(dept)}</span>
        </button>
      </div>
    </section>
  {/each}

  {#if departments.length === 0}
    <div class="aoc-empty">
      <p>No agents to display. Hire some agents to see them here.</p>
    </div>
  {/if}
</div>

<style>
  .aoc-root {
    display: flex;
    flex-direction: column;
    gap: var(--space-6);
    padding: var(--space-5) var(--space-6);
  }

  /* ── Department section ────────────────────────────────────────────────── */

  .aoc-dept {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .aoc-dept__header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .aoc-dept__label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--fg-muted);
  }

  .aoc-dept__count {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 18px;
    height: 18px;
    padding: 0 5px;
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    border-radius: 9999px;
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
  }

  .aoc-dept__cards {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-3);
  }

  /* ── Agent card ────────────────────────────────────────────────────────── */

  .aoc-card {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-3) var(--space-4);
    width: 180px;
    min-height: 120px;
    background: var(--surface, var(--bg-elevated, var(--bg)));
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    cursor: pointer;
    transition: border-color 0.12s var(--ease-out),
      background 0.12s var(--ease-out),
      box-shadow 0.12s var(--ease-out);
    text-align: left;
    position: relative;
    outline: none;
  }

  .aoc-card:hover {
    border-color: var(--cnp-accent, var(--border-strong));
    box-shadow: 0 4px 16px color-mix(in oklch, var(--fg) 8%, transparent);
  }

  .aoc-card:focus-visible {
    outline: 2px solid var(--cnp-accent, oklch(0.55 0.18 250));
    outline-offset: 2px;
  }

  .aoc-card--hired {
    border-color: color-mix(in oklch, var(--cnp-accent, oklch(0.55 0.18 250)) 30%, var(--border));
  }

  /* ── Add placeholder card ──────────────────────────────────────────────── */

  .aoc-card--add {
    border-style: dashed;
    background: transparent;
    align-items: center;
    justify-content: center;
    color: var(--fg-subtle);
    font-family: var(--font-sans);
    gap: var(--space-1);
  }

  .aoc-card--add:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    color: var(--fg-muted);
  }

  .aoc-card__add-icon {
    font-size: 18px;
    line-height: 1;
    color: var(--fg-subtle);
  }

  .aoc-card__add-label {
    font-size: 11px;
    font-weight: 500;
    text-align: center;
    color: inherit;
  }

  /* ── Card contents ─────────────────────────────────────────────────────── */

  .aoc-card__avatar {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 36px;
    height: 36px;
    border-radius: 10px;
    background: color-mix(in oklch, var(--cnp-accent, #6366f1) 12%, transparent);
    color: var(--cnp-accent, #6366f1);
    flex-shrink: 0;
  }

  .aoc-card--hired .aoc-card__avatar {
    background: color-mix(in oklch, var(--cnp-accent, #6366f1) 18%, transparent);
  }

  .aoc-card__meta {
    display: flex;
    flex-direction: column;
    gap: 2px;
    flex: 1;
  }

  .aoc-card__name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
    line-height: 1.2;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .aoc-card__slug {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .aoc-card__footer {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    margin-top: auto;
  }

  /* ── Status pill ───────────────────────────────────────────────────────── */

  .aoc-status-pill {
    display: inline-block;
    padding: 2px 7px;
    border-radius: 9999px;
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 500;
    letter-spacing: 0.02em;
  }

  .aoc-status-pill--hired {
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.55 0.18 250)) 12%, transparent);
    color: var(--cnp-accent, oklch(0.55 0.18 250));
    border: 1px solid color-mix(in oklch, var(--cnp-accent, oklch(0.55 0.18 250)) 25%, transparent);
  }

  .aoc-status-pill--running {
    background: color-mix(in oklch, oklch(0.6 0.18 145) 12%, transparent);
    color: oklch(0.6 0.18 145);
    border: 1px solid color-mix(in oklch, oklch(0.6 0.18 145) 25%, transparent);
  }

  .aoc-status-pill--idle {
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    color: var(--fg-subtle);
    border: 1px solid var(--border);
  }

  /* ── Activity beacon ───────────────────────────────────────────────────── */

  .aoc-beacon {
    display: inline-block;
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: oklch(0.6 0.18 145);
    flex-shrink: 0;
    animation: aoc-pulse 1.8s ease-in-out infinite;
  }

  @keyframes aoc-pulse {
    0%, 100% { opacity: 1; transform: scale(1); }
    50% { opacity: 0.5; transform: scale(0.8); }
  }

  /* ── Empty state ───────────────────────────────────────────────────────── */

  .aoc-empty {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: var(--space-8);
    color: var(--fg-subtle);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
  }
</style>
