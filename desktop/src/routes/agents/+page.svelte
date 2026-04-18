<script lang="ts">
/**
 * Agents library — /agents (docs/02-frontend-design.md §6.6).
 * Grid of AgentCard. 19 category filters (pills). Search input.
 * Loading: 12 skeletons. Empty: EmptyState component.
 */
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { Bot, Plus, Search } from 'lucide-svelte';
import { goto } from '$app/navigation';
import { agentsQuery, fireAgentMutation, hireAgentMutation } from '$lib/api/queries/agents.js';
import AgentCard from '$lib/design/patterns/AgentCard.svelte';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import type { Agent, AgentCategory, HireAgentBody } from '$lib/domain/agents/types.js';

const queryClient = useQueryClient();

/** All 19 categories from the agents directory. */
const categories: Array<{ value: AgentCategory | 'all'; label: string }> = [
  { value: 'all', label: 'All' },
  { value: 'sales', label: 'Sales' },
  { value: 'engineering', label: 'Engineering' },
  { value: 'marketing', label: 'Marketing' },
  { value: 'operations', label: 'Operations' },
  { value: 'product', label: 'Product' },
  { value: 'executive', label: 'Executive' },
  { value: 'growth', label: 'Growth' },
  { value: 'revenue', label: 'Revenue' },
  { value: 'creative-content', label: 'Creative Content' },
  { value: 'technology', label: 'Technology' },
  { value: 'support', label: 'Support' },
  { value: 'project-management', label: 'PM' },
  { value: 'paid-media', label: 'Paid Media' },
  { value: 'design', label: 'Design' },
  { value: 'academic', label: 'Academic' },
  { value: 'testing', label: 'Testing' },
  { value: 'specialized', label: 'Specialized' },
  { value: 'game-development', label: 'Game Dev' },
  { value: 'spatial-computing', label: 'Spatial' },
];

let searchQuery = $state('');
let selectedCategory = $state<AgentCategory | 'all'>('all');

const agentsOpts = $derived(
  agentsQuery(
    selectedCategory === 'all'
      ? { query: searchQuery || undefined }
      : { category: selectedCategory, query: searchQuery || undefined }
  ) as CreateQueryOptions<Agent[]>
);
const agentsQ = createQuery<Agent[]>(agentsOpts);

const hireMut = createMutation<Agent, Error, { slug: string; body?: HireAgentBody }>(
  hireAgentMutation() as CreateMutationOptions<Agent, Error, { slug: string; body?: HireAgentBody }>
);

const fireMut = createMutation<void, Error, string>(
  fireAgentMutation() as CreateMutationOptions<void, Error, string>
);

// Typed accessor
const agents = $derived(($agentsQ.data ?? []) as Agent[]);

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
  goto(`/sessions?agent=${slug}`);
}
</script>

