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
import { Bot, GitBranch, Plus, RefreshCw, Search, Sparkles } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import {
  agentsQuery,
  fireAgentMutation,
  hireAgentMutation,
  syncWorkspaceAgentsMutation,
} from '$lib/api/queries/agents.js';
import { createSession } from '$lib/api/queries/sessions.js';
import AgentCard from '$lib/design/patterns/AgentCard.svelte';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import HireAgentModal from '$lib/design/patterns/agents/HireAgentModal.svelte';
import AgentOrgChart from '$lib/design/patterns/agents/AgentOrgChart.svelte';
import NLAgentCreator from '$lib/design/patterns/agents/NLAgentCreator.svelte';
import type {
  Agent,
  AgentCategory,
  HireAgentBody,
  WorkspaceAgentSyncResult,
} from '$lib/domain/agents/types.js';
import { useListKeyboard } from '$lib/utils/useListKeyboard.svelte.js';
import ViewPicker from '$lib/design/primitives/ViewPicker.svelte';
import type { ViewState } from '$lib/design/primitives/ViewPicker.svelte';
import { toasts } from '$lib/stores/toasts.svelte.js';
import { activeWorkspace } from '$lib/stores/active-workspace.svelte.js';

const queryClient = useQueryClient();

// ── Hire modal state ─────────────────────────────────────────────────────────
let hireTarget = $state<Agent | null>(null);

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

const agentsOptsStore = writable(
  untrack(
    () =>
      agentsQuery(
        selectedCategory === 'all'
          ? { query: searchQuery || undefined }
          : { category: selectedCategory, query: searchQuery || undefined }
      ) as CreateQueryOptions<Agent[]>
  )
);

$effect(() => {
  agentsOptsStore.set(
    agentsQuery(
      selectedCategory === 'all'
        ? { query: searchQuery || undefined }
        : { category: selectedCategory, query: searchQuery || undefined }
    ) as CreateQueryOptions<Agent[]>
  );
});

const agentsQ = createQuery<Agent[]>(agentsOptsStore);

const hireMut = createMutation<Agent, Error, { slug: string; body?: HireAgentBody }>(
  hireAgentMutation() as CreateMutationOptions<Agent, Error, { slug: string; body?: HireAgentBody }>
);

const fireMut = createMutation<void, Error, string>(
  fireAgentMutation() as CreateMutationOptions<void, Error, string>
);

const syncMut = createMutation<WorkspaceAgentSyncResult, Error, string>(
  syncWorkspaceAgentsMutation() as CreateMutationOptions<WorkspaceAgentSyncResult, Error, string>
);

// Typed accessor
const agents = $derived(($agentsQ.data ?? []) as Agent[]);

function handleHire(slug: string): void {
  const agent = agents.find((a) => a.slug === slug);
  if (agent) hireTarget = agent;
}

function handleHired(): void {
  queryClient.invalidateQueries({ queryKey: ['agents'] });
  toasts.show(`${hireTarget?.name ?? 'Agent'} hired.`, 'success');
  hireTarget = null;
}

function handleSyncWorkspaceAgents(): void {
  const workspaceSlug = activeWorkspace.slug;
  if (!workspaceSlug) {
    toasts.show('Select a workspace before syncing .canopy agents.', 'error');
    return;
  }

  $syncMut.mutate(workspaceSlug, {
    onSuccess: (result) => {
      queryClient.invalidateQueries({ queryKey: ['agents'] });
      const changed = result.imported + result.updated;
      const skipped = result.skipped > 0 ? ` ${result.skipped} skipped.` : '';
      toasts.show(
        `Synced ${changed} agent${changed === 1 ? '' : 's'} from .canopy/agents.${skipped}`,
        result.errors.length > 0 ? 'warning' : 'success'
      );
    },
    onError: (err) => {
      toasts.show(err instanceof Error ? err.message : 'Failed to sync workspace agents.', 'error');
    },
  });
}

async function handleRun(slug: string): Promise<void> {
  const agent = agents.find((a) => a.slug === slug);
  try {
    const session = await createSession({
      agentSlug: slug,
      runtimeType: agent?.defaultRuntime ?? 'claude-local',
      cwd: '~',
      kind: 'agent_conversation',
      prompt: `Run ${agent?.name ?? slug}.`,
    }) as { id?: string; sessionId?: string };
    const sessionId = session.id ?? session.sessionId;
    if (!sessionId) throw new Error('Session started, but the backend did not return a session id.');
    await goto(`/sessions/${sessionId}`);
  } catch (err) {
    toasts.show(err instanceof Error ? err.message : 'Failed to start agent run.', 'error');
  }
}

