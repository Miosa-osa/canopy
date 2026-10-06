/**
 * auth-guard.ts
 *
 * Resolves authentication + onboarding state after initializeAuth() has run.
 * Returns true if the user is considered onboarded and may proceed into the app.
 * Returns false if they should be redirected to /onboarding.
 *
 * Must only be called AFTER initializeAuth() resolves so that the token and
 * mock-mode flags are already set.
 */

import { getToken, isMockEnabled, workspaces, agents } from "$api/client";

export async function resolveAuthState(): Promise<boolean> {
  // Case 1: authenticated session — treat as fully onboarded.
  if (!isMockEnabled() && getToken()) {
    localStorage.setItem("canopy-onboarding-complete", "true");
    localStorage.setItem(
      "canopy-onboarding",
      JSON.stringify({ completed: true }),
    );
    return true;
  }

  // Case 2: backend reachable but no token — check for existing workspace + agent data.
  if (!isMockEnabled()) {
    try {
      const wsList = await workspaces.list();
      if (wsList.length > 0) {
        const agentList = await agents.list(wsList[0].id);
        if (agentList.length > 0) {
          localStorage.setItem("canopy-onboarding-complete", "true");
          localStorage.setItem(
            "canopy-onboarding",
            JSON.stringify({ completed: true }),
          );
          return true;
        }
      }
    } catch {
      // Non-fatal: fall through to localStorage check.
    }
  }

  // Case 3: offline / mock mode — honour localStorage flags.
  const raw = localStorage.getItem("canopy-onboarding");
  const completed = raw
    ? (JSON.parse(raw) as { completed?: boolean }).completed
    : false;
  if (completed) return true;

  const legacy = localStorage.getItem("canopy-onboarding-complete");
  return legacy === "true";
}
