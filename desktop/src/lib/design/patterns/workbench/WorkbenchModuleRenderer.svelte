<script lang="ts">
  /**
   * WorkbenchModuleRenderer — renders the real sidebar page component
   * inside a Workbench canvas tile.
   *
   * Routes that use `page.url.searchParams` (/sessions, /tasks, /governance)
   * cannot be safely embedded and fall back to a "not embeddable" state with
   * an "Open full page" button.
   *
   * CSS prefix: wmr-
   */
  import { goto } from '$app/navigation';
  import { ExternalLink, Loader } from 'lucide-svelte';

  interface Props {
    route: string;
    workspaceSlug?: string;
  }

  let { route, workspaceSlug = 'default' }: Props = $props();

  // Routes that depend on page.url.searchParams — cannot be embedded.
  const NOT_EMBEDDABLE = new Set(['/sessions', '/tasks', '/governance']);

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let PageComponent = $state<any>(null);
  let loading = $state(false);
  let error = $state('');
  let notEmbeddable = $state(false);

  $effect(() => {
    const r = route;
    loading = true;
    error = '';
    notEmbeddable = false;
    PageComponent = null;

    if (NOT_EMBEDDABLE.has(r)) {
      notEmbeddable = true;
      loading = false;
      return;
    }

    void loadModule(r);
  });

  async function loadModule(r: string): Promise<void> {
    try {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const mod = await getModuleImport(r) as { default: any } | null;
      if (mod?.default) {
        PageComponent = mod.default;
      } else {
        notEmbeddable = true;
      }
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load module';
    } finally {
      loading = false;
    }
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  type AnyModule = { default: any };

  async function getModuleImport(r: string): Promise<AnyModule | null> {
    switch (r) {
      case '/agents':         return (await import('../../../../routes/agents/+page.svelte')) as AnyModule;
      case '/activity':       return (await import('../../../../routes/activity/+page.svelte')) as AnyModule;
      case '/analytics':      return (await import('../../../../routes/analytics/+page.svelte')) as AnyModule;
      case '/runtimes':       return (await import('../../../../routes/runtimes/+page.svelte')) as AnyModule;
      case '/workspaces':     return (await import('../../../../routes/workspaces/+page.svelte')) as AnyModule;
      case '/skills':         return (await import('../../../../routes/skills/+page.svelte')) as AnyModule;
      case '/templates':      return (await import('../../../../routes/templates/+page.svelte')) as AnyModule;
      case '/team':           return (await import('../../../../routes/team/+page.svelte')) as AnyModule;
      case '/goals':          return (await import('../../../../routes/goals/+page.svelte')) as AnyModule;
      case '/routines':       return (await import('../../../../routes/routines/+page.svelte')) as AnyModule;
      case '/review':         return (await import('../../../../routes/review/+page.svelte')) as AnyModule;
      case '/knowledge':      return (await import('../../../../routes/knowledge/+page.svelte')) as AnyModule;
      case '/chat':           return (await import('../../../../routes/chat/+page.svelte')) as AnyModule;
      case '/channels':       return (await import('../../../../routes/channels/+page.svelte')) as AnyModule;
      case '/issues':         return (await import('../../../../routes/issues/+page.svelte')) as AnyModule;
      case '/my-issues':      return (await import('../../../../routes/my-issues/+page.svelte')) as AnyModule;
      case '/schedule':       return (await import('../../../../routes/schedule/+page.svelte')) as AnyModule;
      case '/dashboard':      return (await import('../../../../routes/dashboard/+page.svelte')) as AnyModule;
      case '/command-center': return (await import('../../../../routes/command-center/+page.svelte')) as AnyModule;
      case '/agent-control':  return (await import('../../../../routes/agent-control/+page.svelte')) as AnyModule;
      case '/agent-kanban':   return (await import('../../../../routes/agent-kanban/+page.svelte')) as AnyModule;
      case '/docs':           return (await import('../../../../routes/docs/+page.svelte')) as AnyModule;
      case '/files':          return (await import('../../../../routes/files/+page.svelte')) as AnyModule;
      case '/sandboxes':      return (await import('../../../../routes/sandboxes/+page.svelte')) as AnyModule;
      case '/projects':       return (await import('../../../../routes/projects/+page.svelte')) as AnyModule;
      case '/notifications':  return (await import('../../../../routes/notifications/+page.svelte')) as AnyModule;
      // /drive has a known parse error in its source; fall through to null → "Open full page" fallback.
      default:                return null;
    }
  }
</script>

<div class="wmr-root">
  {#if loading}
    <div class="wmr-state">
      <Loader size={16} class="wmr-spin" aria-hidden="true" />
      <span>Loading module…</span>
    </div>
  {:else if notEmbeddable}
    <div class="wmr-state wmr-state--info">
      <p class="wmr-hint">This module requires routing context and cannot be embedded inline.</p>
      <button
        type="button"
        class="wmr-open-btn"
        onclick={() => goto(route)}
        aria-label="Open {route} in full page"
      >
        <ExternalLink size={12} aria-hidden="true" />
        Open full page
      </button>
    </div>
  {:else if error}
    <div class="wmr-state wmr-state--error">
      <p class="wmr-hint">{error}</p>
      <button
        type="button"
        class="wmr-open-btn"
        onclick={() => goto(route)}
        aria-label="Open {route} in full page"
      >
        <ExternalLink size={12} aria-hidden="true" />
        Open full page
      </button>
    </div>
  {:else if PageComponent}
    <div class="wmr-page">
      <!-- svelte-ignore svelte_component_deprecated -->
      <svelte:component this={PageComponent} />
    </div>
  {/if}
</div>

<style>
  .wmr-root {
    display: flex;
    flex-direction: column;
    min-height: 0;
    height: 100%;
  }

  .wmr-page {
    flex: 1;
    min-height: 0;
    overflow: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  /* Ensure embedded page components fill the container */
  .wmr-page :global([class$="-page"]),
  .wmr-page :global([class*="-page "]) {
    height: 100%;
    min-height: 0;
  }

  .wmr-state {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    justify-content: center;
    gap: 10px;
    padding: 12px;
    color: var(--fg-muted);
    font-size: 12px;
  }

  .wmr-state--error {
    color: var(--destructive, oklch(0.65 0.22 25));
  }

  .wmr-state--info {
    color: var(--fg-subtle);
  }

  .wmr-hint {
    margin: 0;
    line-height: 1.45;
  }

  .wmr-open-btn {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    min-height: 26px;
    padding: 0 9px;
    border: 1px solid var(--border);
    border-radius: 6px;
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 14%, transparent);
    border-color: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 36%, var(--border));
    color: var(--fg);
    font: inherit;
    font-size: 11px;
    cursor: pointer;
  }

  .wmr-open-btn:hover {
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 22%, transparent);
  }

  :global(.wmr-spin) {
    animation: wmr-spin 1s linear infinite;
  }

  @keyframes wmr-spin {
    to { transform: rotate(360deg); }
  }
</style>
