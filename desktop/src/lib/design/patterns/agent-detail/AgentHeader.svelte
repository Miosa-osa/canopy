<script lang="ts">
/**
 * AgentHeader — avatar, name, status pill, quick stats row.
 * CSS prefix: adh- (AgentDetailHeader)
 */
import ActorAvatar from '$lib/design/patterns/ActorAvatar.svelte';
import StatusDot from '$lib/design/patterns/StatusDot.svelte';
import type { AgentDetail } from '$lib/domain/agents/types.js';

interface Props {
  agent: AgentDetail;
  hired: boolean;
  onHire: () => void;
  onFire: () => void;
  onRun: () => void;
  onKanban: () => void;
  hireIsPending: boolean;
  fireIsPending: boolean;
}

let { agent, hired, onHire, onFire, onRun, onKanban, hireIsPending, fireIsPending }: Props =
  $props();
</script>

<div class="adh-root">
  <div class="adh-identity">
    <ActorAvatar
      actor={{ type: 'agent', id: agent.slug, name: agent.name, emoji: agent.emoji }}
      size="lg"
    />
    <div class="adh-name-block">
      <h1 class="adh-name">{agent.emoji} {agent.name}</h1>
      <p class="adh-sub">{agent.title} · <span class="adh-category">{agent.category}</span></p>
    </div>
    <div class="adh-status">
      <StatusDot
        color={hired ? 'green' : 'grey'}
        label={hired ? 'Hired' : 'Available'}
        pulse={hired}
      />
    </div>
  </div>

  <div class="adh-stats">
    <div class="adh-stat">
      <span class="adh-stat__value">{agent.runCount}</span>
      <span class="adh-stat__label">Sessions</span>
    </div>
    <div class="adh-stat-sep" aria-hidden="true"></div>
    <div class="adh-stat">
      <span class="adh-stat__value">{agent.budget != null ? `$${agent.budget}` : '—'}</span>
      <span class="adh-stat__label">Budget/mo</span>
    </div>
    <div class="adh-stat-sep" aria-hidden="true"></div>
    <div class="adh-stat">
      <span class="adh-stat__value">{agent.contextTier?.toUpperCase() ?? '—'}</span>
      <span class="adh-stat__label">Context</span>
    </div>
    <div class="adh-stat-sep" aria-hidden="true"></div>
    <div class="adh-stat">
      <span class="adh-stat__value">{(agent.skills ?? []).length}</span>
      <span class="adh-stat__label">Skills</span>
    </div>
  </div>

  <div class="adh-actions">
    <button
      class="btn-pill btn-pill-secondary btn-pill-sm"
      onclick={onKanban}
      aria-label="Open Kanban for {agent.name}"
    >
      Kanban
    </button>
    {#if hired}
      <button
        class="btn-pill btn-pill-secondary btn-pill-sm"
        onclick={onFire}
        disabled={fireIsPending}
        aria-label="Fire {agent.name}"
      >
        {fireIsPending ? 'Firing…' : 'Fire'}
      </button>
      <button
        class="btn-pill btn-pill-primary btn-pill-sm"
        onclick={onRun}
        aria-label="Run {agent.name}"
      >
        Run ▸
      </button>
    {:else}
      <button
        class="btn-pill btn-pill-primary btn-pill-sm"
        onclick={onHire}
        disabled={hireIsPending}
        aria-label="Hire {agent.name}"
      >
        {hireIsPending ? 'Hiring…' : 'Hire'}
      </button>
    {/if}
  </div>
</div>

<style>
  .adh-root {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-6);
    border-bottom: 1px solid var(--border);
  }

  .adh-identity {
    display: flex;
    align-items: center;
    gap: var(--space-4);
  }

  .adh-name-block {
    flex: 1;
    min-width: 0;
  }

  .adh-name {
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
    letter-spacing: -0.025em;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .adh-sub {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: var(--space-1) 0 0;
    text-transform: capitalize;
  }

  .adh-category {
    color: var(--fg-subtle);
  }

  .adh-status {
    flex-shrink: 0;
  }

  /* Stats row */
  .adh-stats {
    display: flex;
    align-items: center;
    gap: var(--space-4);
  }

  .adh-stat {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .adh-stat__value {
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
  }

  .adh-stat__label {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--fg-subtle);
  }

  .adh-stat-sep {
    width: 1px;
    height: 24px;
    background: var(--border);
    flex-shrink: 0;
  }

  /* Actions */
  .adh-actions {
    display: flex;
    gap: var(--space-2);
    flex-wrap: wrap;
  }
</style>