// ── Keyboard navigation ──────────────────────────────────────────────────────

let shortcutHelpVisible = $state(false);
let view = $state<ViewState>({ layout: 'grid', density: 'comfortable', sort: 'name_asc' });

// ── Org chart / NL creator state ─────────────────────────────────────────────
const LS_ORG_KEY = 'canopy.agents.view';
let orgView = $state<'grid' | 'org'>(
  typeof localStorage !== 'undefined'
    ? ((localStorage.getItem(LS_ORG_KEY) as 'grid' | 'org') ?? 'grid')
    : 'grid'
);
let nlCreatorOpen = $state(false);

$effect(() => {
  if (typeof localStorage !== 'undefined') {
    localStorage.setItem(LS_ORG_KEY, orgView);
  }
});

const visibleAgents = $derived.by(() => {
  const q = searchQuery.trim().toLowerCase();
  const filtered = agents.filter((agent) => {
    if (selectedCategory !== 'all' && agent.category !== selectedCategory) return false;
    if (!q) return true;
    return [
      agent.slug,
      agent.name,
      agent.title,
      agent.category,
      agent.owner ?? '',
      agent.bio,
      String(agent.config?.team ?? ''),
      String(agent.config?.department ?? ''),
      String(agent.config?.division ?? ''),
    ].some((value) => value.toLowerCase().includes(q));
  });
  const sorted = [...filtered];
  switch (view.sort) {
    case 'name_desc':
      sorted.sort((a, b) => b.name.localeCompare(a.name));
      break;
    case 'status':
      sorted.sort((a, b) => Number(b.hired) - Number(a.hired) || a.name.localeCompare(b.name));
      break;
    case 'oldest':
      sorted.sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());
      break;
    case 'recent':
      sorted.sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime());
      break;
    case 'name_asc':
    default:
      sorted.sort((a, b) => a.name.localeCompare(b.name));
      break;
  }
  return sorted;
});

const kb = useListKeyboard({
  items: () => agents,
  onSelect: (agent) => goto(`/agents/${agent.slug}`),
  onRefresh: () => {
    queryClient.invalidateQueries({ queryKey: ['agents'] });
  },
  onHelp: () => {
    shortcutHelpVisible = !shortcutHelpVisible;
  },
});
</script>

<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
<div
  class="agents-page"
  role="region"
  aria-label="Agents list"
  onkeydown={kb.handleKeydown}
