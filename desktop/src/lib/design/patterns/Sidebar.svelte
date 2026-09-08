<script lang="ts">
/**
 * Sidebar — 3-group navigation spine.
 * Groups: Cockpit | Workspace | System.
 * Active route highlighted via SvelteKit page state.
 * Badges on items with counts. Collapsible via ui.sidebarCollapsed.
 * Groups + item order driven by sidebarConfig store (localStorage-persisted).
 * LOC target: ≤ 200.
 */

import {
  Activity,
  BarChart2,
  BookOpen,
  Bot,
  Box,
  Briefcase,
  Calendar,
  CheckSquare,
  CircleDot,
  FileText,
  FolderKanban,
  FolderOpen,
  Gauge,
  Hammer,
  Hash,
  History,
  Home,
  Inbox,
  LayoutGrid,
  LayoutTemplate,
  MessageCircle,
  Monitor,
  Plus,
  Repeat,
  ShieldCheck,
  Target,
  Terminal,
  UserCheck,
  Users,
  Zap,
} from 'lucide-svelte';
import { goto } from '$app/navigation';
import { page } from '$app/state';
import { Tooltip } from '$lib/design/foundation';
import { sidebarConfig } from '$lib/stores/sidebar-config.svelte.js';
import { ui } from '$lib/stores/ui.svelte.js';
import StatusDot from './StatusDot.svelte';

// lucide-svelte v1 components are Svelte 4 class-based — not assignable to the
// Svelte 5 Component<Props> type. Use unknown to hold references and cast
// through unknown at the svelte:component call site.
type IconComponent = unknown;

// Local icon lookup — keeps icon resolution inside the component, not in the store.
const ICON_MAP: Record<string, IconComponent> = {
  Activity: Activity as IconComponent,
  BarChart2: BarChart2 as IconComponent,
  BookOpen: BookOpen as IconComponent,
  Bot: Bot as IconComponent,
  Box: Box as IconComponent,
  Briefcase: Briefcase as IconComponent,
  Calendar: Calendar as IconComponent,
  CheckSquare: CheckSquare as IconComponent,
  CircleDot: CircleDot as IconComponent,
  FileText: FileText as IconComponent,
  FolderKanban: FolderKanban as IconComponent,
  FolderOpen: FolderOpen as IconComponent,
  Gauge: Gauge as IconComponent,
  Hammer: Hammer as IconComponent,
  Hash: Hash as IconComponent,
  LayoutGrid: LayoutGrid as IconComponent,
  History: History as IconComponent,
  Inbox: Inbox as IconComponent,
  LayoutTemplate: LayoutTemplate as IconComponent,
  MessageCircle: MessageCircle as IconComponent,
  Monitor: Monitor as IconComponent,
  Repeat: Repeat as IconComponent,
  ShieldCheck: ShieldCheck as IconComponent,
  Target: Target as IconComponent,
  Terminal: Terminal as IconComponent,
  UserCheck: UserCheck as IconComponent,
  Users: Users as IconComponent,
  Zap: Zap as IconComponent,
};

interface NavItem {
  label: string;
  path: string;
  icon: IconComponent;
  badge?: number;
  badgeStyle?: 'count' | 'warn';
  comingSoon?: boolean;
}

interface NavGroup {
  label: string;
  items: NavItem[];
}

// Derive visible groups from the config store — hidden items are filtered out.
const groups = $derived<NavGroup[]>(
  sidebarConfig.config.groups.map((g) => ({
    label: g.label,
    items: g.items
      .filter((item) => !item.hidden)
      .map((item) => ({
        label: item.label,
        path: item.path,
        icon: ICON_MAP[item.icon] ?? (Monitor as IconComponent),
        badge: item.badge,
        badgeStyle: item.badgeStyle,
        comingSoon: item.comingSoon,
      })),
  }))
);

const collapsed = $derived(ui.sidebarCollapsed);

function isActive(path: string): boolean {
  if (path === '/') return page.url.pathname === '/';
  return page.url.pathname.startsWith(path) && path !== '/coming-soon';
}

function navigate(path: string): void {
  goto(path);
}
</script>

<nav
  class="cnp-sidebar-nav"
  class:cnp-sidebar-nav--collapsed={collapsed}
  aria-label="Main menu"