<div class="agents-page">
  <!-- Header -->
  <header class="agents-page__header">
    <div class="agents-page__title-row">
      <h1 class="agents-page__title">Agents</h1>
      <button
        class="btn-pill btn-pill-primary btn-pill-sm"
        onclick={() => goto('/agents/new')}
        aria-label="New agent"
      >
        <Plus size={12} aria-hidden="true" /> New Agent
      </button>
    </div>

    <!-- Search -->
    <div class="agents-page__search-wrap">
      <Search size={13} class="agents-page__search-icon" aria-hidden="true" />
      <input
        class="agents-page__search"
        type="search"
        placeholder="Search agents..."
        bind:value={searchQuery}
        aria-label="Search agents"
      />
    </div>
  </header>

  <!-- Category filter pills -->
  <div class="agents-page__filters" role="group" aria-label="Filter by category">
    {#each categories as cat (cat.value)}
      <button
        class="btn-pill btn-pill-xs agents-page__filter-pill"
        class:agents-page__filter-pill--active={selectedCategory === cat.value}
        onclick={() => { selectedCategory = cat.value; }}
        aria-pressed={selectedCategory === cat.value}
      >
        {cat.label}
      </button>
    {/each}
  </div>

  <!-- Grid -->
  <main class="agents-page__grid-wrap">
    {#if $agentsQ.isLoading}
      <div class="agents-grid">
        {#each Array(12) as _, i (i)}
          <div class="agent-card-skeleton" aria-hidden="true">
            <div class="sk sk--emoji"></div>
            <div class="sk sk--line sk--wide"></div>
            <div class="sk sk--line sk--medium"></div>
            <div class="sk sk--line sk--narrow"></div>
            <div class="sk sk--actions">
              <div class="sk sk--line sk--narrow"></div>
              <div class="sk sk--pill"></div>
            </div>
          </div>
        {/each}
      </div>
    {:else if $agentsQ.isError}
      <EmptyState
        icon={Bot as never}
        title="Failed to load agents"
        body="Check your connection and try again."
        action="Retry"
        onAction={() => $agentsQ.refetch()}
      />
    {:else if agents.length === 0}
      <EmptyState
        icon={Bot as never}
        title="No agents found"
        body={searchQuery ? `No results for "${searchQuery}". Try a different search.` : 'No agents in this category yet.'}
        action={searchQuery ? 'Clear search' : 'Browse all'}
        onAction={() => { searchQuery = ''; selectedCategory = 'all'; }}
      />
    {:else}
      <div class="agents-grid">
        {#each agents as agent (agent.slug)}
          <AgentCard
            {agent}
            onHire={handleHire}
            onRun={handleRun}
            isHiring={$hireMut.isPending && $hireMut.variables?.slug === agent.slug}
          />
        {/each}
      </div>
    {/if}
  </main>
</div>

<style>
  .agents-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  .agents-page__header {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-5) var(--space-6) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .agents-page__title-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .agents-page__title {
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
    letter-spacing: -0.025em;
  }

  .agents-page__search-wrap {
    position: relative;
    display: flex;
    align-items: center;
  }

  :global(.agents-page__search-icon) {
    position: absolute;
    left: var(--space-3);
    color: var(--fg-subtle);
    pointer-events: none;
  }

  .agents-page__search {
    width: 100%;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    padding: var(--space-2) var(--space-3) var(--space-2) calc(var(--space-3) + 22px);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .agents-page__search:focus {
    border-color: var(--border-strong);
  }

  .agents-page__search::placeholder {
    color: var(--fg-subtle);
  }

  .agents-page__filters {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-1);
    padding: var(--space-3) var(--space-6);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .agents-page__filter-pill {
    background: transparent;
    border: 1px solid var(--border);
    color: var(--fg-muted);
    font-size: 11px;
  }

  .agents-page__filter-pill:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .agents-page__filter-pill--active {
    background: color-mix(in oklch, var(--fg) 12%, transparent 88%);
    color: var(--fg);
    border-color: var(--border-strong);
  }

  .agents-page__grid-wrap {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-5) var(--space-6);
  }

  .agents-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--space-3);
  }

  @media (max-width: 900px) {
    .agents-grid { grid-template-columns: repeat(2, 1fr); }
  }

  @media (max-width: 600px) {
    .agents-grid { grid-template-columns: 1fr; }
  }

  /* Skeletons */
  .agent-card-skeleton {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-4);
    background: var(--bg-elevated);
    border-radius: var(--radius-xl);
    border: 1px solid var(--border);
    min-height: 180px;
  }

  .sk {
    animation: sk-pulse 1.5s ease-in-out infinite;
    background: var(--border);
    border-radius: var(--radius-sm);
  }

  .sk--emoji { width: 36px; height: 36px; border-radius: var(--radius-sm); }
  .sk--line { height: 12px; }
  .sk--wide { width: 75%; }
  .sk--medium { width: 55%; }
  .sk--narrow { width: 40%; }
  .sk--pill { width: 60px; height: 24px; border-radius: 9999px; }
  .sk--actions {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-top: auto;
    background: transparent;
    animation: none;
  }

  @keyframes sk-pulse {
    0%, 100% { opacity: 0.35; }
    50% { opacity: 0.65; }
  }
</style>
