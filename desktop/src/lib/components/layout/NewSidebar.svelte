<!-- src/lib/components/layout/NewSidebar.svelte -->
<script lang="ts">
  import { page } from "$app/stores";
  import {
    Activity,
    Blocks,
    Bot,
    CalendarClock,
    Clock,
    FolderKanban,
    FolderTree,
    Inbox,
    LayoutDashboard,
    Library,
    MessageSquare,
    Plug,
    Plus,
    Puzzle,
    Radio,
    Settings,
    Terminal,
    Users,
  } from "lucide-svelte";
  import SidebarSection from "./SidebarSection.svelte";
  import { nodesStore } from "$lib/stores/nodes.svelte";
  import { topologyStore } from "$lib/stores/topology.svelte";
  import { signalsFsStore } from "$lib/stores/signals-fs.svelte";
  import { agentsStore } from "$lib/stores/agents.svelte";
  import { inboxStore } from "$lib/stores/inbox.svelte";
  import { sidebarStore, type SidebarModuleId } from "$lib/stores/sidebar.svelte";

  interface Props {
    collapsed?: boolean;
    /** Mobile overlay mode: when defined, controls absolute overlay visibility */
    visible?: boolean;
  }

  let { collapsed = false, visible = undefined }: Props = $props();

  // Mobile mode: visible prop is set; use absolute overlay instead of width collapse.
  let mobileMode = $derived(visible !== undefined);
  let mobileOpen = $derived(mobileMode && visible === true);

  let currentPath = $derived($page.url.pathname);

  function isActive(href: string): boolean {
    if (href === "/app") return currentPath === "/app";
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
      .filter((a: any) => a.adapter !== "human" && a.adapter !== "http")
      .slice(0, 10)
      .map((a: any) => ({
        id: a.id,
        label: a.name,
        href: `/app/agents/${a.id}`,
        status: (a.status ?? "idle") as "idle" | "working" | "running" | "error" | "paused",
      }))
  );

  // Live agent count: only truly active (running / working), not idle
  const liveAgentCount = $derived(
    (agentsStore.agents ?? []).filter(
      (a) => a.status === "running" || a.status === "working"
    ).length
  );

  // Project color palette — cycle through for project item dots
  const PROJECT_COLORS = ["#e879f9", "#60a5fa", "#34d399", "#a78bfa", "#fb923c", "#f472b6"];

  sidebarStore.load();

  type SidebarItem = {
    id: SidebarModuleId | string;
    label: string;
    href: string;
    icon?: typeof Blocks;
    health?: string;
    status?: "idle" | "working" | "running" | "error" | "paused";
  };

  type SidebarEntry = {
    id: SidebarModuleId;
    label: string;
    href: string;
    icon: typeof Blocks;
    collapsible: boolean;
    badge?: number;
    items: SidebarItem[];
  };

  function visibleItems(items: SidebarItem[]): SidebarItem[] {
    return items.filter((item) => {
      if (typeof item.id !== "string") return true;
      return !SIDEBAR_CONFIG_IDS.has(item.id) || sidebarStore.isVisible(item.id as SidebarModuleId);
    });
  }

  const SIDEBAR_CONFIG_IDS = new Set<string>([
    "dashboard", "inbox", "office", "workbench", "execution", "terminal", "chat",
    "sessions", "rhythm", "signals", "nodes", "library", "templates", "skills",
    "projects", "team", "agents", "automation", "schedules", "integrations",
    "activity", "system",
  ]);

  const executionItems: SidebarItem[] = [
    { id: "workbench", label: "Workbench", href: "/app/workbench", icon: Blocks },
    { id: "terminal", label: "Terminal", href: "/app/terminal", icon: Terminal },
    { id: "chat", label: "Chat", href: "/app/chat", icon: MessageSquare },
    { id: "sessions", label: "Sessions", href: "/app/sessions", icon: Activity },
  ];

  const libraryItems: SidebarItem[] = [
    { id: "templates", label: "Templates", href: "/app/templates", icon: Library },
    { id: "skills", label: "Skills", href: "/app/skills", icon: Puzzle },
  ];

  const automationItems: SidebarItem[] = [
    { id: "schedules", label: "Schedules", href: "/app/schedules", icon: CalendarClock },
    { id: "integrations", label: "Integrations", href: "/app/integrations", icon: Plug },
    { id: "activity", label: "Activity", href: "/app/activity", icon: Activity },
  ];

  // Section config — workflow order: overview → inbox → execution → incoming → reference → people → automation → settings
  const sections = $derived.by<SidebarEntry[]>(() => {
    const entries: SidebarEntry[] = [
      { id: "dashboard", label: "DASHBOARD", href: "/app", icon: LayoutDashboard, collapsible: false, badge: liveAgentCount > 0 ? liveAgentCount : undefined, items: [] },
      { id: "inbox", label: "INBOX", href: "/app/inbox", icon: Inbox, collapsible: false, badge: inboxStore.unreadCount > 0 ? inboxStore.unreadCount : undefined, items: [] },
      { id: "office", label: "OFFICE", href: "/app/office", icon: FolderTree, collapsible: false, items: [] },
      { id: "workbench", label: "WORKBENCH", href: "/app/workbench", icon: Blocks, collapsible: false, items: [] },
      { id: "execution", label: "EXECUTION", href: "/app/workbench", icon: Blocks, collapsible: true, items: visibleItems(executionItems) },
      { id: "rhythm", label: "RHYTHM", href: "/app/rhythm", icon: Clock, collapsible: false, items: [] },
      { id: "signals", label: "SIGNALS", href: "/app/signals", icon: Radio, collapsible: false, badge: signalsFsStore.unreadCount || undefined, items: [] },
      { id: "nodes", label: "NODES", href: "/app/nodes", icon: FolderTree, collapsible: true, items: nodeItems },
      { id: "library", label: "LIBRARY", href: "/app/templates", icon: Library, collapsible: true, items: visibleItems(libraryItems) },
      { id: "projects", label: "PROJECTS", href: "/app/projects", icon: FolderKanban, collapsible: false, items: [] },
      { id: "team", label: "TEAM", href: "/app/team", icon: Users, collapsible: true, items: teamItems },
      { id: "agents", label: "AI AGENTS", href: "/app/agents", icon: Bot, collapsible: true, items: agentItems },
      { id: "automation", label: "AUTOMATION", href: "/app/schedules", icon: CalendarClock, collapsible: true, items: visibleItems(automationItems) },
      { id: "system", label: "SYSTEM", href: "/app/system", icon: Settings, collapsible: false, items: [] },
    ];

    return entries.filter((entry) => {
      if (!sidebarStore.isVisible(entry.id)) return false;
      if (!entry.collapsible) return true;
      return entry.items.length > 0;
    });
  });