>
  <!-- Home — outside groups -->
  <Tooltip content={collapsed ? 'Home' : undefined} side="right">
    <button
      class="cnp-nav-item"
      class:cnp-nav-item--collapsed={collapsed}
      class:cnp-nav-item--active={isActive('/home')}
      onclick={() => navigate('/home')}
      aria-label="Home"
      aria-current={isActive('/home') ? 'page' : undefined}
    >
      <Home size={14} aria-hidden="true" />
      {#if !collapsed}
        <span class="cnp-nav-item__label">Home</span>
      {/if}
    </button>
  </Tooltip>

  <!-- 3 groups -->
  {#each groups as group (group.label)}
    <div class="cnp-nav-group">
      {#if !collapsed}
        <span class="cnp-nav-group__label">{group.label}</span>
      {/if}

      {#each group.items as item (item.path + item.label)}
        {@const active = isActive(item.path) && !item.comingSoon}
        <!-- Sessions row uses a wrapper div so the "+" is a sibling, not a child button. -->
        {#if !collapsed && item.path === '/sessions'}
          <div class="cnp-nav-item-row" class:cnp-nav-item-row--active={active}>
            <button
              class="cnp-nav-item cnp-nav-item--flex1"
              class:cnp-nav-item--active={active}
              onclick={() => navigate(item.path)}
              aria-label={item.label}
              aria-current={active ? 'page' : undefined}
            >
              <!-- svelte-ignore svelte_component_deprecated -->
              <svelte:component this={item.icon as unknown as typeof import('svelte').SvelteComponent} size={14} aria-hidden="true" />
              <span class="cnp-nav-item__label">{item.label}</span>
            </button>
            <button
              class="cnp-nav-plus"
              onclick={() => ui.openNewSessionModal()}
              aria-label="New session (Cmd+N)"
              title="New session (⌘N)"
            >
              <Plus size={10} aria-hidden="true" />
            </button>
          </div>
        {:else}
          <Tooltip content={collapsed ? item.label : undefined} side="right">
            <button
              class="cnp-nav-item"
              class:cnp-nav-item--collapsed={collapsed}
              class:cnp-nav-item--active={active}
              onclick={() => navigate(item.path)}
              aria-label={item.label}
              aria-current={active ? 'page' : undefined}
            >
              <!-- svelte-ignore svelte_component_deprecated -->
              <svelte:component this={item.icon as unknown as typeof import('svelte').SvelteComponent} size={14} aria-hidden="true" />

              {#if !collapsed}
                <span class="cnp-nav-item__label">{item.label}</span>

                {#if item.badge !== undefined && item.badge > 0}
                  <span
                    class="cnp-nav-badge"
                    class:cnp-nav-badge--warn={item.badgeStyle === 'warn'}
                    aria-label="{item.badge} {item.label.toLowerCase()}"
                  >
                    {item.badgeStyle === 'warn' ? '⚠' : ''}{item.badge}
                  </span>
                {/if}
              {:else if item.badge !== undefined && item.badge > 0}
                <StatusDot color={item.badgeStyle === 'warn' ? 'amber' : 'green'} />
              {/if}
            </button>
          </Tooltip>
        {/if}
      {/each}
    </div>
  {/each}
</nav>

<style>
  .cnp-sidebar-nav {
    display: flex;
    flex-direction: column;
    gap: 1px;
    flex: 1;
    overflow-y: auto;
    padding: var(--space-2);
  }

  .cnp-sidebar-nav--collapsed {
    padding: var(--space-2) 0;
    align-items: center;
  }

  .cnp-nav-group {
    display: flex;
    flex-direction: column;
    gap: 1px;
    margin-top: var(--space-3);
  }

  .cnp-nav-group__label {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.08em;
    color: var(--fg-subtle);
    padding: var(--space-1) var(--space-2);
    opacity: 0.7;
    text-transform: uppercase;
    user-select: none;
  }

  .cnp-nav-item {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-1) var(--space-2);
    border: none;
    background: transparent;
    border-radius: var(--radius-md);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg-muted);
    width: 100%;
    text-align: left;
    min-height: 28px;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
    white-space: nowrap;
    overflow: hidden;
  }

  .cnp-nav-item:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .cnp-nav-item--active {
    background: color-mix(in oklch, var(--fg) 10%, transparent 90%);
    color: var(--fg);
  }

  .cnp-nav-item--collapsed {
    width: 36px;
    min-width: 36px;
    justify-content: center;
    padding: var(--space-1);
    gap: 0;
    position: relative;
  }

  .cnp-nav-item--collapsed :global(.cnp-status-dot) {
    position: absolute;
    top: 4px;
    right: 4px;
  }

  /* Tooltip primitive wraps the trigger in a <span>. Make those wrappers
     transparent to flex layout so nav items remain block-stacked. The
     :has() selector targets only spans wrapping a nav-item button; the
     group label span (which contains text, not a button) is left alone. */
  .cnp-sidebar-nav :global(span:has(> .cnp-nav-item)) {
    display: contents;
  }

  .cnp-nav-item__label {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .cnp-nav-item-row {
    display: flex;
    align-items: center;
    border-radius: var(--radius-md);
    transition: background var(--dur-instant) var(--ease-out);
  }

  .cnp-nav-item-row:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
  }

  .cnp-nav-item-row--active {
    background: color-mix(in oklch, var(--fg) 10%, transparent 90%);
  }

  .cnp-nav-item--flex1 {
    flex: 1;
    border-radius: var(--radius-md) 0 0 var(--radius-md);
  }

  .cnp-nav-item--flex1:hover,
  .cnp-nav-item-row:hover .cnp-nav-item--flex1 {
    background: transparent;
  }

  .cnp-nav-plus {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 16px;
    height: 16px;
    border-radius: var(--radius-sm, 4px);
    border: none;
    background: transparent;
    color: var(--fg-subtle);
    cursor: pointer;
    flex-shrink: 0;
    opacity: 0;
    transition: opacity var(--dur-instant) var(--ease-out), background var(--dur-instant) var(--ease-out), color var(--dur-instant) var(--ease-out);
  }

  .cnp-nav-item-row:hover .cnp-nav-plus {
    opacity: 1;
  }

  .cnp-nav-plus:hover {
    background: color-mix(in oklch, var(--fg) 12%, transparent 88%);
    color: var(--fg);
    opacity: 1;
  }

  .cnp-nav-plus:focus-visible {
    outline: 2px solid var(--cnp-accent, currentColor);
    outline-offset: 1px;
    opacity: 1;
  }

  .cnp-nav-badge {
    flex-shrink: 0;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 18px;
    height: 16px;
    padding: 0 4px;
    border-radius: 9999px;
    font-size: 10px;
    font-weight: 600;
    background: color-mix(in oklch, var(--fg) 12%, transparent 88%);
    color: var(--fg-muted);
    line-height: 1;
  }

  .cnp-nav-badge--warn {
    background: color-mix(in oklch, var(--signal-warn) 20%, transparent 80%);
    color: var(--signal-warn);
  }
</style>
