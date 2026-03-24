<!-- src/lib/components/layout/Sidebar.svelte -->
<script lang="ts">
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { paletteStore } from '$lib/stores/palette.svelte';
  import { agentsStore } from '$lib/stores/agents.svelte';
  import { approvalsStore } from '$lib/stores/approvals.svelte';
  import { hierarchyStore } from '$lib/stores/hierarchy.svelte';
  import WorkspaceSwitcher from './WorkspaceSwitcher.svelte';
  import SidebarNavItem from './SidebarNavItem.svelte';
  import SidebarSection from './SidebarSection.svelte';

  interface User {
    name: string;
    email: string;
    avatarUrl?: string;
  }

  interface Props {
    isCollapsed: boolean;
    onToggle: () => void;
    user?: User | null;
  }

  let { isCollapsed = $bindable(), onToggle, user = null }: Props = $props();

  let currentPath = $derived($page.url.pathname as string);

  // Division display config (fallback grouping when no real teams exist)
  const DIVISION_META: Record<string, { emoji: string; label: string; order: number }> = {
    core:        { emoji: '🧭', label: 'Core',        order: 0 },
    foundations:  { emoji: '🔍', label: 'Foundations',  order: 1 },
    marketing:   { emoji: '📣', label: 'Marketing',   order: 2 },
    nurture:     { emoji: '✉️', label: 'Nurture',     order: 3 },
    sales:       { emoji: '💰', label: 'Sales',       order: 4 },
    launch:      { emoji: '🚀', label: 'Launch',      order: 5 },
    scale:       { emoji: '📈', label: 'Scale',       order: 6 },
  };

  function isActive(href: string): boolean {
    if (href === '/app') return currentPath === '/app';
    return currentPath.startsWith(href);
  }

  function initials(name: string): string {
    return name
      .split(' ')
      .slice(0, 2)
      .map((w) => w[0])
      .join('')
      .toUpperCase();
  }

  // Inbox badge: approvals + any future notification count
  const inboxBadge = $derived(approvalsStore.pendingCount || undefined);

  // SVG icon paths
  const ICONS = {
    dashboard:    'M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-4 0a1 1 0 01-1-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 01-1 1m-2 0h2',
    inbox:        'M2.25 13.5h3.86a2.25 2.25 0 012.012 1.244l.256.512a2.25 2.25 0 002.013 1.244h3.218a2.25 2.25 0 002.013-1.244l.256-.512a2.25 2.25 0 012.013-1.244h3.859m-19.5.338V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18v-4.162c0-.224-.034-.447-.1-.661L19.24 5.338a2.25 2.25 0 00-2.15-1.588H6.911a2.25 2.25 0 00-2.15 1.588L2.35 13.177a2.25 2.25 0 00-.1.661z',
    office:       'M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18M9 6.75h1.5m-1.5 3h1.5m-1.5 3h1.5m3-6H15m-1.5 3H15m-1.5 3H15M9 21v-3.375c0-.621.504-1.125 1.125-1.125h3.75c.621 0 1.125.504 1.125 1.125V21',
    issues:       'M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z',
    goals:        'M3 3v1.5M3 21v-6m0 0l2.77-.693a9 9 0 016.208.682l.108.054a9 9 0 006.086.71l3.114-.732a48.524 48.524 0 01-.005-10.499l-3.11.732a9 9 0 01-6.085-.711l-.108-.054a9 9 0 00-6.208-.682L3 4.5M3 15V4.5',
    documents:    'M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z',
    activity:     'M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z',
    sessions:     'M20.25 8.511c.884.284 1.5 1.128 1.5 2.097v4.286c0 1.136-.847 2.1-1.98 2.193-.34.027-.68.052-1.02.072v3.091l-3-3c-1.354 0-2.694-.055-4.02-.163a2.115 2.115 0 01-.825-.242m9.345-8.334a2.126 2.126 0 00-.476-.095 48.64 48.64 0 00-8.048 0c-1.131.094-1.976 1.057-1.976 2.192v4.286c0 .837.46 1.58 1.155 1.951m9.345-8.334V6.637c0-1.621-1.152-3.026-2.76-3.235A48.455 48.455 0 0011.25 3c-2.115 0-4.198.137-6.24.402-1.608.209-2.76 1.614-2.76 3.235v6.226c0 1.621 1.152 3.026 2.76 3.235.577.075 1.157.14 1.74.194V21l4.155-4.155',
    costs:        'M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 013 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 00-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 01-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 003 15h-.75M15 10.5a3 3 0 11-6 0 3 3 0 016 0zm3 0h.008v.008H18V10.5zm-12 0h.008v.008H6V10.5z',
    memory:       'M20.25 6.375c0 2.278-3.694 4.125-8.25 4.125S3.75 8.653 3.75 6.375m16.5 0c0-2.278-3.694-4.125-8.25-4.125S3.75 4.097 3.75 6.375m16.5 0v11.25c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125V6.375m16.5 0v3.75m-16.5-3.75v3.75m16.5 0v3.75C20.25 16.153 16.556 18 12 18s-8.25-1.847-8.25-4.125v-3.75m16.5 0c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125',
    skills:       'M4.26 10.147a60.438 60.438 0 00-.491 6.347A48.62 48.62 0 0112 20.904a48.62 48.62 0 018.232-4.41 60.46 60.46 0 00-.491-6.347m-15.482 0a50.636 50.636 0 00-2.658-.813A59.906 59.906 0 0112 3.493a59.903 59.903 0 0110.399 5.84c-.896.248-1.783.52-2.658.814m-15.482 0A50.717 50.717 0 0112 13.489a50.702 50.702 0 017.74-3.342M6.75 15a.75.75 0 100-1.5.75.75 0 000 1.5zm0 0v-3.675A55.378 55.378 0 0112 8.443m-7.007 11.55A5.981 5.981 0 006.75 15.75v-1.5',
    schedules:    'M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z',
    workflows:    'M3.75 12h16.5m-16.5 0a1.5 1.5 0 01-1.5-1.5V6a1.5 1.5 0 011.5-1.5h16.5a1.5 1.5 0 011.5 1.5v4.5a1.5 1.5 0 01-1.5 1.5m-16.5 0a1.5 1.5 0 00-1.5 1.5V18a1.5 1.5 0 001.5 1.5h16.5a1.5 1.5 0 001.5-1.5v-4.5a1.5 1.5 0 00-1.5-1.5',
    alerts:       'M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75v-.7V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0',
    integrations: 'M13.5 16.875h3.375m0 0h3.375m-3.375 0V13.5m0 3.375v3.375M6 10.5h2.25a2.25 2.25 0 002.25-2.25V6a2.25 2.25 0 00-2.25-2.25H6A2.25 2.25 0 003.75 6v2.25A2.25 2.25 0 006 10.5zm0 9.75h2.25A2.25 2.25 0 0010.5 18v-2.25a2.25 2.25 0 00-2.25-2.25H6a2.25 2.25 0 00-2.25 2.25V18A2.25 2.25 0 006 20.25zm9.75-9.75H18a2.25 2.25 0 002.25-2.25V6A2.25 2.25 0 0018 3.75h-2.25A2.25 2.25 0 0013.5 6v2.25a2.25 2.25 0 002.25 2.25z',
    users:        'M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z',
    config:       'M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.325.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.241-.438.613-.43.992a7.723 7.723 0 010 .255c-.008.378.137.75.43.991l1.004.827c.424.35.534.955.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.47 6.47 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.281c-.09.543-.56.94-1.11.94h-2.594c-.55 0-1.019-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.991a6.932 6.932 0 010-.255c.007-.38-.138-.751-.43-.992l-1.004-.827a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.086.22-.128.332-.183.582-.495.644-.869l.214-1.28z M15 12a3 3 0 11-6 0 3 3 0 016 0z',
    library:      'M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25',
    workspaces:   'M20.25 6.375c0 2.278-3.694 4.125-8.25 4.125S3.75 8.653 3.75 6.375m16.5 0c0-2.278-3.694-4.125-8.25-4.125S3.75 4.097 3.75 6.375m16.5 0v11.25c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125V6.375m16.5 0v3.75m-16.5-3.75v3.75m16.5 0v3.75C20.25 16.153 16.556 18 12 18s-8.25-1.847-8.25-4.125v-3.75m16.5 0c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125',
    secrets:      'M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z',
    hierarchy:    'M3 6l3-3 3 3M6 3v13M21 6l-3-3-3 3M18 3v13M3 21h18M3 17h6M15 17h6',
    datasets:     'M20.25 6.375c0 2.278-3.694 4.125-8.25 4.125S3.75 8.653 3.75 6.375m16.5 0c0-2.278-3.694-4.125-8.25-4.125S3.75 4.097 3.75 6.375m16.5 0v3.75M3.75 6.375v3.75m16.5 0c0 2.278-3.694 4.125-8.25 4.125S3.75 12.403 3.75 10.125m16.5 0v3.75C20.25 16.153 16.556 18 12 18s-8.25-1.847-8.25-4.125v-3.75',
    workProducts: 'M11.35 3.836c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15a2.251 2.251 0 012.15 1.586m-5.8 0c-.376.023-.75.05-1.124.08C9.095 4.01 8.25 4.973 8.25 6.108V8.25m8.9-4.414c.376.023.75.05 1.124.08 1.131.094 1.976 1.057 1.976 2.192V16.5A2.25 2.25 0 0118 18.75h-2.25m-7.5-10.5H4.875c-.621 0-1.125.504-1.125 1.125v11.25c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V18.75m-7.5-10.5h6.375c.621 0 1.125.504 1.125 1.125v9.375m-8.25-3l1.5 1.5 3-3.75',
    chat:         'M8.625 12a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 01-2.555-.337A5.972 5.972 0 015.41 20.97a5.969 5.969 0 01-.474-.065 4.48 4.48 0 00.978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25z',
    agent:        'M17.982 18.725A7.488 7.488 0 0012 15.75a7.488 7.488 0 00-5.982 2.975m11.963 0a9 9 0 10-11.963 0m11.963 0A8.966 8.966 0 0112 21a8.966 8.966 0 01-5.982-2.275M15 9.75a3 3 0 11-6 0 3 3 0 016 0z',
    terminal:     'M6.75 7.5l3 2.25-3 2.25m4.5 0h3m-9 8.25h13.5A2.25 2.25 0 0021 18V6a2.25 2.25 0 00-2.25-2.25H5.25A2.25 2.25 0 003 6v12a2.25 2.25 0 002.25 2.25z',
    hamburger:    'M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5',
    close:        'M6 18L18 6M6 6l12 12',
    search:       'M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 15.803a7.5 7.5 0 0010.607 10.607z',
    plus:         'M12 4.5v15m7.5-7.5h-15',
  } as const;
