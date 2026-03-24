<script lang="ts">
  import { browser } from '$app/environment';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
import Sidebar from '$lib/components/layout/Sidebar.svelte';
  import ConnectionStatusBar from '$lib/components/layout/ConnectionStatusBar.svelte';
  import ToastContainer from '$lib/components/layout/ToastContainer.svelte';
  import { connectionStore } from '$lib/stores/connection.svelte';
  import { themeStore } from '$lib/stores/theme.svelte';
  import { paletteStore } from '$lib/stores/palette.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';
  import { agentsStore } from '$lib/stores/agents.svelte';
  import { projectsStore } from '$lib/stores/projects.svelte';
  import { settingsStore } from '$lib/stores/settings.svelte';
  import CommandPalette from '$lib/components/layout/CommandPalette.svelte';
  import ActivityWidget from '$lib/components/activity/ActivityWidget.svelte';
  import { activityStore } from '$lib/stores/activity.svelte';
  import { sessionsStore } from '$lib/stores/sessions.svelte';
  import { organizationsStore } from '$lib/stores/organizations.svelte';
  import { approvalsStore } from '$lib/stores/approvals.svelte';
  import { hierarchyStore } from '$lib/stores/hierarchy.svelte';
  import { isTauri, isMacOS } from '$lib/utils/platform';
  import { initializeAuth, getToken, isMockEnabled, workspaces, agents } from '$api/client';

  let { children } = $props();

  // ─── Onboarding guard ────────────────────────────────────────────────────
  // NOTE: This guard runs inside initializeAuth().then() (see the second
  // onMount below) so that _token is already set before we check it.
  // A separate early-mount guard here would fire before auth resolves and
  // always see an empty token, causing spurious redirects to /onboarding.

  // Initialize theme
  $effect(() => { void themeStore.resolved; });

  // Forward session-related activity events to the sessions store so the
  // session list stays current during live execution without a full refetch.
  let _lastForwardedActivityId = $state<string | null>(null);
  $effect(() => {
    const latest = activityStore.events[0];
    if (!latest || latest.id === _lastForwardedActivityId) return;
    _lastForwardedActivityId = latest.id;
    sessionsStore.handleActivityEvent(latest);
  });

  // Sidebar collapsed state — persisted to localStorage
  let sidebarCollapsed = $state(false);
  $effect(() => {
    if (!browser) return;
    const stored = localStorage.getItem('canopy-sidebar-collapsed');
    if (stored !== null) sidebarCollapsed = stored === 'true';
  });

  function toggleSidebar() {
    sidebarCollapsed = !sidebarCollapsed;
    if (browser) localStorage.setItem('canopy-sidebar-collapsed', String(sidebarCollapsed));
  }

  // Nav routes for ⌘1–⌘3 (Core section)
  const NAV_ROUTES = ['/app', '/app/inbox', '/app/office'];

  onMount(() => {
    // Capture stopPolling in outer scope so the cleanup return can call it.
    let stopPolling: (() => void) | null = null;

    // 1. Run auth initialization first: probes backend, disables mock if reachable,
    //    auto-logs in with dev credentials if set, then loads everything else.
    //
    //    IMPORTANT: connection polling and all data fetching must start AFTER
    //    initializeAuth() resolves. Starting polling before auth completes causes
    //    connectionStore.check() → health.get() to set useMock=false while _token
    //    is still null, so every subsequent API request fires without an
    //    Authorization header and receives 401 "unauthorized".
    initializeAuth().then(async () => {
      // ── Onboarding guard (runs after auth resolves) ───────────────────────
      // If the backend is reachable and the user has a valid token, they
      // already have a running setup — skip onboarding entirely.
      let onboardingDone = false;

      if (!isMockEnabled() && getToken()) {
        // Valid authenticated session → treat as fully onboarded.
        localStorage.setItem('canopy-onboarding-complete', 'true');
        localStorage.setItem(
          'canopy-onboarding',
          JSON.stringify({ completed: true }),
        );
        onboardingDone = true;
      } else if (!isMockEnabled()) {
        // Backend reachable but no token yet — check for existing data.
        try {
          const wsList = await workspaces.list();
          if (wsList.length > 0) {
            const agentList = await agents.list(wsList[0].id);
            if (agentList.length > 0) {
              localStorage.setItem('canopy-onboarding-complete', 'true');
              localStorage.setItem(
                'canopy-onboarding',
                JSON.stringify({ completed: true }),
              );
              onboardingDone = true;
            }
          }
        } catch {
          // Non-fatal: fall through to localStorage check
        }
      }

      if (!onboardingDone) {
        // Offline / mock mode — honour localStorage flags.
        const raw = localStorage.getItem('canopy-onboarding');
        const completed = raw
          ? (JSON.parse(raw) as { completed?: boolean }).completed
          : false;
        if (!completed) {
          const legacy = localStorage.getItem('canopy-onboarding-complete');
          if (legacy !== 'true') {
            goto('/onboarding');
            return;
          }
        }
      }
      // ─────────────────────────────────────────────────────────────────────

      // 2. Start connection polling now that _token is set (or mock is active).
      //    Do NOT start polling before auth resolves: health.get() bypasses
      //    request() and can flip useMock=false while _token is still null.
      stopPolling = connectionStore.startPolling(30_000);

      // 3. Subscribe to the activity SSE stream after auth so the token is
      //    available when the Authorization header is attached.
      activityStore.subscribe();

      // 4. Load workspaces from localStorage
      workspaceStore.fetchWorkspaces();

      // 5. Sync workspace list from backend (sets activeWorkspaceId to backend's active workspace)
      await workspaceStore.syncFromBackend();

      // 6. Initialize organizations — ensure at least one exists, auto-select
      await organizationsStore.ensureDefault();

      // 7. Pre-fetch full hierarchy tree + approvals for sidebar
      if (organizationsStore.current) {
        void hierarchyStore.fetchTree(organizationsStore.current.id);
        void hierarchyStore.fetchDivisions(organizationsStore.current.id);
        void hierarchyStore.fetchDepartments();
        void hierarchyStore.fetchTeams();
      }
      void approvalsStore.fetchApprovals();

      // 8. Load agents & projects: resolve workspace context first
      const ws = workspaceStore.activeWorkspace;
      const wsId = workspaceStore.activeWorkspaceId ?? undefined;

      // 9. Pre-fetch projects so goals and other project-dependent pages work
      void projectsStore.fetchProjects(wsId);
      if (ws) {
        workspaceStore.scanAndLoadAgents(ws.path).then(() => {
          workspaceStore.watchActive();
          // If scan didn't load any agents (browser mode / empty scan), fall back to API
          if (agentsStore.agents.length === 0) {
            void agentsStore.fetchAgents(wsId);
          }
        });
      } else {
        void agentsStore.fetchAgents(wsId);
      }
    });

    // Load adapter choice and miosaCloud setting from Tauri secure store
    // (written during onboarding; no-op in browser dev mode)
    void settingsStore.loadFromTauriStore();

    paletteStore.registerBuiltins(goto, {});
    return () => {
      stopPolling?.();
      activityStore.unsubscribe();
    };
  });

  // Keyboard shortcuts
  onMount(() => {
    function handleKeyDown(e: KeyboardEvent) {
      const meta = e.metaKey || e.ctrlKey;
      if (meta && (e.key === 'k' || e.key === 'K')) { e.preventDefault(); paletteStore.toggle(); return; }
      if (!meta) return;
      if (e.key === '\\') { e.preventDefault(); toggleSidebar(); return; }
      if (e.key === ',') { e.preventDefault(); goto('/app/settings'); return; }
      if (e.key === 't' || e.key === 'T') { e.preventDefault(); goto('/app/terminal'); return; }
      const idx = ['1', '2', '3'].indexOf(e.key);
      if (idx !== -1) { e.preventDefault(); goto(NAV_ROUTES[idx]); }
    }
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  });

  // Wire user display name from onboarding
  let userName = $state<string | null>(null);
  $effect(() => {
    if (!browser) return;
    const name = localStorage.getItem('canopy-display-name');
    if (name) userName = name;
  });
  const user = $derived(userName ? { name: userName, email: '' } : null);
</script>

<!-- App shell with sidebar + main content -->
<div class="app-shell" class:has-titlebar={isTauri() && isMacOS()}>
  <Sidebar bind:isCollapsed={sidebarCollapsed} onToggle={toggleSidebar} {user} />
  <main class="main-content" id="main-content">
    {@render children()}
    <ConnectionStatusBar />
  </main>
</div>

<!-- Global overlays -->
<CommandPalette />
<ToastContainer />
<ActivityWidget />

<style>
  .app-shell {
    height: 100dvh; width: 100vw; display: flex; overflow: hidden;
    background: var(--bg-primary); position: relative;
    background-image: radial-gradient(ellipse at 20% 0%, rgba(255,255,255,0.015) 0%, transparent 60%);
  }
  .app-shell.has-titlebar {
    padding-top: 28px;
    height: calc(100dvh - 28px);
  }
  .main-content {
    flex: 1; height: 100%; display: flex; flex-direction: column;
    min-width: 0; overflow: hidden; background: var(--bg-secondary);
    box-shadow: inset 1px 0 0 rgba(255,255,255,0.04); position: relative;
  }
</style>
