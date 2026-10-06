<script lang="ts">
  import { goto } from '$app/navigation';
  import { browser } from '$app/environment';
  import { onMount } from 'svelte';
  import { initializeAuth, getToken, isMockEnabled, isFirstRun } from '$api/client';
  import { isTauri } from '$lib/utils/platform';

  /**
   * Determine where to send the user after auth initializes.
   *
   * Decision tree:
   *
   *  LOCAL DESKTOP (Tauri) — no auth required:
   *    1a. Onboarding not complete → /onboarding
   *    1b. Onboarding complete     → /app
   *
   *  WEB / CLOUD MODE — auth required:
   *  1. initializeAuth() — probes /health, reads /auth/status (_firstRun),
   *     restores saved token, attempts dev auto-login if VITE_DEV_EMAIL set.
   *
   *  2. Backend unreachable (isMockEnabled):
   *       → /onboarding   (offline / mock setup flow)
   *
   *  3. Backend reachable, no users yet (_firstRun = true):
   *       → /auth         (show registration form)
   *
   *  4. Backend reachable, users exist, but no valid token:
   *       → /auth         (show login form)
   *
   *  5. Backend reachable, valid token, onboarding not complete:
   *       → /onboarding
   *
   *  6. Backend reachable, valid token, onboarding complete:
   *       → /app
   */
  async function resolveDestination(): Promise<'/app' | '/onboarding' | '/auth'> {
    // ── Local desktop mode: no auth required ─────────────────────────────
    // Tauri apps run fully locally. Auth is only needed for MiosaCloud sync,
    // which users can opt into from Settings — not at launch.
    if (isTauri()) {
      return isOnboardingComplete() ? '/app' : '/onboarding';
    }

    // ── Web / cloud mode: auth required ──────────────────────────────────
    await initializeAuth();

    // Case 2 — offline / backend down
    if (isMockEnabled()) {
      return '/onboarding';
    }

    // Case 3 — first install, no users in DB yet
    if (isFirstRun()) {
      return '/auth';
    }

    // Case 4 — users exist but no valid session token
    if (!getToken()) {
      return '/auth';
    }

    // Cases 5 & 6 — authenticated; check onboarding state
    return isOnboardingComplete() ? '/app' : '/onboarding';
  }

  /** Check both localStorage keys used for onboarding state. */
  function isOnboardingComplete(): boolean {
    if (typeof localStorage === 'undefined') return false;
    if (localStorage.getItem('canopy-onboarding-complete') === 'true') return true;
    try {
      const raw = localStorage.getItem('canopy-onboarding');
      return raw ? (JSON.parse(raw) as { completed?: boolean }).completed === true : false;
    } catch {
      return false;
    }
  }

  onMount(async () => {
    if (!browser) return;
    const dest = await resolveDestination();
    goto(dest, { replaceState: true });
  });
</script>
