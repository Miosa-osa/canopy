<script lang="ts">
/**
 * Root layout — inset card shell (docs/02-frontend-design.md §5).
 *
 * Responsibilities:
 *   1. Mount theme (load persisted, apply to <html>).
 *   2. Register global keyboard shortcuts + ⌘K command palette.
 *   3. Render the shell geometry (sidebar + inset main).
 *   4. Provide TanStack Query client to all child routes.
 */
import '../app.css';
import { QueryClient, QueryClientProvider } from '@tanstack/svelte-query';
import { PanelLeft } from 'lucide-svelte';
import { onMount } from 'svelte';
import { goto } from '$app/navigation';
import { page } from '$app/state';
import { syncRuntimesIfStale } from '$lib/bootstrap/runtime-sync.js';
import CommandPalette from '$lib/design/patterns/CommandPalette.svelte';
import KeywordSearchDialog from '$lib/design/patterns/keyword-search/KeywordSearchDialog.svelte';
import NewSessionModal from '$lib/design/patterns/NewSessionModal.svelte';
import NotificationBell from '$lib/design/patterns/NotificationBell.svelte';
import Sidebar from '$lib/design/patterns/Sidebar.svelte';
import ToastContainer from '$lib/design/patterns/ToastContainer.svelte';
import WorkspaceRail from '$lib/design/patterns/WorkspaceRail.svelte';
import WorkspaceSwitcher from '$lib/design/patterns/WorkspaceSwitcher.svelte';
import ThemeToggle from '$lib/design/primitives/ThemeToggle.svelte';
import { loadPersistedTheme, persistTheme } from '$lib/stores/theme-persistence.js';
import { themeRegistry } from '$lib/stores/theme-registry.svelte.js';
import { ui } from '$lib/stores/ui.svelte.js';
import { handleGlobalShortcut } from '$lib/utils/keyboard.js';

// Force the theme-registry to initialize on app boot — it applies
// CSS vars + data-theme + .dark class, overriding the legacy theme store.
void themeRegistry.activeThemeId;

let { children } = $props();

/**
 * /onboarding hides the sidebar/shell chrome — the wizard owns the full
 * viewport. All other routes get the standard inset shell.
 */
const isOnboarding = $derived(page.url.pathname.startsWith('/onboarding'));

/** Single QueryClient instance shared by all routes via context. */
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

onMount(async () => {
  const saved = await loadPersistedTheme();
  if (saved) ui.setTheme(saved);

  // Fire-and-forget: scan $PATH for runtime binaries (Tauri-only), POST results
  // to Phoenix /runtimes/detect so installed/version/binary_path become real.
  // Rate-limited to once per 60s to avoid re-detection storms on re-mount.
  const result = await syncRuntimesIfStale();

  // First-run: no runtimes detected + not already on /onboarding → route there.
  // `result === null` (rate-limited cache hit) means we already synced this
  // session; never re-route on those.
  if (
    result &&
    result.ok &&
    result.installedCount === 0 &&
    !page.url.pathname.startsWith('/onboarding')
  ) {
    void goto('/onboarding');
  }
});

$effect(() => {
  const theme = ui.theme;
  if (typeof document === 'undefined') return;
  // data-theme drives Canopy's OKLCh token selectors.
  // .dark drives Foundation primitive CSS (Modal, Tabs, etc.).
  document.documentElement.setAttribute('data-theme', theme);
  document.documentElement.classList.toggle('dark', theme === 'dark');
  void persistTheme(theme);
});

/** Extend global shortcuts — ⌘K for command palette. */
function handleKeydown(e: KeyboardEvent): void {
  // ⌘N — new session modal
  if ((e.metaKey || e.ctrlKey) && !e.shiftKey && e.key === 'n') {
    e.preventDefault();
    ui.openNewSessionModal();
    return;
  }
  // ⌘K — command palette
  if (e.metaKey && !e.shiftKey && e.key === 'k') {
    e.preventDefault();
    ui.openCommandPalette();
    return;
  }
  // ⌘/ — keyword search across sessions, agents, workspaces
  if ((e.metaKey || e.ctrlKey) && e.key === '/') {
    e.preventDefault();
    ui.openKeywordSearch();
    return;
  }
  // ⌘\ — toggle sidebar collapse
  if ((e.metaKey || e.ctrlKey) && !e.shiftKey && e.key === '\\') {
    e.preventDefault();
    ui.toggleSidebar();
    return;
  }
  // ⌘, — settings
  if (e.metaKey && !e.shiftKey && e.key === ',') {
    e.preventDefault();
    import('$app/navigation').then(({ goto }) => goto('/settings'));
    return;
  }
  // ⌘1–5 — section jumps
  if (e.metaKey && !e.shiftKey) {
    const sectionMap: Record<string, string> = {
      1: '/home',
      2: '/runtimes',
      3: '/sessions',
      4: '/agents',
      5: '/workspaces',
    };
    const target = sectionMap[e.key];
    if (target) {
      e.preventDefault();
      import('$app/navigation').then(({ goto }) => goto(target));
      return;
    }
  }
  // Delegate ⌘⇧D and ⌘⇧L to keyboard utils
  handleGlobalShortcut(e);
}
</script>

