<script lang="ts">
/**
 * AgentStep — step 3 of OnboardingWizard.
 * Pick 4-6 starter agents to hire. Uses hireAgent API.
 * CSS prefix: obw-
 */
import { hireAgent } from '$lib/api/queries/agents.js';
import { Workflow, Search, Shield, Wrench, PenTool, BarChart3, Bot, Check } from 'lucide-svelte';

interface Props {
  onNext: () => void;
  onBack: () => void;
  onSkip: () => void;
}

let { onNext, onBack, onSkip }: Props = $props();

interface AgentCard {
  slug: string;
  name: string;
  icon: typeof Bot;
  category: string;
  description: string;
}

const RECOMMENDED: AgentCard[] = [
  { slug: 'conductor', name: 'Conductor', icon: Workflow, category: 'Orchestration', description: 'Orchestrates multi-agent workflows end-to-end' },
  { slug: 'iris', name: 'Iris', icon: Search, category: 'Research', description: 'Research and knowledge synthesis' },
  { slug: 'vault', name: 'Vault', icon: Shield, category: 'Security', description: 'Secure credential and secret management' },
  { slug: 'forge', name: 'Forge', icon: Wrench, category: 'Engineering', description: 'Code generation and engineering tasks' },
  { slug: 'copy-doctor', name: 'Copy Doctor', icon: PenTool, category: 'Content', description: 'Copywriting, editing, and content polish' },
  { slug: 'data-analyst', name: 'Data Analyst', icon: BarChart3, category: 'Analytics', description: 'Data analysis, charts, and reporting' },
];

const hired = $state(new Set<string>());
let isHiring = $state(false);

function toggle(slug: string): void {
  if (hired.has(slug)) {
    hired.delete(slug);
  } else {
    hired.add(slug);
  }
}

async function handleNext(): Promise<void> {
  if (hired.size === 0) {
    onNext();
    return;
  }
  isHiring = true;
  try {
    await Promise.allSettled([...hired].map((slug) => hireAgent(slug)));
  } finally {
    isHiring = false;
  }
  onNext();
}
</script>

