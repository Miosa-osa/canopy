<script lang="ts">
/**
 * Sidebar — 3-group navigation spine (Core-OSS pattern).
 * Groups: Cockpit | Workspace | System.
 * Active route highlighted via SvelteKit page state.
 * Badges on items with counts. Collapsible via ui.sidebarCollapsed.
 * LOC target: ≤ 200.
 */

import {
  BarChart2,
  Bot,
  Box,
  Briefcase,
  Calendar,
  CheckSquare,
  FileText,
  FolderOpen,
  Hash,
  History,
  Home,
  Inbox,
  LayoutTemplate,
  MessageCircle,
  Monitor,
  ShieldCheck,
  Terminal,
  Zap,
} from 'lucide-svelte';
import { goto } from '$app/navigation';
import { page } from '$app/state';
import { ui } from '$lib/stores/ui.svelte.js';
import StatusDot from './StatusDot.svelte';

// lucide-svelte v1 components are Svelte 4 class-based — not assignable to the
// Svelte 5 Component<Props> type. Use unknown to hold references and cast
// through unknown at the svelte:component call site.
type IconComponent = unknown;

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

const groups: NavGroup[] = [
  {
    label: 'COCKPIT',
    items: [
      { label: 'Runtimes', path: '/runtimes', icon: Monitor as IconComponent },
      { label: 'Sessions', path: '/sessions', icon: History as IconComponent },
      { label: 'Agents', path: '/agents', icon: Bot as IconComponent },
      { label: 'Workspaces', path: '/workspaces', icon: Briefcase as IconComponent },
      { label: 'Sandboxes', path: '/sandboxes', icon: Box as IconComponent },
      { label: 'Command Center', path: '/dashboard', icon: Terminal as IconComponent },
    ],
  },
  {
    label: 'WORKSPACE',
    items: [
      {
        label: 'Inbox',
        path: '/coming-soon',
        icon: Inbox as IconComponent,
        badge: 7,
        comingSoon: true,
      },
      {
        label: 'Schedule',
        path: '/coming-soon',
        icon: Calendar as IconComponent,
        comingSoon: true,
      },
      {
        label: 'Chat',
        path: '/chat',
        icon: MessageCircle as IconComponent,
      },
      {
        label: 'Channels',
        path: '/channels',
        icon: Hash as IconComponent,
      },
      { label: 'Files', path: '/files', icon: FolderOpen as IconComponent },
      { label: 'Docs', path: '/docs', icon: FileText as IconComponent },
      {
        label: 'Tasks',
        path: '/tasks',
        icon: CheckSquare as IconComponent,
      },
    ],
  },
  {
    label: 'SYSTEM',
    items: [
      { label: 'Skills', path: '/coming-soon', icon: Zap as IconComponent, comingSoon: true },
      {
        label: 'Templates',
        path: '/coming-soon',
        icon: LayoutTemplate as IconComponent,
        comingSoon: true,
      },
      {
        label: 'Analytics',
        path: '/coming-soon',
        icon: BarChart2 as IconComponent,
        comingSoon: true,
      },
      {
        label: 'Governance',
        path: '/coming-soon',
        icon: ShieldCheck as IconComponent,
        badge: 1,
        badgeStyle: 'warn',
        comingSoon: true,
      },
    ],
  },
];

const collapsed = $derived(ui.sidebarCollapsed);

function isActive(path: string): boolean {
  if (path === '/') return page.url.pathname === '/';
  return page.url.pathname.startsWith(path) && path !== '/coming-soon';
}

function navigate(path: string): void {
  goto(path);
}
</script>

<nav class="cnp-sidebar-nav" aria-label="Main menu">
  <!-- Home — outside groups -->
  <button
    class="cnp-nav-item"
    class:cnp-nav-item--active={isActive('/')}
    onclick={() => navigate('/')}
    aria-label="Home"
    aria-current={isActive('/') ? 'page' : undefined}
    title={collapsed ? 'Home' : undefined}
  >
    <Home size={14} aria-hidden="true" />
    {#if !collapsed}
      <span class="cnp-nav-item__label">Home</span>
    {/if}
  </button>

  <!-- 3 groups -->
  {#each groups as group (group.label)}
    <div class="cnp-nav-group">
      {#if !collapsed}
        <span class="cnp-nav-group__label">{group.label}</span>
      {/if}

      {#each group.items as item (item.path + item.label)}
        {@const active = isActive(item.path) && !item.comingSoon}
        <button
          class="cnp-nav-item"
          class:cnp-nav-item--active={active}
          onclick={() => navigate(item.path)}
          aria-label={item.label}
          aria-current={active ? 'page' : undefined}
          title={collapsed ? item.label : undefined}
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

  .cnp-nav-item__label {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
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
