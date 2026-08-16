<script lang="ts">
  /**
   * WorkspaceRail — narrow 56px left rail with workspace icons.
   * CSS prefix: wr-
   *
   * Mount between the sidebar and shell main area. Controlled by
   * Settings → Appearance → Show workspace rail (localStorage).
   *
   * The rail renders workspace initials as icon buttons. Current workspace
   * is highlighted with the accent color.
   */
  import { createQuery } from '@tanstack/svelte-query';
  import { Plus } from 'lucide-svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import { apiGet } from '$lib/api/client.js';
  import { ui } from '$lib/stores/ui.svelte.js';

  interface Workspace {
    slug: string;
    name: string;
  }

  // ── Query ─────────────────────────────────────────────────────────────────

  const workspacesQ = createQuery<Workspace[]>({
    queryKey: ['workspaces'],
    queryFn: () => apiGet<{ data: Workspace[] }>('/workspaces').then((r) => r.data ?? []),
    staleTime: 60_000,
  });

  const workspaces = $derived($workspacesQ.data ?? []);
  const currentSlug = $derived(ui.currentWorkspaceSlug);

  // ── Helpers ───────────────────────────────────────────────────────────────

  function initials(name: string): string {
    return name
      .split(/\s+/)
      .slice(0, 2)
      .map((w) => w[0]?.toUpperCase() ?? '')
      .join('');
  }

  function navigateTo(slug: string) {
    ui.setCurrentWorkspace(slug);
    void goto(`/workspaces/${slug}`);
  }
</script>

<nav class="wr-rail" aria-label="Workspace switcher rail">
  <ul class="wr-list" role="list">
    {#each workspaces as ws (ws.slug)}
      {@const active = ws.slug === currentSlug}
      <li class="wr-item" role="listitem">
        <button
          class="wr-icon"
          class:wr-icon--active={active}
          onclick={() => navigateTo(ws.slug)}
          title={ws.name}
          aria-label="Switch to workspace {ws.name}"
          aria-current={active ? 'page' : undefined}
        >
          <span class="wr-initials" aria-hidden="true">{initials(ws.name)}</span>
        </button>
      </li>
    {/each}
  </ul>

  <div class="wr-footer">
    <button
      class="wr-new-btn"
      onclick={() => goto('/workspaces')}
      title="Manage workspaces"
      aria-label="Manage workspaces"
    >
      <Plus size={14} aria-hidden="true" />
    </button>
  </div>
</nav>

<style>
  .wr-rail {
    width: 56px;
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    background: var(--sidebar);
    border-right: 1px solid var(--border);
    overflow: hidden;
    transition: width var(--dur-normal) var(--ease-io);
  }

  .wr-list {
    list-style: none;
    margin: 0;
    padding: var(--space-2) 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-1);
    flex: 1;
    overflow-y: auto;
    scrollbar-width: none;
  }

  .wr-list::-webkit-scrollbar {
    display: none;
  }

  .wr-item {
    width: 100%;
    display: flex;
    justify-content: center;
  }

  .wr-icon {
    width: 36px;
    height: 36px;
    border: none;
    border-radius: var(--radius-md);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background var(--dur-fast) ease, box-shadow var(--dur-fast) ease;
    position: relative;
  }

  .wr-icon:hover {
    background: color-mix(in oklch, var(--fg) 14%, transparent);
  }

  .wr-icon--active {
    background: var(--cnp-accent, color-mix(in oklch, var(--fg) 20%, transparent));
    box-shadow: 0 0 0 2px var(--cnp-accent, transparent);
  }

  .wr-icon--active:hover {
    background: var(--cnp-accent, color-mix(in oklch, var(--fg) 25%, transparent));
  }

  .wr-icon:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .wr-initials {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 700;
    color: var(--fg);
    letter-spacing: -0.01em;
    line-height: 1;
    user-select: none;
  }

  .wr-icon--active .wr-initials {
    color: color-mix(in oklch, var(--fg) 90%, white 10%);
  }

  .wr-footer {
    padding: var(--space-2) 0;
    display: flex;
    justify-content: center;
    border-top: 1px solid var(--border);
    flex-shrink: 0;
  }

  .wr-new-btn {
    width: 36px;
    height: 36px;
    border: 1px dashed var(--border);
    border-radius: var(--radius-md);
    background: transparent;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--fg-subtle);
    transition: color var(--dur-fast) ease, border-color var(--dur-fast) ease,
      background var(--dur-fast) ease;
  }

  .wr-new-btn:hover {
    color: var(--fg-muted);
    border-color: var(--border-strong);
    background: color-mix(in oklch, var(--fg) 5%, transparent);
  }

  .wr-new-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }
</style>