</script>

<aside class="sb-sidebar" class:collapsed={isCollapsed} aria-label="Main navigation">
  <!-- Toggle button -->
  <div class="sb-toggle-row">
    <button
      class="sb-toggle"
      onclick={onToggle}
      aria-label={isCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
      title={isCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
    >
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path d={isCollapsed ? ICONS.hamburger : ICONS.close} />
      </svg>
    </button>
  </div>

  {#if !isCollapsed}
    <!-- Workspace Switcher -->
    <div class="sb-workspace">
      <WorkspaceSwitcher />
    </div>

    <!-- Search -->
    <div class="sb-search-row">
      <button
        class="sb-search"
        onclick={() => paletteStore.toggle()}
        aria-label="Open command palette"
      >
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d={ICONS.search} />
        </svg>
        <span class="sb-search-label">Search…</span>
        <span class="sb-search-hint">⌘K</span>
      </button>
    </div>
  {/if}

  <!-- Scrollable nav area -->
  <nav class="sb-nav" aria-label="Sidebar navigation">
    <!-- ═══ DAILY DRIVERS (no label, always visible) ═══ -->
    <div class="sb-core">
      <SidebarNavItem href="/app" label="Home" icon={ICONS.dashboard} shortcut={!isCollapsed ? '⌘1' : undefined} active={isActive('/app')} />
      <SidebarNavItem href="/app/inbox" label="Inbox" icon={ICONS.inbox} shortcut={!isCollapsed ? '⌘2' : undefined} badge={inboxBadge} active={isActive('/app/inbox')} />
      <SidebarNavItem href="/app/office" label="Office" icon={ICONS.office} shortcut={!isCollapsed ? '⌘3' : undefined} active={isActive('/app/office')} />
    </div>

    {#if !isCollapsed}
      <div class="sb-divider" aria-hidden="true"></div>

      <!-- ═══ WORK — What you're building ═══ -->
      <SidebarSection label="Work">
        <SidebarNavItem href="/app/projects" label="Projects" icon={ICONS.workspaces} active={isActive('/app/projects')} />
        <SidebarNavItem href="/app/goals" label="Goals" icon={ICONS.goals} active={isActive('/app/goals')} />
        <SidebarNavItem href="/app/issues" label="Issues" icon={ICONS.issues} active={isActive('/app/issues')} />
        <SidebarNavItem href="/app/documents" label="Documents" icon={ICONS.documents} active={isActive('/app/documents')} />
      </SidebarSection>

      <div class="sb-divider" aria-hidden="true"></div>

      <!-- ═══ AGENTS — Organized by Division → Department → Team → Agent ═══ -->
      <SidebarSection label="Agents" badge={agentsStore.agents.length || undefined}>
        {#if agentsStore.agents.length === 0}
          <div class="sb-empty">No agents deployed</div>
        {:else}
          <!-- Full hierarchy tree: Division > Department > Team > Agent -->
          {#if hierarchyStore.tree && hierarchyStore.tree.divisions.length > 0}
            {@const tree = hierarchyStore.tree}
            {@const assignedAgentIds = new Set(
              tree.divisions
                .flatMap(d => d.departments ?? [])
                .flatMap(dept => dept.teams ?? [])
                .flatMap(t => (t.agents ?? []).map(a => a.id))
            )}
            {#each tree.divisions as division (division.id)}
              {@const divMeta = DIVISION_META[division.slug] ?? DIVISION_META[division.name?.toLowerCase()]}
              {@const divAgentCount = (division.departments ?? [])
                .flatMap(dept => dept.teams ?? [])
                .flatMap(t => t.agents ?? []).length}
              {#if divAgentCount > 0}
                <SidebarSection
                  label="{divMeta?.emoji ?? '📁'} {division.name}"
                  badge={divAgentCount}
                  defaultOpen={divAgentCount <= 8}
                >
                  {#each (division.departments ?? []) as dept (dept.id)}
                    {@const deptAgentCount = (dept.teams ?? []).flatMap(t => t.agents ?? []).length}
                    {#if deptAgentCount > 0}
                      {#if (dept.teams ?? []).length === 1}
                        <!-- Single team in department — show agents directly under dept name -->
                        {@const team = dept.teams[0]}
                        <SidebarSection label={dept.name} badge={deptAgentCount} defaultOpen={true}>
                          {#each (team.agents ?? []) as agent (agent.id)}
                            <SidebarNavItem
                              href="/app/agents/{agent.id}"
                              label={agent.display_name || agent.name}
                              icon={ICONS.agent}
                              active={isActive(`/app/agents/${agent.id}`)}
                            />
                          {/each}
                        </SidebarSection>
                      {:else}
                        <!-- Multiple teams — show dept > team > agents -->
                        <SidebarSection label={dept.name} badge={deptAgentCount} defaultOpen={false}>
                          {#each (dept.teams ?? []) as team (team.id)}
                            {#if (team.agents ?? []).length > 0}
                              <SidebarSection label={team.name} badge={team.agents.length} defaultOpen={true}>
                                {#each (team.agents ?? []) as agent (agent.id)}
                                  <SidebarNavItem
                                    href="/app/agents/{agent.id}"
                                    label={agent.display_name || agent.name}
                                    icon={ICONS.agent}
                                    active={isActive(`/app/agents/${agent.id}`)}
                                  />
                                {/each}
                              </SidebarSection>
                            {/if}
                          {/each}
                        </SidebarSection>
                      {/if}
                    {/if}
                  {/each}
                </SidebarSection>
              {/if}
            {/each}

            <!-- Unassigned agents (not in any team in the tree) -->
            {@const unassigned = agentsStore.agents.filter(a => !assignedAgentIds.has(a.id))}
            {#if unassigned.length > 0}
              <SidebarSection label="Unassigned" badge={unassigned.length} defaultOpen={false}>
                {#each unassigned.slice(0, 10) as agent (agent.id)}
                  <SidebarNavItem
                    href="/app/agents/{agent.id}"
                    label={agent.display_name || agent.name}
                    icon={ICONS.agent}
                    active={isActive(`/app/agents/${agent.id}`)}
                  />
                {/each}
              </SidebarSection>
            {/if}

          <!-- Fallback: group by config.division when no tree data -->
          {:else}
            {@const grouped = (() => {
              const groups = new Map<string, import('$api/types').CanopyAgent[]>();
              for (const agent of agentsStore.agents) {
                const div = (agent.config?.division as string) || 'general';
                const list = groups.get(div) ?? [];
                list.push(agent);
                groups.set(div, list);
              }
              return [...groups.entries()]
                .sort(([a], [b]) => (DIVISION_META[a]?.order ?? 99) - (DIVISION_META[b]?.order ?? 99));
            })()}
            {#each grouped as [divKey, divAgents] (divKey)}
              {@const meta = DIVISION_META[divKey]}
              <SidebarSection label="{meta?.emoji ?? '📁'} {meta?.label ?? divKey}" badge={divAgents.length} defaultOpen={true}>
                {#each divAgents as agent (agent.id)}
                  <SidebarNavItem
                    href="/app/agents/{agent.id}"
                    label={agent.display_name || agent.name}
                    icon={ICONS.agent}
                    active={isActive(`/app/agents/${agent.id}`)}
                  />
                {/each}
              </SidebarSection>
            {/each}
          {/if}

          <SidebarNavItem href="/app/agents" label="View all ({agentsStore.agents.length})" icon={ICONS.agent} active={currentPath === '/app/agents'} />
        {/if}
        <button class="sb-inline-action" onclick={() => goto('/app/agents?hire=1')}>
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d={ICONS.plus} />
          </svg>
          Deploy Agent
        </button>
      </SidebarSection>

      <div class="sb-divider" aria-hidden="true"></div>

      <!-- ═══ CHAT — Talk to agents ═══ -->
      <SidebarNavItem href="/app/chat" label="Chat" icon={ICONS.chat} active={isActive('/app/chat')} />

      <div class="sb-divider" aria-hidden="true"></div>

      <!-- ═══ DATA — What agents know & produce ═══ -->
      <SidebarSection label="Data">
        <SidebarNavItem href="/app/memory" label="Memory" icon={ICONS.memory} active={isActive('/app/memory')} />
        <SidebarNavItem href="/app/datasets" label="Datasets" icon={ICONS.datasets} active={isActive('/app/datasets')} />
        <SidebarNavItem href="/app/work-products" label="Work Products" icon={ICONS.workProducts} active={isActive('/app/work-products')} />
      </SidebarSection>

      <div class="sb-divider" aria-hidden="true"></div>

      <!-- ═══ OBSERVE — How things are going ═══ -->
      <SidebarSection label="Observe">
        <SidebarNavItem href="/app/activity" label="Activity" icon={ICONS.activity} active={isActive('/app/activity')} />
        <SidebarNavItem href="/app/sessions" label="Sessions" icon={ICONS.sessions} active={isActive('/app/sessions')} />
        <SidebarNavItem href="/app/costs" label="Costs" icon={ICONS.costs} active={isActive('/app/costs')} />
      </SidebarSection>

      <div class="sb-divider" aria-hidden="true"></div>

      <!-- ═══ AUTOMATE — Make things happen automatically ═══ -->
      <SidebarSection label="Automate">
        <SidebarNavItem href="/app/workflows" label="Workflows" icon={ICONS.workflows} active={isActive('/app/workflows')} />
        <SidebarNavItem href="/app/schedules" label="Schedules" icon={ICONS.schedules} active={isActive('/app/schedules')} />
        <SidebarNavItem href="/app/alerts" label="Alerts" icon={ICONS.alerts} active={isActive('/app/alerts')} />
      </SidebarSection>

      <div class="sb-divider" aria-hidden="true"></div>

      <!-- ═══ LIBRARY — Templates, skills, marketplace ═══ -->
      <SidebarNavItem href="/app/library" label="Library" icon={ICONS.library} active={isActive('/app/library')} />

      <div class="sb-divider" aria-hidden="true"></div>

      <!-- ═══ SYSTEM (collapsed by default) — Org, users, config ═══ -->
      <SidebarSection label="System" defaultOpen={false}>
        <SidebarNavItem href="/app/hierarchy" label="Organization" icon={ICONS.hierarchy} active={isActive('/app/hierarchy') || isActive('/app/organizations') || isActive('/app/divisions') || isActive('/app/departments') || isActive('/app/teams')} />
        <SidebarNavItem href="/app/users" label="Users & Access" icon={ICONS.users} active={isActive('/app/users') || isActive('/app/access')} />
        <SidebarNavItem href="/app/integrations" label="Integrations" icon={ICONS.integrations} active={isActive('/app/integrations') || isActive('/app/webhooks') || isActive('/app/plugins')} />
        <SidebarNavItem href="/app/secrets" label="Secrets" icon={ICONS.secrets} active={isActive('/app/secrets')} />
        <SidebarNavItem href="/app/environment" label="Environment" icon={ICONS.terminal} active={isActive('/app/environment')} />
        <SidebarNavItem href="/app/config" label="Config" icon={ICONS.config} active={isActive('/app/config') || isActive('/app/gateways') || isActive('/app/execution-workspaces') || isActive('/app/audit')} />
      </SidebarSection>
    {:else}
      <!-- Collapsed icon-only mode -->
      <div class="sb-collapsed-icons">
        <SidebarNavItem href="/app/projects" label="Projects" icon={ICONS.workspaces} active={isActive('/app/projects')} />
        <SidebarNavItem href="/app/agents" label="Agents" icon={ICONS.agent} active={isActive('/app/agents')} />
        <SidebarNavItem href="/app/chat" label="Chat" icon={ICONS.chat} active={isActive('/app/chat')} />
        <SidebarNavItem href="/app/activity" label="Activity" icon={ICONS.activity} active={isActive('/app/activity')} />
        <SidebarNavItem href="/app/costs" label="Costs" icon={ICONS.costs} active={isActive('/app/costs')} />
        <SidebarNavItem href="/app/library" label="Library" icon={ICONS.library} active={isActive('/app/library')} />
      </div>
    {/if}
  </nav>

  <!-- Bottom pinned -->
  <div class="sb-bottom">
    <div class="sb-divider" aria-hidden="true"></div>
    <SidebarNavItem href="/app/terminal" label="Terminal" icon={ICONS.terminal} shortcut={!isCollapsed ? '⌘T' : undefined} active={isActive('/app/terminal')} />
    <SidebarNavItem href="/app/settings" label="Settings" icon={ICONS.config} shortcut={!isCollapsed ? '⌘,' : undefined} active={isActive('/app/settings')} />

    {#if user}
      <button type="button" class="sb-user" title="{user.name} — {user.email}" aria-label="Open profile" onclick={() => goto('/app/settings')}>
        <div class="sb-avatar" aria-hidden="true">
          {#if user.avatarUrl}
            <img src={user.avatarUrl} alt="" class="sb-avatar-img" />
          {:else}
            <span class="sb-avatar-initials">{initials(user.name)}</span>
          {/if}
        </div>
        {#if !isCollapsed}
          <div class="sb-user-info">
            <span class="sb-user-name">{user.name}</span>
            <span class="sb-user-email">{user.email}</span>
          </div>
        {/if}
      </button>
    {/if}
  </div>
</aside>

<style>
  .sb-sidebar {
    display: flex;
    flex-direction: column;
    width: var(--sidebar-expanded-width);
    height: 100dvh;
    background: var(--bg-primary);
    border-right: 1px solid var(--border-default);
    flex-shrink: 0;
    transition: var(--sidebar-transition);
    overflow: hidden;
    position: relative;
    z-index: 100;
  }

  .sb-sidebar.collapsed {
    width: var(--sidebar-collapsed-width);
  }

  /* Toggle row */
  .sb-toggle-row {
    display: flex;
    align-items: center;
    padding: 38px 8px 4px;
    flex-shrink: 0;
  }

  .sb-toggle {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    padding: 0;
    border: none;
    background: transparent;
    color: var(--text-tertiary);
    cursor: pointer;
    border-radius: var(--radius-xs);
    transition: background 120ms ease, color 120ms ease;
    flex-shrink: 0;
  }

  .sb-toggle:hover {
    background: var(--bg-surface);
    color: var(--text-primary);
  }

  /* Workspace */
  .sb-workspace {
    padding: 4px 8px;
    flex-shrink: 0;
  }

  /* Search */
  .sb-search-row {
    padding: 4px 8px;
    flex-shrink: 0;
  }

  .sb-search {
    display: flex;
    align-items: center;
    gap: 7px;
    width: 100%;
    height: 28px;
    padding: 0 8px;
    border: 1px solid var(--border-default);
    background: var(--bg-surface);
    color: var(--text-tertiary);
    cursor: pointer;
    border-radius: var(--radius-xs);
    font-size: 12px;
    text-align: left;
    transition: border-color 120ms ease, background 120ms ease, color 120ms ease;
  }

  .sb-search:hover {
    border-color: var(--border-hover);
    background: var(--bg-elevated);
    color: var(--text-secondary);
  }

  .sb-search-label {
    flex: 1;
  }

  .sb-search-hint {
    font-size: 10px;
    color: var(--text-muted);
  }

  /* Nav */
  .sb-nav {
    flex: 1;
    overflow-y: auto;
    padding: 4px 8px;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .sb-nav::-webkit-scrollbar {
    width: 4px;
  }

  .sb-nav::-webkit-scrollbar-track {
    background: transparent;
  }

  .sb-nav::-webkit-scrollbar-thumb {
    background: var(--border-default);
    border-radius: 2px;
  }

  .sb-core {
    display: flex;
    flex-direction: column;
    gap: 1px;
    padding-bottom: 2px;
  }

  .sb-collapsed-icons {
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .sb-divider {
    height: 1px;
    background: var(--border-default);
    margin: 4px 0;
    flex-shrink: 0;
  }

  .sb-empty {
    padding: 6px 12px;
    font-size: 12px;
    color: var(--text-muted);
  }

  .sb-inline-action {
    display: flex;
    align-items: center;
    gap: 6px;
    width: 100%;
    height: 28px;
    padding: 0 12px;
    border: none;
    background: transparent;
    color: var(--text-tertiary);
    cursor: pointer;
    border-radius: var(--radius-xs);
    font-size: 12px;
    text-align: left;
    transition: background 100ms ease, color 100ms ease;
  }

  .sb-inline-action:hover {
    background: var(--bg-surface);
    color: var(--text-secondary);
  }

  /* Bottom */
  .sb-bottom {
    flex-shrink: 0;
    padding: 0 8px 8px;
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .sb-user {
    display: flex;
    align-items: center;
    gap: 8px;
    height: 36px;
    padding: 0 8px;
    border-radius: var(--radius-xs);
    margin-top: 4px;
    cursor: pointer;
    transition: background 120ms ease;
    background: none;
    border: none;
    text-align: left;
    width: 100%;
    font: inherit;
    color: inherit;
  }

  .sb-user:hover {
    background: var(--bg-surface);
  }

  .sb-avatar {
    width: 24px;
    height: 24px;
    border-radius: 50%;
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    flex-shrink: 0;
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .sb-avatar-img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .sb-avatar-initials {
    font-size: 9px;
    font-weight: 700;
    color: var(--text-secondary);
    letter-spacing: 0.02em;
  }

  .sb-user-info {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
  }

  .sb-user-name {
    font-size: 12px;
    font-weight: 500;
    color: var(--text-primary);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .sb-user-email {
    font-size: 10px;
    color: var(--text-tertiary);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  /* Collapsed mode: hide labels in nav items */
  .sb-sidebar.collapsed :global(.sni-label),
  .sb-sidebar.collapsed :global(.sni-shortcut),
  .sb-sidebar.collapsed :global(.sni-badge),
  .sb-sidebar.collapsed :global(.sni-right) {
    display: none;
  }

  .sb-sidebar.collapsed :global(.sni-item) {
    justify-content: center;
    padding: 0;
    width: 36px;
    margin: 0 auto;
  }
</style>
