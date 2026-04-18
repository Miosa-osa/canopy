<script lang="ts">
/**
 * Home / — composer + recent sessions + pinned agents (docs/02-frontend-design.md §6.1).
 * Cabinet pattern: serif greeting, composer-centric, time-aware.
 */

import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { Bot } from 'lucide-svelte';
import { goto } from '$app/navigation';
import { agentsQuery, hireAgentMutation } from '$lib/api/queries/agents.js';
import { createSessionMutation, sessionsQuery } from '$lib/api/queries/sessions.js';
import AgentCard from '$lib/design/patterns/AgentCard.svelte';
import Composer from '$lib/design/patterns/Composer.svelte';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import Kbd from '$lib/design/patterns/Kbd.svelte';
import StatusDot from '$lib/design/patterns/StatusDot.svelte';
import type { Agent, HireAgentBody } from '$lib/domain/agents/types.js';
import type { CreateSessionBody, Session } from '$lib/domain/sessions/types.js';

const queryClient = useQueryClient();

/** Time-aware greeting. */
function greeting(): string {
  const h = new Date().getHours();
  if (h >= 5 && h < 12) return 'Good morning, Roberto.';
  if (h >= 12 && h < 17) return 'Good afternoon, Roberto.';
  if (h >= 17 && h < 22) return 'Good evening, Roberto.';
  return 'Good night, Roberto.';
}

let currentGreeting = $state(greeting());

// Recent sessions — last 5
const recentSessionsQ = createQuery<Session[]>(
  sessionsQuery({ limit: 5 }) as CreateQueryOptions<Session[]>
);

// Pinned agents — hired agents only
const pinnedAgentsQ = createQuery<Agent[]>(
  agentsQuery({ hired: true }) as CreateQueryOptions<Agent[]>
);

const hireMut = createMutation<Agent, Error, { slug: string; body?: HireAgentBody }>(
  hireAgentMutation() as CreateMutationOptions<Agent, Error, { slug: string; body?: HireAgentBody }>
);

const sessionMut = createMutation<Session, Error, CreateSessionBody>(
  createSessionMutation() as CreateMutationOptions<Session, Error, CreateSessionBody>
);

function handleComposerSubmit(
  prompt: string,
  agentSlug: string | null,
  runtime: string | null
): void {
  $sessionMut.mutate(
    {
      prompt,
      agentSlug: agentSlug ?? undefined,
      runtimeType: runtime ?? 'claude-code',
      cwd: '.',
      workspaceSlug: undefined,
    },
    {
      onSuccess: (session) => {
        queryClient.invalidateQueries({ queryKey: ['sessions'] });
        goto(`/sessions/${session.id}`);
      },
    }
  );
}

function handleHire(slug: string): void {
  $hireMut.mutate(
    { slug },
    {
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: ['agents'] });
      },
    }
  );
}

function handleRun(slug: string): void {
  goto(`/agents/${slug}`);
}

// Typed data accessors — avoids NonNullable<TQueryFnData> issues in template
const recentSessions = $derived(($recentSessionsQ.data ?? []) as Session[]);
const pinnedAgents = $derived(($pinnedAgentsQ.data ?? []) as Agent[]);

/** Compute session duration in ms from startedAt / completedAt timestamps. */
function sessionDurationMs(s: Session): number | null {
  if (!s.startedAt || !s.completedAt) return null;
  return new Date(s.completedAt).getTime() - new Date(s.startedAt).getTime();
}

/** Format duration for display. */
function formatDuration(ms: number | null): string {
  if (!ms) return '—';
  const m = Math.floor(ms / 60_000);
  const s = Math.floor((ms % 60_000) / 1_000);
  return m > 0 ? `${m}m ${s}s` : `${s}s`;
}

/** Format relative time. */
function formatRelative(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const minutes = Math.floor(diff / 60_000);
  if (minutes < 1) return 'just now';
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}
</script>

