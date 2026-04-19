<script lang="ts">
  /**
   * Home / — command center (Canopy v2 Phase 6 Wave A Track #115).
   * Five sections: greeting, stat strip, active agents, quick actions, recent activity.
   * LOC target: ≤ 450.
   */

  // TODO: pull from auth when multi-user lands
  const USER_NAME = 'Roberto';

  import {
    type CreateQueryOptions,
    createQuery,
  } from '@tanstack/svelte-query';
  import {
    Activity,
    Bell,
    CheckSquare,
    FileText,
    MessageSquare,
    Plus,
    ShieldAlert,
    Terminal,
    Wallet,
  } from 'lucide-svelte';
  import { format, formatDistanceToNow } from 'date-fns';
  import { goto } from '$app/navigation';
  import { untrack } from 'svelte';
  import { writable } from 'svelte/store';
  import { approvalsQuery } from '$lib/api/queries/governance.js';
  import { dashboardSummaryQuery } from '$lib/api/queries/dashboard.js';
  import { agentsQuery } from '$lib/api/queries/agents.js';
  import { sessionsQuery } from '$lib/api/queries/sessions.js';
  import { tasksQuery } from '$lib/api/queries/tasks.js';
  import { unreadCountQuery } from '$lib/api/queries/notifications.js';
  import AgentLiveCard from '$lib/design/patterns/AgentLiveCard.svelte';
  import Kbd from '$lib/design/patterns/Kbd.svelte';
  import StatusDot from '$lib/design/patterns/StatusDot.svelte';
  import WorkspaceSwitcher from '$lib/design/patterns/WorkspaceSwitcher.svelte';
  import { theme } from '$lib/stores/theme.svelte.js';
  import { greetingFor } from '$lib/utils/greeting.js';
  import type { Agent } from '$lib/domain/agents/types.js';
  import type { DashboardSummary } from '$lib/domain/dashboard/types.js';
  import type { Approval } from '$lib/domain/governance/types.js';
  import type { Session } from '$lib/domain/sessions/types.js';
  import type { Task } from '$lib/domain/tasks/types.js';

  // ── Greeting ─────────────────────────────────────────────────────────────────

  const greeting = $derived(greetingFor(new Date().getHours()));
  const todayLabel = format(new Date(), 'EEEE, MMMM d, yyyy');
  const resolvedMode = $derived(theme.resolved);

  // ── Queries ───────────────────────────────────────────────────────────────────

  const dashboardOptsStore = writable(
    untrack(() => dashboardSummaryQuery() as CreateQueryOptions<DashboardSummary>),
  );
  const dashboardQ = createQuery<DashboardSummary>(dashboardOptsStore);

  const unreadOptsStore = writable(
    untrack(() => unreadCountQuery() as CreateQueryOptions<{ count: number }>),
  );
  const unreadQ = createQuery<{ count: number }>(unreadOptsStore);

  const approvalsOptsStore = writable(
    untrack(() => approvalsQuery('pending') as CreateQueryOptions<Approval[]>),
  );
  const approvalsQ = createQuery<Approval[]>(approvalsOptsStore);

  const hiredAgentsOptsStore = writable(
    untrack(() => agentsQuery({ hired: true }) as CreateQueryOptions<Agent[]>),
  );
  const hiredAgentsQ = createQuery<Agent[]>(hiredAgentsOptsStore);

  const recentSessionsOptsStore = writable(
    untrack(() => sessionsQuery({ limit: 5 }) as CreateQueryOptions<Session[]>),
  );
  const recentSessionsQ = createQuery<Session[]>(recentSessionsOptsStore);

  const recentTasksOptsStore = writable(
    untrack(() => tasksQuery({ limit: 5 } as never) as CreateQueryOptions<Task[]>),
  );
  const recentTasksQ = createQuery<Task[]>(recentTasksOptsStore);

  // ── Derived data ──────────────────────────────────────────────────────────────

  const dashboard = $derived(($dashboardQ.data ?? null) as DashboardSummary | null);
  const activeSessionCount = $derived(dashboard?.sandboxUsageToday.runningNow ?? 0);
  const unreadCount = $derived($unreadQ.data?.count ?? 0);
  const pendingCount = $derived(($approvalsQ.data ?? []).length);

  const spendTotal = $derived(
    dashboard ? parseFloat(dashboard.spendThisMonth.totalUsd) : 0,
  );
  // Placeholder budget limit — replace with user-level budget when available
  const SPEND_LIMIT = 100;
  const spendPct = $derived(Math.min((spendTotal / SPEND_LIMIT) * 100, 100));

  const hiredAgents = $derived(($hiredAgentsQ.data ?? []) as Agent[]);
  const activeAgentSlugs = $derived(
    new Set((dashboard?.activeAgents ?? []).map((a) => a.agentSlug).filter(Boolean)),
  );
  const activeAgents = $derived(
    hiredAgents.filter((a) => activeAgentSlugs.has(a.slug)).slice(0, 8),
  );
  const extraActiveCount = $derived(
    Math.max(0, (dashboard?.activeAgents ?? []).length - 8),
  );

  // ── Recent activity merge ─────────────────────────────────────────────────────

  interface ActivityItem {
    id: string;
    kind: 'session' | 'task';
    label: string;
    timestamp: string;
    href: string;
  }

  const recentActivity = $derived.by<ActivityItem[]>(() => {
    const sessions = ($recentSessionsQ.data ?? []) as Session[];
    const tasks = ($recentTasksQ.data ?? []) as Task[];

    const sessionItems: ActivityItem[] = sessions.map((s) => ({
      id: `session-${s.id}`,
      kind: 'session' as const,
      label: `${s.agentSlug ?? 'Direct prompt'} session ${s.status}`,
      timestamp: s.startedAt ?? s.insertedAt,
      href: `/sessions/${s.id}`,
    }));

    const taskItems: ActivityItem[] = tasks.map((t) => ({
      id: `task-${t.id}`,
      kind: 'task' as const,
      label: `${t.title} — ${t.status}`,
      timestamp: t.updatedAt,
      href: `/tasks/${t.shortId}`,
    }));

    return [...sessionItems, ...taskItems]
      .sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
      .slice(0, 10);
  });

  const activityLoading = $derived(
    $recentSessionsQ.isLoading || $recentTasksQ.isLoading,
  );
