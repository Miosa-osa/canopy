<script lang="ts">
/**
 * AgentCard — card for one agent in the library grid.
 * Glass card outer, pill CTAs, emoji + serif name.
 * LOC target: ≤ 120.
 */
import { goto } from '$app/navigation';
import type { Agent } from '$lib/domain/agents/types.js';
import StatusDot from './StatusDot.svelte';

interface Props {
  agent: Agent;
  onHire?: (slug: string) => void;
  onRun?: (slug: string) => void;
  /** Pass true while the hire mutation is in-flight for this card's agent. */
  isHiring?: boolean;
  class?: string;
}

let { agent, onHire, onRun, isHiring = false, class: className = '' }: Props = $props();

const hired = $derived(agent.hired);

function handleHire(e: MouseEvent): void {
  e.stopPropagation();
  onHire?.(agent.slug);
}

function handleRun(e: MouseEvent): void {
  e.stopPropagation();
  onRun?.(agent.slug);
}

function handleCardClick(): void {
  goto(`/agents/${agent.slug}`);
}
</script>

<!-- Outer glass card — navigation affordance via keydown on the wrapping div -->
<div
  class="cnp-agent-card glass-card {className}"
  onclick={handleCardClick}
  onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); handleCardClick(); } }}
  role="link"
  tabindex="0"
  aria-label="View {agent.name}"
>
  <div class="cnp-agent-card__emoji" aria-hidden="true">{agent.emoji}</div>

  <div class="cnp-agent-card__meta">
    <p class="cnp-agent-card__name">{agent.name}</p>
    <p class="cnp-agent-card__category">
      {agent.category}{#if agent.owner} · {agent.owner}{/if}
    </p>
  </div>

  <p class="cnp-agent-card__bio">{agent.bio}</p>

  <div class="cnp-agent-card__footer">
    <div class="cnp-agent-card__status">
      <StatusDot color={hired ? 'green' : 'grey'} label={hired ? 'Hired' : 'Available'} pulse={hired} />
      {#if agent.runCount > 0}
        <span class="cnp-agent-card__runs">{agent.runCount} run{agent.runCount !== 1 ? 's' : ''}</span>
      {/if}
    </div>

    <div class="cnp-agent-card__actions">
      {#if hired}
        <button
          class="btn-pill btn-pill-secondary btn-pill-sm"
          onclick={handleRun}
          aria-label="Run {agent.name}"
        >
          Run ▸
        </button>
      {:else}
        <button
          class="btn-pill btn-pill-primary btn-pill-sm"
          onclick={handleHire}
          disabled={isHiring}
          aria-label={isHiring ? 'Hiring…' : `Hire ${agent.name}`}
        >
          {#if isHiring}
            <span class="btn-pill-spinner" aria-hidden="true"></span>
            Hiring…
          {:else}
            Hire
          {/if}
        </button>
      {/if}
    </div>
  </div>
</div>

<style>
  .cnp-agent-card {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-4);
    cursor: pointer;
    user-select: none;
    outline: none;
  }

  .cnp-agent-card:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .cnp-agent-card__emoji {
    font-size: 32px;
    line-height: 1;
    margin-bottom: var(--space-1);
  }

  .cnp-agent-card__meta {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .cnp-agent-card__name {
    font-family: var(--font-sans);
    font-size: var(--text-base);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
    letter-spacing: -0.015em;
    line-height: 1.25;
  }

  .cnp-agent-card__category {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    margin: 0;
    text-transform: capitalize;
  }

  .cnp-agent-card__bio {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
    line-height: 1.5;
    flex: 1;
    overflow: hidden;
    display: -webkit-box;
    /* stylelint-disable-next-line */
    -webkit-line-clamp: 2;
    line-clamp: 2;
    -webkit-box-orient: vertical;
  }

  .cnp-agent-card__footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-top: var(--space-1);
  }

  .cnp-agent-card__status {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .cnp-agent-card__runs {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  .cnp-agent-card__actions {
    display: flex;
    gap: var(--space-1);
  }
</style>