</script>

<aside
  class="ns-sidebar"
  class:collapsed={!mobileMode && collapsed}
  class:mobile={mobileMode}
  class:mobile-open={mobileOpen}
  aria-label="Main navigation"
>
  <div class="ns-top-actions">
    <a href="/app/signals" class="ns-new-signal" title="Ingest a new signal">
      <Plus size={14} aria-hidden="true" />
      <span>New Signal</span>
    </a>
  </div>

  <nav class="ns-nav">
    {#each sections as section (section.label)}
      {#if section.collapsible && section.items && section.items.length > 0}
        <SidebarSection label={section.label} badge={section.badge}>
          {#snippet children()}
            {@const Icon = section.icon}
            <a
              class="ns-section-link"
              href={section.href}
              class:active={isActive(section.href)}
              aria-current={isActive(section.href) ? "page" : undefined}
            >
              <Icon size={14} />
              <span>{section.label}</span>
              {#if section.badge}
                <span class="ns-badge">{section.badge}</span>
              {/if}
            </a>
            {#each section.items as item, i (item.id)}
              <a
                class="ns-item"
                href={item.href}
                class:active={currentPath === item.href || currentPath.startsWith(item.href + "/")}
                aria-current={currentPath === item.href ? "page" : undefined}
              >
                {#if "icon" in item}
                  {@const ItemIcon = item.icon}
                  <ItemIcon size={13} aria-hidden="true" />
                {:else if "health" in item}
                  <span
                    class="ns-health-dot"
                    class:green={item.health === "green" || item.health === "healthy"}
                    class:yellow={item.health === "yellow" || item.health === "stale"}
                    class:red={item.health === "red" || item.health === "error"}
                    aria-hidden="true"
                  ></span>
                {:else if "status" in item}
                  <span
                    class="ns-status-dot"
                    class:working={item.status === "working" || item.status === "running"}
                    class:error={item.status === "error"}
                    class:paused={item.status === "paused"}
                    aria-hidden="true"
                    aria-label="Agent status: {item.status}"
                  ></span>
                {:else}
                  <span
                    class="ns-color-dot"
                    style="background: {PROJECT_COLORS[i % PROJECT_COLORS.length]}"
                    aria-hidden="true"
                  ></span>
                {/if}
                <span class="ns-item-label">{item.label}</span>
              </a>
            {/each}
          {/snippet}
        </SidebarSection>
      {:else}
        {@const Icon = section.icon}
        <a
          class="ns-link"
          href={section.href}
          class:active={isActive(section.href)}
          aria-current={isActive(section.href) ? "page" : undefined}
        >
          <Icon size={16} />
          <span>{section.label}</span>
          {#if section.badge}
            {#if section.label === "DASHBOARD"}
              <span class="ns-live-badge" aria-label="{section.badge} agents live">{section.badge} live</span>
            {:else}
              <span class="ns-badge">{section.badge}</span>
            {/if}
          {/if}
        </a>
      {/if}
    {/each}
  </nav>
</aside>

<style>
  /* ── Top action bar ─────────────────────────────────────────────── */
  .ns-top-actions {
    padding: 8px 8px 4px;
    flex-shrink: 0;
  }

  .ns-new-signal {
    display: flex;
    align-items: center;
    gap: 6px;
    width: 100%;
    padding: 6px 8px;
    background: transparent;
    border: 1px solid var(--border-default);
    border-radius: 0;
    color: var(--text-secondary);
    text-decoration: none;
    font-size: 12px;
    font-weight: 500;
    letter-spacing: 0.02em;
    cursor: pointer;
    transition: background 100ms ease, color 100ms ease, border-color 100ms ease;
    white-space: nowrap;
  }

  .ns-new-signal:hover {
    background: var(--bg-surface);
    color: var(--text-primary);
    border-color: var(--text-tertiary);
  }

  /* ── Live agent badge ────────────────────────────────────────────── */
  .ns-live-badge {
    margin-left: auto;
    background: color-mix(in srgb, var(--accent-primary) 15%, transparent);
    color: var(--accent-primary);
    font-size: 10px;
    font-weight: 600;
    padding: 1px 6px;
    border-radius: 0;
    min-width: 18px;
    text-align: center;
    letter-spacing: 0.02em;
  }

  /* ── Project / generic color dot ─────────────────────────────────── */
  .ns-color-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    flex-shrink: 0;
  }

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
    border-radius: 0;
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
    border-radius: 0;
    color: var(--text-secondary);
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

  /* Agent status dot */
  .ns-status-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--text-disabled, color-mix(in srgb, var(--text-tertiary) 50%, transparent));
    flex-shrink: 0;
  }

  .ns-status-dot.working {
    background: var(--accent-primary);
    animation: ns-pulse 2s ease-in-out infinite;
  }

  .ns-status-dot.error {
    background: var(--accent-error);
  }

  .ns-status-dot.paused {
    background: var(--accent-warning);
  }

  @keyframes ns-pulse {
    0%, 100% {
      opacity: 1;
      box-shadow: 0 0 0 0 var(--accent-primary);
    }
    50% {
      opacity: 0.7;
      box-shadow: 0 0 0 4px transparent;
    }
  }

  .ns-badge {
    margin-left: auto;
    background: var(--accent-primary);
    color: white;
    font-size: 10px;
    font-weight: 600;
    padding: 1px 6px;
    border-radius: 0;
    min-width: 18px;
    text-align: center;
  }

  /* ── Mobile overlay mode ─────────────────────────────────────────── */
  .ns-sidebar.mobile {
    position: absolute;
    top: 0;
    left: 0;
    z-index: 100;
    width: 240px;
    min-width: 240px;
    display: none;
    /* Override width transition — use display toggle instead */
    transition: none;
  }

  .ns-sidebar.mobile.mobile-open {
    display: flex;
  }
</style>
