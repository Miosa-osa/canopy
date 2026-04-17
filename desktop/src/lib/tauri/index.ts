/**
 * Tauri API re-exports + environment detection.
 * All Tauri imports in the app go through this module, never direct.
 * This lets us stub/mock cleanly in tests and browser dev mode.
 */

/**
 * Returns true when running inside a Tauri desktop window.
 * False in browser dev mode and tests.
 */
export function isTauri(): boolean {
  return typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;
}

// Re-export the Tauri APIs the app uses so import paths stay consistent.
// Actual Tauri modules are only resolvable at runtime inside Tauri — these
// are dynamic to avoid build-time failures in SSR/test environments.
export async function getTauriStore() {
  if (!isTauri()) {
    throw new Error('getTauriStore called outside Tauri context');
  }
  return import('@tauri-apps/plugin-store');
}

export async function getTauriDialog() {
  if (!isTauri()) {
    throw new Error('getTauriDialog called outside Tauri context');
  }
  return import('@tauri-apps/plugin-dialog');
}

export async function getTauriProcess() {
  if (!isTauri()) {
    throw new Error('getTauriProcess called outside Tauri context');
  }
  return import('@tauri-apps/plugin-process');
}
