<script lang="ts">
  import { goto } from '$app/navigation';
  import { browser } from '$app/environment';
  import { onMount } from 'svelte';
  import { initializeAuth, getToken, isMockEnabled, workspaces, agents } from '$api/client';

  /**
   * Determine whether onboarding has already been completed.
   *
   * Priority order:
   * 1. Backend is reachable AND caller has a valid auth token → backend has
   *    real data; mark onboarding done and go straight to /app.
   * 2. Backend is reachable AND workspaces + agents exist (token-less probe
   *    path, e.g. public API) → same result.
   * 3. Fall back to localStorage flags (legacy / offline / mock mode).
   */
  async function resolveDestination(): Promise<'/app' | '/onboarding'> {
    // Run auth probe: checks health, restores saved token, attempts dev login.
    await initializeAuth();

    // If we ended up with a valid token the backend is live and the user is
    // already authenticated — no need to re-onboard regardless of localStorage.
    if (!isMockEnabled() && getToken()) {
      // Persist both keys so the layout guard also short-circuits.
      localStorage.setItem('canopy-onboarding-complete', 'true');
      localStorage.setItem(
        'canopy-onboarding',
        JSON.stringify({ completed: true }),
      );
      return '/app';
    }

    // Backend reachable but no auth token yet — check whether workspaces with
    // agents exist (handles setups that don't use token-based auth).
    if (!isMockEnabled()) {
      try {
        const wsList = await workspaces.list();
        if (wsList.length > 0) {
          // Check if any workspace has agents (scoped to first workspace)
          const agentList = await agents.list(wsList[0].id);
          if (agentList.length > 0) {
            localStorage.setItem('canopy-onboarding-complete', 'true');
            localStorage.setItem(
              'canopy-onboarding',
              JSON.stringify({ completed: true }),
            );
            return '/app';
          }
        }
      } catch {
        // Non-fatal: fall through to localStorage check
      }
    }

    // Offline / mock mode — honour existing localStorage flags.
    const raw = localStorage.getItem('canopy-onboarding');
    const completed = raw
      ? (JSON.parse(raw) as { completed?: boolean }).completed
      : false;
    if (completed) return '/app';

    const legacy = localStorage.getItem('canopy-onboarding-complete');
    if (legacy === 'true') return '/app';

    return '/onboarding';
  }

  onMount(async () => {
    if (!browser) return;
    const dest = await resolveDestination();
    goto(dest, { replaceState: true });
  });
</script>