<svelte:window onkeydown={handleKeydown} />

<QueryClientProvider client={queryClient}>
  {#if isOnboarding}
    <!-- Onboarding owns the full viewport — no sidebar, no inset card -->
    <div class="onboarding-shell">
      {@render children()}
    </div>
  {:else}
  <div class="shell">
    <aside
      class="sidebar"
      class:collapsed={ui.sidebarCollapsed}
      aria-label="Primary navigation"
    >
      <div class="sidebar-wordmark">
        {#if !ui.sidebarCollapsed}
          <span class="wordmark-text">Canopy</span>
        {/if}
        <button
          class="btn-compact btn-compact-ghost btn-compact-icon sidebar-collapse-toggle"
          class:sidebar-collapse-toggle--collapsed={ui.sidebarCollapsed}
          onclick={() => ui.toggleSidebar()}
          aria-label={ui.sidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          aria-expanded={!ui.sidebarCollapsed}
          title={ui.sidebarCollapsed ? 'Expand sidebar (⌘\\)' : 'Collapse sidebar (⌘\\)'}
        >
          <PanelLeft size={14} aria-hidden="true" />
        </button>
      </div>

      <Sidebar />

      <div class="sidebar-footer" aria-label="Sidebar footer">
        <div class="sidebar-footer__spend" aria-hidden={ui.sidebarCollapsed}>
          {#if !ui.sidebarCollapsed}
            <span class="spend-label">Usage data not connected</span>
          {/if}
        </div>

        <!-- WorkspaceSwitcher — between spend bar and settings (Track #57) -->
        <div class="sidebar-footer__workspace" style="position: relative;">
          <WorkspaceSwitcher />
        </div>

        <div class="sidebar-footer__actions">
          {#if !isOnboarding}
            <NotificationBell />
          {/if}
          <button
            class="btn-compact btn-compact-ghost btn-compact-icon"
            onclick={() => import('$app/navigation').then(({ goto }) => goto('/settings'))}
            aria-label="Settings"
            title="Settings"
          >
            <!-- Settings icon inline SVG (avoids import overhead) -->
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
              <circle cx="12" cy="12" r="3"/>
              <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>
            </svg>
          </button>
        </div>
      </div>
    </aside>

    {#if ui.showWorkspaceRail}
      <WorkspaceRail />
    {/if}

    <div class="main-container">
      <main class="glass-panel">
        {@render children()}
      </main>
    </div>
  </div>
  {/if}

  <!-- Global overlays (present on every route, including /onboarding) -->
  <CommandPalette />
  <KeywordSearchDialog open={ui.keywordSearchOpen} onclose={() => ui.closeKeywordSearch()} />
  <NewSessionModal open={ui.newSessionModalOpen} onClose={() => ui.closeNewSessionModal()} />
  <ThemeToggle />
  <ToastContainer />
</QueryClientProvider>

<style>
  .shell {
    background: var(--sidebar);
    display: flex;
    height: 100vh;
    overflow: hidden;
  }

  .onboarding-shell {
    background: var(--bg);
    height: 100vh;
    overflow: auto;
  }

  .sidebar {
    width: 220px;
    display: flex;
    flex-direction: column;
    flex-shrink: 0;
    transition: width var(--dur-normal) var(--ease-io);
    overflow: hidden;
  }

  .sidebar.collapsed {
    width: 56px;
  }

  .sidebar-wordmark {
    padding: var(--space-4) var(--space-3);
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-2);
    min-height: 48px;
    flex-shrink: 0;
  }

  .sidebar.collapsed .sidebar-wordmark {
    justify-content: center;
    padding-left: 0;
    padding-right: 0;
  }

  .wordmark-text {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    letter-spacing: -0.02em;
    color: var(--fg);
    white-space: nowrap;
    transition: opacity var(--dur-fast) var(--ease-out);
  }

  .sidebar-collapse-toggle {
    flex-shrink: 0;
    transition: transform var(--dur-normal) var(--ease-io);
  }

  .sidebar-collapse-toggle--collapsed {
    transform: rotate(180deg);
  }

  .sidebar-footer {
    padding: var(--space-3);
    flex-shrink: 0;
    border-top: 1px solid var(--border);
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .sidebar-footer__spend {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .spend-label {
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--fg-subtle);
    white-space: nowrap;
  }

  .sidebar.collapsed .spend-label {
    display: none;
  }

  .sidebar-footer__actions {
    display: flex;
    align-items: center;
    justify-content: flex-start;
    gap: var(--space-1);
  }

  .main-container {
    flex: 1;
    padding: var(--space-2) var(--space-2) var(--space-2) 0;
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    min-width: 0;
  }

  main {
    flex: 1;
    /* background and border handled by .glass-panel utility (glass.css) */
    border-radius: var(--radius-lg);
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }
</style>
