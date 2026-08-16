<script lang="ts">
  /**
   * /team — People + org chart.
   * Two tabs: Grid (agent card grid) and Org (CSS tree grouped by category).
   * Reads from GET /api/v1/agents (336 seeded agents).
   * svelte-flow is not installed — org chart uses CSS flex layout.
   * CSS prefix: tm- (team)
   */
  import {
    type CreateQueryOptions,
    createQuery,
  } from "@tanstack/svelte-query";
  import { untrack } from "svelte";
  import { writable } from "svelte/store";
  import { goto } from "$app/navigation";
  import { Search, Users } from "lucide-svelte";
  import { agentsQuery } from "$lib/api/queries/agents.js";
  import EmptyState from "$lib/design/patterns/EmptyState.svelte";
  import SkeletonList from "$lib/design/patterns/SkeletonList.svelte";
  import type { Agent, AgentCategory } from "$lib/domain/agents/types.js";

  // ── Query ──────────────────────────────────────────────────────────────────

  const agentOptsStore = writable(
    untrack(() => agentsQuery() as CreateQueryOptions<Agent[]>)
  );
  const agentsQ = createQuery<Agent[]>(agentOptsStore);
  const agents = $derived(($agentsQ.data ?? []) as Agent[]);

  // ── Tabs ───────────────────────────────────────────────────────────────────

  type Tab = "grid" | "org";
  let activeTab = $state<Tab>("grid");

  // ── Search ─────────────────────────────────────────────────────────────────

  let search = $state("");

  const filteredAgents = $derived(
    search.trim() === ""
      ? agents
      : agents.filter(
          (a) =>
            a.name.toLowerCase().includes(search.toLowerCase()) ||
            a.category.toLowerCase().includes(search.toLowerCase())
        )
  );

  // ── Org chart grouping ─────────────────────────────────────────────────────

  interface CategoryGroup {
    category: AgentCategory;
    label: string;
    members: Agent[];
  }

  const CATEGORY_LABELS: Record<AgentCategory, string> = {
    academic: "Academic",
    "creative-content": "Creative & Content",
    design: "Design",
    engineering: "Engineering",
    executive: "Executive",
    "game-development": "Game Dev",
    growth: "Growth",
    marketing: "Marketing",
    operations: "Operations",
    "paid-media": "Paid Media",
    product: "Product",
    "project-management": "Project Mgmt",
    revenue: "Revenue",
    sales: "Sales",
    "spatial-computing": "Spatial",
    specialized: "Specialized",
    support: "Support",
    technology: "Technology",
    testing: "Testing",
  };

  const categoryGroups = $derived(
    Object.entries(
      filteredAgents.reduce<Partial<Record<AgentCategory, Agent[]>>>((acc, agent) => {
        const cat = agent.category;
        if (!acc[cat]) acc[cat] = [];
        acc[cat]!.push(agent);
        return acc;
      }, {})
    )
      .map(([cat, members]) => ({
        category: cat as AgentCategory,
        label: CATEGORY_LABELS[cat as AgentCategory] ?? cat,
        members: members ?? [],
      }))
      .sort((a, b) => a.label.localeCompare(b.label))
  );

  function initials(name: string): string {
    return name
      .split(" ")
      .slice(0, 2)
      .map((w) => w[0] ?? "")
      .join("")
      .toUpperCase();
  }
</script>

