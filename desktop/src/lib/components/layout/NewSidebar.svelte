<!-- src/lib/components/layout/NewSidebar.svelte -->
<script lang="ts">
  import { page } from '$app/stores';
  import { LayoutDashboard, Radio, FolderTree, Users, Bot, FolderKanban, Clock, Settings } from 'lucide-svelte';
  import SidebarSection from './SidebarSection.svelte';
  import { nodesStore } from '$lib/stores/nodes.svelte';
  import { topologyStore } from '$lib/stores/topology.svelte';
  import { signalsFsStore } from '$lib/stores/signals-fs.svelte';
  import { agentsStore } from '$lib/stores/agents.svelte';

  interface Props {
    collapsed?: boolean;
  }

  let { collapsed = false }: Props = $props();

  let currentPath = $derived($page.url.pathname);

  function isActive(href: string): boolean {
    if (href === '/app') return currentPath === '/app';
    return currentPath.startsWith(href);
  }

  // Derive sidebar items from stores
  const nodeItems = $derived(
    nodesStore.sortedNodes.map(n => ({
      id: n.id,
      label: n.name || n.id,
      href: n.href,
      health: n.health,
    }))
  );

  const teamItems = $derived(
    topologyStore.humanPeople.map(p => ({
      id: p.id,
      label: p.name,
      href: `/app/team/${p.id}`,
    }))
  );

  const agentItems = $derived(
    (agentsStore.agents ?? [])
      .filter((a: any) => a.adapter !== 'human' && a.adapter !== 'http')
      .slice(0, 10)
      .map((a: any) => ({
        id: a.id,
        label: a.name,
        href: `/app/agents/${a.id}`,
      }))
  );

  // Section config
  const sections = $derived([
    { label: 'DASHBOARD', href: '/app', icon: LayoutDashboard, collapsible: false, badge: undefined as number | undefined, items: [] as any[] },
    { label: 'SIGNALS', href: '/app/signals', icon: Radio, collapsible: false, badge: signalsFsStore.unreadCount || undefined, items: [] as any[] },
    { label: 'NODES', href: '/app/nodes', icon: FolderTree, collapsible: true, badge: undefined as number | undefined, items: nodeItems },
    { label: 'TEAM', href: '/app/team', icon: Users, collapsible: true, badge: undefined as number | undefined, items: teamItems },
    { label: 'AI AGENTS', href: '/app/agents', icon: Bot, collapsible: true, badge: undefined as number | undefined, items: agentItems },
    { label: 'PROJECTS', href: '/app/projects', icon: FolderKanban, collapsible: false, badge: undefined as number | undefined, items: [] as any[] },
    { label: 'RHYTHM', href: '/app/rhythm', icon: Clock, collapsible: false, badge: undefined as number | undefined, items: [] as any[] },
    { label: 'SYSTEM', href: '/app/system', icon: Settings, collapsible: false, badge: undefined as number | undefined, items: [] as any[] },
  ]);
</script>

<aside class="ns-sidebar" class:collapsed aria-label="Main navigation">
  <nav class="ns-nav">
    {#each sections as section (section.label)}
      {#if section.collapsible && section.items && section.items.length > 0}
        <SidebarSection label={section.label} badge={section.badge}>
          {#snippet children()}
            <a
              class="ns-section-link"
              href={section.href}
              class:active={isActive(section.href)}
              aria-current={isActive(section.href) ? 'page' : undefined}
            >
              <svelte:component this={section.icon} size={14} />
              <span>{section.label}</span>
              {#if section.badge}
                <span class="ns-badge">{section.badge}</span>
              {/if}
            </a>
            {#each section.items as item (item.id)}
              <a
                class="ns-item"
                href={item.href}
                class:active={currentPath === item.href || currentPath.startsWith(item.href + '/')}
                aria-current={currentPath === item.href ? 'page' : undefined}
              >
                {#if 'health' in item}
                  <span class="ns-health-dot" class:green={item.health === 'green'} class:yellow={item.health === 'yellow'} class:red={item.health === 'red'} aria-hidden="true"></span>
                {/if}
                <span class="ns-item-label">{item.label}</span>
              </a>
            {/each}
          {/snippet}
        </SidebarSection>
      {:else}
        <a
          class="ns-link"
          href={section.href}
          class:active={isActive(section.href)}
          aria-current={isActive(section.href) ? 'page' : undefined}
        >
          <svelte:component this={section.icon} size={16} />
          <span>{section.label}</span>
          {#if section.badge}
            <span class="ns-badge">{section.badge}</span>
          {/if}
        </a>
      {/if}
    {/each}
  </nav>
</aside>

<style>
  .ns-sidebar {
    width: 240px;
    min-width: 240px;
    height: 100%;
    display: flex;
    flex-direction: column;
    background: var(--bg-secondary);
    border-right: 1px solid var(--border-default);
    overflow-y: auto;
    overflow-x: hidden;
    transition: width 250ms cubic-bezier(0.4, 0, 0.2, 1), min-width 250ms cubic-bezier(0.4, 0, 0.2, 1);
  }

  .ns-sidebar.collapsed {
    width: 0;
    min-width: 0;
    overflow: hidden;
  }

  .ns-nav {
    display: flex;
    flex-direction: column;
    padding: 8px;
    gap: 2px;
  }

  .ns-link, .ns-section-link {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 8px;
    border-radius: var(--radius-xs);
    color: var(--text-secondary);
    text-decoration: none;
    font-size: 12px;
    font-weight: 500;
    letter-spacing: 0.02em;
    transition: background 100ms ease, color 100ms ease;
    white-space: nowrap;
  }

  .ns-link:hover, .ns-section-link:hover {
    background: var(--bg-surface);
    color: var(--text-primary);
  }

  .ns-link.active, .ns-section-link.active {
    background: var(--bg-elevated);
    color: var(--text-primary);
  }

  .ns-item {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 4px 8px 4px 28px;
    border-radius: var(--radius-xs);
    color: var(--text-tertiary);
    text-decoration: none;
    font-size: 12px;
    transition: background 100ms ease, color 100ms ease;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ns-item:hover {
    background: var(--bg-surface);
    color: var(--text-secondary);
  }

  .ns-item.active {
    background: var(--bg-elevated);
    color: var(--text-primary);
  }

  .ns-item-label {
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ns-health-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--text-tertiary);
    flex-shrink: 0;
  }

  .ns-health-dot.green { background: var(--accent-success); }
  .ns-health-dot.yellow { background: var(--accent-warning); }
  .ns-health-dot.red { background: var(--accent-error); }

  .ns-badge {
    margin-left: auto;
    background: var(--accent-primary);
    color: white;
    font-size: 10px;
    font-weight: 600;
    padding: 1px 6px;
    border-radius: 10px;
    min-width: 18px;
    text-align: center;
  }
</style>