<div class="obw-agents">
  <p class="obw-agents__hint">
    Select agents to hire into your workspace. Click to toggle — selected agents will be activated.
  </p>

  {#if hired.size > 0}
    <div class="obw-agents__selection">
      {hired.size} agent{hired.size > 1 ? 's' : ''} selected
    </div>
  {/if}

  <ul class="obw-agents__grid" aria-label="Recommended agents">
    {#each RECOMMENDED as agent (agent.slug)}
      {@const isHired = hired.has(agent.slug)}
      <li>
        <button
          class="obw-agent-card"
          class:obw-agent-card--hired={isHired}
          onclick={() => toggle(agent.slug)}
          aria-pressed={isHired}
          aria-label="{isHired ? 'Unhire' : 'Hire'} {agent.name}"
          disabled={isHiring}
        >
          <div class="obw-agent-card__top">
            <span class="obw-agent-card__icon" aria-hidden="true">
              <svelte:component this={agent.icon} size={18} strokeWidth={1.8} />
            </span>
            <span class="obw-agent-card__cat">{agent.category}</span>
            {#if isHired}
              <span class="obw-agent-card__check" aria-hidden="true">
                <Check size={14} strokeWidth={2.5} />
              </span>
            {/if}
          </div>
          <span class="obw-agent-card__name">{agent.name}</span>
          <span class="obw-agent-card__desc">{agent.description}</span>
        </button>
      </li>
    {/each}
  </ul>

  <div class="obw-nav">
    <button class="obw-btn-ghost" onclick={onBack} disabled={isHiring}>← Back</button>
    <div class="obw-nav__right">
      <button class="obw-btn-ghost obw-btn-skip" onclick={onSkip} disabled={isHiring}>Skip</button>
      <button
        class="obw-btn-primary"
        onclick={handleNext}
        disabled={isHiring}
        aria-busy={isHiring}
      >
        {isHiring ? 'Hiring…' : 'Next →'}
      </button>
    </div>
  </div>
</div>

<style>
  .obw-agents {
    display: flex;
    flex-direction: column;
    gap: var(--space-4, 16px);
  }

  .obw-agents__hint {
    margin: 0;
    font-family: var(--font-sans, sans-serif);
    font-size: var(--text-sm, 0.875rem);
    color: var(--fg-muted);
    line-height: 1.6;
  }

  .obw-agents__grid {
    list-style: none;
    margin: 0;
    padding: 0;
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: var(--space-2, 8px);
  }

  .obw-agent-card {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 12px;
    border-radius: 8px;
    border: 1px solid var(--border);
    background: var(--bg-elevated);
    cursor: pointer;
    text-align: left;
    width: 100%;
    position: relative;
    transition: border-color 120ms ease, background 120ms ease;
  }

  .obw-agent-card:hover:not(:disabled) { border-color: var(--border-strong); }
  .obw-agent-card--hired { border-color: var(--cnp-accent); background: oklch(from var(--cnp-accent, #6b8cf7) l c h / 0.06); }
  .obw-agent-card:disabled { opacity: 0.6; cursor: not-allowed; }
  .obw-agent-card:focus-visible { outline: 2px solid var(--cnp-accent); outline-offset: 2px; }

  .obw-agent-card__top {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 4px;
  }

  .obw-agent-card__icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    border-radius: 8px;
    background: color-mix(in oklch, var(--cnp-accent, #6366f1) 12%, transparent);
    color: var(--cnp-accent, #6366f1);
    flex-shrink: 0;
  }

  .obw-agent-card--hired .obw-agent-card__icon {
    background: color-mix(in oklch, var(--cnp-accent, #6366f1) 20%, transparent);
  }

  .obw-agent-card__cat {
    font-family: var(--font-mono);
    font-size: 9px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--fg-subtle);
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    padding: 1px 6px;
    border-radius: 3px;
  }

  .obw-agent-card__check {
    margin-left: auto;
    color: var(--cnp-accent, #6366f1);
    display: flex;
  }

  .obw-agent-card__name {
    font-family: var(--font-sans);
    font-size: 13px;
    font-weight: 600;
    color: var(--fg);
  }

  .obw-agent-card__desc {
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
    line-height: 1.4;
  }

  .obw-nav {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding-top: var(--space-4, 16px);
    border-top: 1px solid var(--border);
    margin-top: auto;
  }

  .obw-nav__right { display: flex; gap: var(--space-3, 12px); align-items: center; }

  .obw-btn-ghost {
    background: none;
    border: none;
    color: var(--fg-subtle);
    font-family: var(--font-sans, sans-serif);
    font-size: var(--text-sm, 0.875rem);
    cursor: pointer;
    padding: 6px 8px;
    border-radius: 6px;
    transition: color 120ms ease;
  }

  .obw-btn-ghost:hover:not(:disabled) { color: var(--fg); }
  .obw-btn-ghost:disabled { opacity: 0.5; cursor: not-allowed; }
  .obw-btn-ghost:focus-visible { outline: 2px solid var(--cnp-accent); outline-offset: 2px; }
  .obw-btn-skip { font-size: var(--text-xs, 0.75rem); }

  .obw-btn-primary {
    padding: 8px 20px;
    border-radius: 999px;
    border: none;
    background: var(--cnp-accent);
    color: var(--user-accent-fg, #fff);
    font-family: var(--font-sans, sans-serif);
    font-size: var(--text-sm, 0.875rem);
    font-weight: 600;
    cursor: pointer;
    transition: opacity 120ms ease;
  }

  .obw-btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
  .obw-btn-primary:not(:disabled):hover { opacity: 0.88; }
  .obw-btn-primary:focus-visible { outline: 2px solid var(--cnp-accent); outline-offset: 3px; }
</style>