<div class="tm-page">
  <!-- Header -->
  <header class="tm-header">
    <div class="tm-title-row">
      <h1 class="tm-title">Team</h1>
      <span class="tm-count">{agents.length} agents</span>
    </div>

    <div class="tm-toolbar">
      <div class="tm-search-wrap">
        <Search size={13} class="tm-search-icon" aria-hidden="true" />
        <input
          class="tm-search"
          type="search"
          placeholder="Search agents..."
          bind:value={search}
          aria-label="Search agents"
        />
      </div>

      <div class="tm-tabs" role="tablist" aria-label="View mode">
        <button
          class="tm-tab"
          class:tm-tab--active={activeTab === "grid"}
          role="tab"
          aria-selected={activeTab === "grid"}
          onclick={() => { activeTab = "grid"; }}
        >
          Grid
        </button>
        <button
          class="tm-tab"
          class:tm-tab--active={activeTab === "org"}
          role="tab"
          aria-selected={activeTab === "org"}
          onclick={() => { activeTab = "org"; }}
        >
          Org
        </button>
      </div>
    </div>
  </header>

  <!-- Content -->
  <div class="tm-main" role="tabpanel">
    {#if $agentsQ.isLoading}
      <div class="tm-skeleton">
        <SkeletonList count={8} height="4rem" gap="0.5rem" />
      </div>
    {:else if $agentsQ.isError}
      <EmptyState
        icon={Users as never}
        title="Failed to load agents"
        body="Check your connection and try again."
        action="Retry"
        onAction={() => $agentsQ.refetch()}
      />
    {:else if agents.length === 0}
      <EmptyState
        icon={Users as never}
        title="No agents found"
        body="No agents are available yet."
      />

    {:else if activeTab === "grid"}
      <!-- Grid view -->
      {#if filteredAgents.length === 0}
        <div class="tm-empty">
          <p class="tm-empty__text">No results for "{search}".</p>
        </div>
      {:else}
        <div class="tm-grid">
          {#each filteredAgents as agent (agent.slug)}
            <button class="tm-card" aria-label="{agent.name}, {agent.category}" onclick={() => goto('/agents/' + agent.slug)}>
              <div class="tm-card__avatar" aria-hidden="true">
                {initials(agent.name)}
              </div>
              <div class="tm-card__body">
                <span class="tm-card__name">{agent.name}</span>
                <span class="tm-card__cat">{CATEGORY_LABELS[agent.category] ?? agent.category}</span>
                {#if agent.hired}
                  <span class="tm-badge tm-badge--hired">Hired</span>
                {/if}
              </div>
            </button>
          {/each}
        </div>
      {/if}

    {:else}
      <!-- Org chart view — grouped by category -->
      <div class="tm-org" aria-label="Agent org chart">
        <div class="tm-org__root">
          <div class="tm-org__node tm-org__node--root">All Agents ({agents.length})</div>
        </div>
        <div class="tm-org__departments">
          {#each categoryGroups as group (group.category)}
            <div class="tm-dept">
              <div class="tm-dept__head">
                <span class="tm-dept__name">{group.label}</span>
                <span class="tm-dept__count">{group.members.length}</span>
              </div>
              <div class="tm-dept__members">
                {#each group.members.slice(0, 6) as member (member.slug)}
                  <button class="tm-dept__member" title="{member.name}" onclick={() => goto('/agents/' + member.slug)}>
                    <span class="tm-dept__avatar" aria-hidden="true">
                      {initials(member.name)}
                    </span>
                    <span class="tm-dept__mname">{member.name}</span>
                  </button>
                {/each}
                {#if group.members.length > 6}
                  <div class="tm-dept__more">+{group.members.length - 6} more</div>
                {/if}
              </div>
            </div>
          {/each}
        </div>
      </div>
    {/if}
  </div>
</div>

<style>
  .tm-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  /* Header */
  .tm-header {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-5) var(--space-6) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .tm-title-row {
    display: flex;
    align-items: baseline;
    gap: var(--space-3);
  }

  .tm-title {
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
    letter-spacing: -0.025em;
  }

  .tm-count {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
  }

  .tm-toolbar {
    display: flex;
    align-items: center;
    gap: var(--space-3);
  }

  /* Search */
  .tm-search-wrap {
    flex: 1;
    position: relative;
    display: flex;
    align-items: center;
  }

  :global(.tm-search-icon) {
    position: absolute;
    left: var(--space-3);
    color: var(--fg-subtle);
    pointer-events: none;
  }

  .tm-search {
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

  .tm-search:focus {
    border-color: var(--border-strong);
  }

  .tm-search::placeholder {
    color: var(--fg-subtle);
  }

  /* Tabs */
  .tm-tabs {
    display: flex;
    gap: 2px;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: 2px;
    flex-shrink: 0;
  }

  .tm-tab {
    padding: var(--space-1) var(--space-3);
    background: transparent;
    border: none;
    border-radius: calc(var(--radius-md) - 2px);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    transition: background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .tm-tab:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
  }

  .tm-tab--active {
    background: color-mix(in oklch, var(--fg) 12%, transparent 88%);
    color: var(--fg);
    font-weight: 500;
  }

  /* Main content area */
  .tm-main {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-5) var(--space-6);
  }

  .tm-skeleton {
    max-width: 600px;
  }

  /* Grid */
  .tm-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: var(--space-3);
  }

  @media (max-width: 1100px) {
    .tm-grid { grid-template-columns: repeat(3, 1fr); }
  }

  @media (max-width: 800px) {
    .tm-grid { grid-template-columns: repeat(2, 1fr); }
  }

  .tm-card {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-3);
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    transition: border-color var(--dur-instant) var(--ease-out);
    cursor: pointer;
    text-align: left;
    width: 100%;
  }

  .tm-card:hover {
    border-color: var(--border-strong);
  }

  .tm-card__avatar {
    width: 32px;
    height: 32px;
    background: color-mix(in oklch, var(--fg) 10%, transparent 90%);
    border: 1px solid var(--border);
    border-radius: 9999px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-family: var(--font-mono);
    font-size: 11px;
    font-weight: 700;
    color: var(--fg-muted);
    flex-shrink: 0;
  }

  .tm-card__body {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }

  .tm-card__name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .tm-card__cat {
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .tm-badge {
    display: inline-block;
    font-family: var(--font-sans);
    font-size: 9px;
    font-weight: 600;
    padding: 1px 5px;
    border-radius: var(--radius-sm);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .tm-badge--hired {
    background: color-mix(in oklch, var(--cnp-accent, var(--fg)) 15%, transparent 85%);
    color: var(--cnp-accent, var(--fg-muted));
    border: 1px solid color-mix(in oklch, var(--cnp-accent, var(--fg)) 25%, transparent 75%);
  }

  /* Empty */
  .tm-empty {
    padding: var(--space-8) 0;
    text-align: center;
  }

  .tm-empty__text {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    margin: 0;
  }

  /* Org chart */
  .tm-org {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-6);
  }

  .tm-org__root {
    display: flex;
    justify-content: center;
  }

  .tm-org__node--root {
    padding: var(--space-2) var(--space-4);
    background: color-mix(in oklch, var(--fg) 10%, transparent 90%);
    border: 1px solid var(--border-strong);
    border-radius: var(--radius-md);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
  }

  .tm-org__departments {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: var(--space-3);
    width: 100%;
  }

  @media (max-width: 1100px) {
    .tm-org__departments { grid-template-columns: repeat(3, 1fr); }
  }

  @media (max-width: 800px) {
    .tm-org__departments { grid-template-columns: repeat(2, 1fr); }
  }

  .tm-dept {
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: var(--radius-xl);
    overflow: hidden;
  }

  .tm-dept__head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-2) var(--space-3);
    border-bottom: 1px solid var(--border);
    background: var(--bg-inset);
  }

  .tm-dept__name {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    color: var(--fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .tm-dept__count {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .tm-dept__members {
    display: flex;
    flex-direction: column;
    gap: 1px;
    padding: var(--space-1);
  }

  .tm-dept__member {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-1) var(--space-2);
    border-radius: var(--radius-sm);
    transition: background var(--dur-instant) var(--ease-out);
    cursor: pointer;
    background: none;
    border: none;
    width: 100%;
    text-align: left;
  }

  .tm-dept__member:hover {
    background: color-mix(in oklch, var(--fg) 5%, transparent 95%);
  }

  .tm-dept__avatar {
    width: 20px;
    height: 20px;
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    border-radius: 9999px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-family: var(--font-mono);
    font-size: 8px;
    font-weight: 700;
    color: var(--fg-subtle);
    flex-shrink: 0;
  }

  .tm-dept__mname {
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .tm-dept__more {
    padding: var(--space-1) var(--space-2);
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--fg-subtle);
  }
</style>