>
  <!-- Header -->
  <header class="agents-page__header">
    <div class="agents-page__title-row">
      <h1 class="agents-page__title">Agents</h1>
      <div style="display:flex;align-items:center;gap:var(--space-2)">
        <!-- Org chart / grid toggle -->
        <div class="agents-page__view-toggle" role="group" aria-label="View mode">
          <button
            class="btn-pill btn-pill-xs agents-page__view-btn"
            class:agents-page__view-btn--active={orgView === 'grid'}
            onclick={() => { orgView = 'grid'; }}
            aria-pressed={orgView === 'grid'}
            aria-label="Grid view"
          >
            Grid
          </button>
          <button
            class="btn-pill btn-pill-xs agents-page__view-btn"
            class:agents-page__view-btn--active={orgView === 'org'}
            onclick={() => { orgView = 'org'; }}
            aria-pressed={orgView === 'org'}
            aria-label="Org chart view"
          >
            <GitBranch size={11} aria-hidden="true" /> Org
          </button>
        </div>

        {#if orgView === 'grid'}
          <ViewPicker routeSlug="agents" bind:view />
        {/if}
        <button
          class="btn-pill btn-pill-sm agents-page__sync"
          onclick={handleSyncWorkspaceAgents}
          disabled={$syncMut.isPending || !activeWorkspace.slug}
          aria-label="Sync workspace agents from .canopy"
          title={activeWorkspace.slug ? `Sync ${activeWorkspace.name ?? activeWorkspace.slug}/.canopy/agents` : 'Select a workspace first'}
        >
          <RefreshCw
            size={12}
            aria-hidden="true"
            class={$syncMut.isPending ? 'agents-page__sync-icon--spin' : ''}
          />
          Sync .canopy
        </button>
        <button
          class="btn-pill btn-pill-sm agents-page__nl-btn"
          onclick={() => { nlCreatorOpen = true; }}
          aria-label="Create agent with AI"
        >
          <Sparkles size={12} aria-hidden="true" /> Create with AI
        </button>
        <button
          class="btn-pill btn-pill-primary btn-pill-sm"
          onclick={() => goto('/agents/new')}
          aria-label="New agent"
        >
          <Plus size={12} aria-hidden="true" /> New Agent
        </button>
      </div>
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
    <p class="agents-page__source">
      Workspace agents load from <code>{activeWorkspace.rootPath ? `${activeWorkspace.rootPath}/.canopy/agents` : '.canopy/agents'}</code>.
      Persona edits write back when an agent came from a workspace markdown file.
    </p>
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

  <!-- Grid / Org chart content -->
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
    {:else if orgView === 'org'}
      <AgentOrgChart agents={visibleAgents} />
    {:else}
      <div
        class="agents-grid"
        class:agents-grid--list={view.layout === 'list'}
        class:agents-grid--compact={view.density === 'compact'}
        class:agents-grid--roomy={view.density === 'roomy'}
      >
        {#each visibleAgents as agent (agent.slug)}
          <AgentCard
            {agent}
            onHire={handleHire}
            onRun={handleRun}
            isHiring={$hireMut.isPending && $hireMut.variables?.slug === agent.slug}
            class={[
              view.layout === 'list' ? 'cnp-agent-card--list' : '',
              `cnp-agent-card--${view.density}`,
            ].filter(Boolean).join(' ')}
          />
        {/each}
      </div>
    {/if}
  </main>
</div>

<!-- Hire configuration modal -->
{#if hireTarget}
  <HireAgentModal
    agent={hireTarget}
    open={hireTarget !== null}
    onClose={() => { hireTarget = null; }}
    onHired={handleHired}
  />
{/if}

<!-- NL Agent Creator -->
<NLAgentCreator open={nlCreatorOpen} onClose={() => { nlCreatorOpen = false; }} />

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
    gap: var(--space-3);
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

  /* ── View toggle (Grid | Org) ──────────────────────────────────────────── */

  .agents-page__view-toggle {
    display: flex;
    align-items: center;
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    border-radius: var(--radius-md);
    padding: 2px;
    gap: 1px;
  }

  .agents-page__view-btn {
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 3px 8px;
    border: none;
    background: transparent;
    border-radius: var(--radius-sm);
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 500;
    color: var(--fg-muted);
    cursor: pointer;
    white-space: nowrap;
    transition: background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .agents-page__view-btn:hover {
    color: var(--fg);
  }

  .agents-page__view-btn--active {
    background: var(--bg-elevated);
    color: var(--fg);
  }

  .agents-page__view-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  /* ── NL creator button ──────────────────────────────────────────────────── */

  .agents-page__nl-btn {
    border: 1px solid color-mix(in oklch, var(--cnp-accent, oklch(0.55 0.18 250)) 35%, var(--border));
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.55 0.18 250)) 8%, var(--bg-elevated));
    color: var(--cnp-accent, oklch(0.55 0.18 250));
    display: flex;
    align-items: center;
    gap: 4px;
    white-space: nowrap;
  }

  .agents-page__nl-btn:hover {
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.55 0.18 250)) 14%, var(--bg-elevated));
  }

  .agents-page__sync {
    border: 1px solid var(--border);
    background: var(--bg-elevated);
    color: var(--fg-muted);
    white-space: nowrap;
  }

  .agents-page__sync:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  :global(.agents-page__sync-icon--spin) {
    animation: agents-spin 0.9s linear infinite;
  }

  .agents-page__source {
    margin: calc(var(--space-2) * -1) 0 0;
    color: var(--fg-subtle);
    font-size: var(--text-xs);
    line-height: 1.5;
  }

  .agents-page__source code {
    color: var(--fg-muted);
    font-family: var(--font-mono);
    font-size: 11px;
  }

  @keyframes agents-spin {
    to { transform: rotate(360deg); }
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

  .agents-grid--list {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .agents-grid--list :global(.cnp-agent-card--list) {
    min-height: 0;
  }

  .agents-grid--compact {
    gap: var(--space-2);
  }

  .agents-grid--roomy {
    gap: var(--space-4);
  }

  .agents-grid--compact :global(.cnp-agent-card) {
    padding: var(--space-3);
  }

  .agents-grid--roomy :global(.cnp-agent-card) {
    padding: var(--space-5);
    min-height: 220px;
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