</script>

<div class="hp-root">
  <!-- ── Section 1: Greeting ─────────────────────────────────────────────── -->
  <header class="hp-greeting-row">
    <div class="hp-greeting-text">
      <h1 class="hp-greeting">{greeting}, {USER_NAME}</h1>
      <p class="hp-date">{todayLabel}</p>
    </div>
    <div class="hp-greeting-controls">
      <WorkspaceSwitcher />
      <span class="hp-mode-pill">{resolvedMode === 'dark' ? 'Dark' : 'Light'}</span>
    </div>
  </header>

  <!-- ── Section 2: Stat strip ─────────────────────────────────────────────── -->
  <section class="hp-stat-strip" aria-label="Stats">
    <!-- Active sessions -->
    <button
      class="hp-stat-card"
      onclick={() => goto('/sessions?status=running')}
      aria-label="Active sessions"
    >
      <div class="hp-stat-num-row">
        <span class="hp-stat-num">{activeSessionCount}</span>
        {#if activeSessionCount > 0}
          <StatusDot color="green" pulse={true} />
        {/if}
      </div>
      <span class="hp-stat-label">Active sessions</span>
    </button>

    <!-- Unread notifications -->
    <button
      class="hp-stat-card"
      onclick={() => goto('/notifications?unread=true')}
      aria-label="Unread notifications"
    >
      <span class="hp-stat-num">{unreadCount}</span>
      <span class="hp-stat-label">Unread</span>
    </button>

    <!-- Pending approvals -->
    <button
      class="hp-stat-card"
      class:hp-stat-card--warn={pendingCount > 0}
      onclick={() => goto('/governance?tab=approvals')}
      aria-label="Pending approvals"
    >
      <span class="hp-stat-num" class:hp-stat-num--warn={pendingCount > 0}>
        {pendingCount}
      </span>
      <span class="hp-stat-label">Pending approvals</span>
    </button>

    <!-- This month spend -->
    <button
      class="hp-stat-card"
      onclick={() => goto('/settings/budgets')}
      aria-label="This month spend"
    >
      <span class="hp-stat-num">
        ${spendTotal.toFixed(2)}<span class="hp-stat-limit"> / ${SPEND_LIMIT.toFixed(2)}</span>
      </span>
      <div class="hp-spend-bar" aria-hidden="true">
        <div class="hp-spend-bar__fill" style="width: {spendPct}%"></div>
      </div>
      <span class="hp-stat-label">This month</span>
    </button>
  </section>

  <!-- ── Section 3: Active agents ──────────────────────────────────────────── -->
  <section class="hp-section" aria-label="Active agents">
    <h2 class="hp-section-title">Active agents</h2>
    {#if $hiredAgentsQ.isLoading || $dashboardQ.isLoading}
      <div class="hp-agent-grid">
        {#each Array(3) as _, i (i)}
          <div class="hp-agent-skeleton" aria-hidden="true"></div>
        {/each}
      </div>
    {:else if activeAgents.length === 0}
      <p class="hp-empty">No active agents. Start a session to see live agents here.</p>
    {:else}
      <div class="hp-agent-grid">
        {#each activeAgents as agent (agent.slug)}
          <AgentLiveCard {agent} compact={true} />
        {/each}
      </div>
      {#if extraActiveCount > 0}
        <a class="hp-more-link" href="/agents?hired=true">+ {extraActiveCount} more</a>
      {/if}
    {/if}
  </section>

  <!-- ── Section 4: Quick actions ──────────────────────────────────────────── -->
  <section class="hp-section" aria-label="Quick actions">
    <h2 class="hp-section-title">Quick actions</h2>
    <div class="hp-actions-row">
      <button
        class="hp-action-pill"
        onclick={() => goto('/chat')}
        aria-label="New chat"
      >
        <MessageSquare size={15} aria-hidden="true" />
        <span>New chat</span>
        <Kbd chord="⌘N" />
      </button>
      <button
        class="hp-action-pill"
        onclick={() => goto('/tasks?create=1')}
        aria-label="New task"
      >
        <CheckSquare size={15} aria-hidden="true" />
        <span>New task</span>
        <Kbd chord="⌘T" />
      </button>
      <button
        class="hp-action-pill"
        onclick={() => goto('/docs?create=1')}
        aria-label="New doc"
      >
        <FileText size={15} aria-hidden="true" />
        <span>New doc</span>
        <Kbd chord="⌘D" />
      </button>
      <button
        class="hp-action-pill"
        onclick={() => goto('/sessions?create=1')}
        aria-label="New session"
      >
        <Terminal size={15} aria-hidden="true" />
        <span>New session</span>
        <Kbd chord="⌘S" />
      </button>
    </div>
  </section>

  <!-- ── Section 5: Recent activity ────────────────────────────────────────── -->
  <section class="hp-section" aria-label="Recent activity">
    <h2 class="hp-section-title">Recent activity</h2>
    {#if activityLoading}
      <div class="hp-activity-list">
        {#each Array(4) as _, i (i)}
          <div class="hp-activity-skeleton" aria-hidden="true">
            <div class="hp-skel-icon"></div>
            <div class="hp-skel-text"></div>
            <div class="hp-skel-time"></div>
          </div>
        {/each}
      </div>
    {:else if recentActivity.length === 0}
      <p class="hp-empty">No recent activity. Start using Canopy to see updates here.</p>
    {:else}
      <ul class="hp-activity-list" role="list">
        {#each recentActivity as item (item.id)}
          <li>
            <button
              class="hp-activity-row"
              onclick={() => goto(item.href)}
              aria-label={item.label}
            >
              <span class="hp-activity-icon" aria-hidden="true">
                {#if item.kind === 'session'}
                  <Terminal size={14} />
                {:else}
                  <CheckSquare size={14} />
                {/if}
              </span>
              <span class="hp-activity-label">{item.label}</span>
              <time class="hp-activity-time" datetime={item.timestamp}>
                {formatDistanceToNow(new Date(item.timestamp), { addSuffix: true })}
              </time>
            </button>
          </li>
        {/each}
      </ul>
    {/if}
  </section>
</div>

<style>
  .hp-root {
    flex: 1; display: flex; flex-direction: column;
    gap: 32px; padding: var(--space-10) var(--space-8);
    overflow-y: auto; max-width: 800px; margin: 0 auto; width: 100%;
  }

  /* Greeting */
  .hp-greeting-row { display: flex; align-items: flex-start; justify-content: space-between; gap: var(--space-4); }
  .hp-greeting-text { display: flex; flex-direction: column; gap: var(--space-1); }
  .hp-greeting { font-family: var(--font-serif); font-size: 28px; font-weight: 400; color: var(--fg); margin: 0; line-height: 1.1; letter-spacing: -0.02em; }
  .hp-date { font-size: 13px; color: var(--fg-muted); margin: 0; }
  .hp-greeting-controls { display: flex; align-items: center; gap: var(--space-2); flex-shrink: 0; }
  .hp-mode-pill {
    display: inline-flex; align-items: center; padding: 2px 8px;
    font-size: 11px; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase;
    color: var(--fg-subtle); background: var(--bg-inset);
    border: 1px solid var(--border); border-radius: var(--radius-md); user-select: none;
  }

  /* Stat strip */
  .hp-stat-strip { display: grid; grid-template-columns: repeat(4, 1fr); gap: var(--space-3); }
  .hp-stat-card {
    display: flex; flex-direction: column; gap: var(--space-1);
    padding: var(--space-3); background: var(--bg-inset);
    border: 1px solid var(--border); border-radius: var(--radius-md);
    cursor: pointer; text-align: left; font-family: inherit;
    transition: border-color var(--dur-fast) var(--ease-out);
    min-height: 72px; justify-content: center;
  }
  .hp-stat-card:hover { border-color: var(--cnp-accent); }
  .hp-stat-card--warn { border-color: color-mix(in oklch, var(--signal-warn) 40%, var(--border) 60%); }
  .hp-stat-card--warn:hover { border-color: var(--signal-warn); }
  .hp-stat-num-row { display: flex; align-items: center; gap: var(--space-2); }
  .hp-stat-num { font-family: var(--font-mono); font-size: 28px; font-variant-numeric: tabular-nums; line-height: 1; color: var(--fg); white-space: nowrap; }
  .hp-stat-num--warn { color: var(--signal-warn); }
  .hp-stat-limit { font-size: 13px; color: var(--fg-subtle); }
  .hp-stat-label { font-size: 11px; font-weight: 600; letter-spacing: 0.06em; text-transform: uppercase; color: var(--fg-subtle); }
  .hp-spend-bar { height: 2px; background: var(--border); border-radius: 9999px; overflow: hidden; margin: 2px 0; }
  .hp-spend-bar__fill { height: 100%; background: var(--cnp-accent); border-radius: 9999px; transition: width var(--dur-fast) var(--ease-out); }

  /* Sections */
  .hp-section { display: flex; flex-direction: column; gap: var(--space-3); }
  .hp-section-title { font-size: 11px; font-weight: 600; letter-spacing: 0.06em; text-transform: uppercase; color: var(--fg-subtle); margin: 0; padding-bottom: var(--space-2); border-bottom: 1px solid var(--border); }
  .hp-empty { font-size: 13px; color: var(--fg-subtle); margin: 0; }

  /* Active agents */
  .hp-agent-grid { display: flex; flex-direction: column; gap: var(--space-1); }
  .hp-agent-skeleton { height: 40px; background: var(--bg-inset); border: 1px solid var(--border); border-radius: var(--radius-md); animation: hp-pulse 1.5s ease-in-out infinite; }
  .hp-more-link { font-size: 13px; color: var(--cnp-accent); text-decoration: none; align-self: flex-start; }
  .hp-more-link:hover { text-decoration: underline; }

  /* Quick actions */
  .hp-actions-row { display: grid; grid-template-columns: repeat(4, 1fr); gap: var(--space-2); }
  .hp-action-pill {
    display: flex; align-items: center; justify-content: center; gap: var(--space-2);
    padding: var(--space-3) var(--space-2); background: var(--bg-inset);
    border: 1px solid var(--border); border-radius: var(--radius-md);
    cursor: pointer; font-size: 13px; color: var(--fg);
    transition: border-color var(--dur-fast) var(--ease-out); white-space: nowrap;
  }
  .hp-action-pill:hover { border-color: var(--cnp-accent); }
  .hp-action-pill:focus-visible { outline: 2px solid var(--cnp-accent); outline-offset: 2px; }

  /* Recent activity */
  .hp-activity-list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 1px; }
  .hp-activity-row {
    display: flex; align-items: center; gap: var(--space-3);
    padding: var(--space-2); border: none; background: transparent;
    border-radius: var(--radius-md); cursor: pointer; width: 100%; text-align: left;
    transition: background var(--dur-fast) var(--ease-out); min-height: 34px;
  }
  .hp-activity-row:hover { background: color-mix(in oklch, var(--fg) 4%, transparent 96%); }
  .hp-activity-row:focus-visible { outline: 2px solid var(--cnp-accent); outline-offset: 2px; }
  .hp-activity-icon { display: flex; align-items: center; color: var(--fg-subtle); flex-shrink: 0; }
  .hp-activity-label { font-size: 13px; color: var(--fg); flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .hp-activity-time { font-family: var(--font-mono); font-size: 11px; color: var(--fg-subtle); white-space: nowrap; flex-shrink: 0; }

  /* Skeletons */
  .hp-activity-skeleton { display: flex; align-items: center; gap: var(--space-3); padding: var(--space-2); min-height: 34px; }
  .hp-skel-icon,
  .hp-skel-text,
  .hp-skel-time { background: var(--border); border-radius: var(--radius-sm); animation: hp-pulse 1.5s ease-in-out infinite; }
  .hp-skel-icon { width: 14px; height: 14px; flex-shrink: 0; }
  .hp-skel-text { flex: 1; height: 12px; max-width: 260px; }
  .hp-skel-time { width: 56px; height: 10px; }

  @keyframes hp-pulse { 0%, 100% { opacity: 0.4; } 50% { opacity: 0.8; } }

  @media (prefers-reduced-motion: reduce) {
    .hp-stat-card, .hp-action-pill, .hp-activity-row, .hp-spend-bar__fill { transition: none; }
    .hp-agent-skeleton, .hp-skel-icon, .hp-skel-text, .hp-skel-time { animation: none; }
  }
</style>
