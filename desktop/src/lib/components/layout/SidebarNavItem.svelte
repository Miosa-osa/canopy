<!-- src/lib/components/layout/SidebarNavItem.svelte -->
<script lang="ts">
  interface Props {
    href: string;
    label: string;
    icon: string;
    shortcut?: string;
    badge?: number;
    active?: boolean;
  }

  let { href, label, icon, shortcut, badge, active = false }: Props = $props();
</script>

<a
  {href}
  class="sni-item"
  class:active
  aria-current={active ? 'page' : undefined}
  title={label}
>
  <span class="sni-icon" aria-hidden="true">
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
      <path d={icon} />
    </svg>
  </span>

  <span class="sni-label">{label}</span>

  <span class="sni-right">
    {#if shortcut}
      <span class="sni-shortcut">{shortcut}</span>
    {/if}
    {#if badge !== undefined && badge > 0}
      <span class="sni-badge">{badge > 99 ? '99+' : badge}</span>
    {/if}
  </span>
</a>

<style>
  .sni-item {
    display: flex;
    align-items: center;
    gap: 8px;
    height: 32px;
    padding: 0 12px;
    border-radius: var(--radius-xs);
    text-decoration: none;
    color: var(--text-secondary);
    transition: background 120ms ease, color 120ms ease;
    position: relative;
    overflow: hidden;
  }

  .sni-item:hover {
    background: var(--bg-surface);
    color: var(--text-primary);
  }

  .sni-item.active {
    background: var(--bg-elevated);
    color: var(--text-primary);
  }

  .sni-item.active::before {
    content: '';
    position: absolute;
    left: 0;
    top: 6px;
    bottom: 6px;
    width: 2px;
    background: var(--accent-primary);
    border-radius: 0 1px 1px 0;
  }

  .sni-icon {
    flex-shrink: 0;
    display: flex;
    color: var(--text-tertiary);
    transition: color 120ms ease;
  }

  .sni-item:hover .sni-icon,
  .sni-item.active .sni-icon {
    color: var(--text-primary);
  }

  .sni-label {
    flex: 1;
    font-size: 13px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .sni-right {
    display: flex;
    align-items: center;
    gap: 4px;
    flex-shrink: 0;
  }

  .sni-shortcut {
    font-size: 10px;
    color: var(--text-muted);
    letter-spacing: 0.02em;
  }

  .sni-badge {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 16px;
    height: 16px;
    padding: 0 4px;
    border-radius: 8px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    color: var(--text-secondary);
    font-size: 10px;
    font-weight: 500;
  }
</style>