<div class="home">
  <!-- Greeting -->
  <header class="home__header">
    <h1 class="home__greeting">{currentGreeting}</h1>
    <p class="home__subtext">What are we working on?</p>
  </header>

  <!-- Composer -->
  <section class="home__composer-wrap" aria-label="New session">
    <Composer onSubmit={handleComposerSubmit} />
    {#if $sessionMut.isPending}
      <p class="home__submitting">Creating session...</p>
    {/if}
  </section>

  <!-- Recent sessions -->
  <section class="home__section" aria-label="Recent sessions">
    <h2 class="home__section-title">Recent sessions</h2>
    <div class="home__divider"></div>

    {#if $recentSessionsQ.isLoading}
      {#each Array(3) as _, i (i)}
        <div class="session-row-skeleton" aria-hidden="true">
          <div class="skeleton-dot"></div>
          <div class="skeleton-text skeleton-text--wide"></div>
          <div class="skeleton-text skeleton-text--narrow"></div>
        </div>
      {/each}
    {:else if $recentSessionsQ.isError}
      <div class="home__inline-error">
        <span>Couldn't load recent sessions.</span>
        <button
          class="btn-compact btn-compact-ghost"
          onclick={() => $recentSessionsQ.refetch()}
        >Retry</button>
      </div>
    {:else if recentSessions.length === 0}
      <p class="home__empty-tip">No sessions yet. Start one above, or press <Kbd chord="⌘K" /> to open the command palette.</p>
    {:else}
      <ul class="session-list" role="list">
        {#each recentSessions as s (s.id)}
          <li>
            <button
              class="session-row"
              onclick={() => goto(`/sessions/${s.id}`)}
              aria-label="Open session: {s.agentSlug ?? 'Direct prompt'}"
            >
              <StatusDot
                color={s.status === 'running' ? 'green' : s.status === 'error' ? 'red' : 'grey'}
                pulse={s.status === 'running'}
              />
              <span class="session-row__agent">{s.agentSlug ?? 'Direct prompt'}</span>
              <span class="session-row__runtime">{s.runtimeType}</span>
              <span class="session-row__meta">{formatDuration(sessionDurationMs(s))}</span>
              <span class="session-row__time">{s.startedAt ? formatRelative(s.startedAt) : '—'}</span>
            </button>
          </li>
        {/each}
      </ul>
    {/if}
  </section>

  <!-- Pinned agents -->
  <section class="home__section" aria-label="Pinned agents">
    <h2 class="home__section-title">Pinned agents</h2>
    <div class="home__divider"></div>

    {#if $pinnedAgentsQ.isLoading}
      <div class="agent-grid">
        {#each Array(4) as _, i (i)}
          <div class="agent-card-skeleton" aria-hidden="true">
            <div class="skeleton-emoji"></div>
            <div class="skeleton-text skeleton-text--wide"></div>
            <div class="skeleton-text skeleton-text--narrow"></div>
          </div>
        {/each}
      </div>
    {:else if pinnedAgents.length === 0}
      <EmptyState
        icon={Bot as never}
        title="No agents hired yet"
        body="Browse the agent library and hire the ones you want available here."
        action="Browse agents"
        onAction={() => goto('/agents')}
      />
    {:else}
      <div class="agent-grid">
        {#each pinnedAgents.slice(0, 4) as agent (agent.slug)}
          <AgentCard
            {agent}
            onHire={handleHire}
            onRun={handleRun}
            isHiring={$hireMut.isPending && $hireMut.variables?.slug === agent.slug}
          />
        {/each}
      </div>
    {/if}
  </section>
</div>

<style>
  .home {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: var(--space-6);
    padding: var(--space-10) var(--space-8);
    overflow-y: auto;
    max-width: 760px;
    margin: 0 auto;
    width: 100%;
  }

  .home__header {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .home__greeting {
    font-family: var(--font-serif);
    font-size: var(--text-3xl);
    font-weight: 400;
    color: var(--fg);
    margin: 0;
    line-height: 1.1;
    letter-spacing: -0.03em;
  }

  .home__subtext {
    font-family: var(--font-sans);
    font-size: var(--text-lg);
    color: var(--fg-muted);
    margin: 0;
    letter-spacing: -0.015em;
  }

  .home__composer-wrap {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .home__submitting {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    margin: 0;
    animation: thinking-shimmer 1.4s cubic-bezier(0.65, 0, 0.35, 1) infinite;
  }

  .home__section {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .home__section-title {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    letter-spacing: 0.06em;
    color: var(--fg-subtle);
    margin: 0;
    text-transform: uppercase;
  }

  .home__divider {
    height: 1px;
    background: var(--border);
    margin-top: -var(--space-1);
  }

  .home__empty-tip {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    margin: 0;
  }

  .home__inline-error {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--signal-error);
  }

  /* Session list */
  .session-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .session-row {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-2) var(--space-3);
    border: none;
    background: transparent;
    border-radius: var(--radius-md);
    cursor: pointer;
    width: 100%;
    text-align: left;
    transition: background var(--dur-instant) var(--ease-out);
    min-height: 36px;
  }

  .session-row:hover {
    background: color-mix(in oklch, var(--fg) 5%, transparent 95%);
  }

  .session-row__agent {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .session-row__runtime,
  .session-row__meta {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    white-space: nowrap;
  }

  .session-row__time {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    white-space: nowrap;
    min-width: 60px;
    text-align: right;
  }

  /* Agent grid */
  .agent-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: var(--space-3);
  }

  /* Skeletons */
  .session-row-skeleton {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-2) var(--space-3);
    min-height: 36px;
  }

  .skeleton-dot {
    width: 7px;
    height: 7px;
    border-radius: 9999px;
    background: var(--border);
    flex-shrink: 0;
    animation: pulse 1.5s ease-in-out infinite;
  }

  .skeleton-text {
    height: 12px;
    background: var(--border);
    border-radius: var(--radius-sm);
    animation: pulse 1.5s ease-in-out infinite;
  }

  .skeleton-text--wide {
    flex: 1;
    max-width: 200px;
  }

  .skeleton-text--narrow {
    width: 60px;
  }

  .agent-card-skeleton {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-4);
    background: var(--bg-elevated);
    border-radius: var(--radius-xl);
    border: 1px solid var(--border);
    min-height: 140px;
  }

  .skeleton-emoji {
    width: 32px;
    height: 32px;
    background: var(--border);
    border-radius: var(--radius-sm);
    animation: pulse 1.5s ease-in-out infinite;
  }

  @keyframes pulse {
    0%, 100% { opacity: 0.4; }
    50% { opacity: 0.8; }
  }

  @keyframes thinking-shimmer {
    0%, 100% { opacity: 0.5; }
    50% { opacity: 1; }
  }
</style>
