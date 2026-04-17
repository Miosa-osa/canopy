/**
 * Theme persistence — load/save user theme preference.
 *
 * Storage strategy:
 *   - In Tauri: @tauri-apps/plugin-store (canopy-ui.json, autosaved)
 *   - Outside Tauri (SSR build, E2E, browser dev): localStorage fallback
 *
 * Kept side-effect-free so +layout.svelte stays under the 150-LOC god-file limit.
 */

import { isTauri } from '$lib/tauri/index.js';

export type Theme = 'dark' | 'light';

const STORE_FILE = 'canopy-ui.json';
const STORE_KEY = 'theme';
const LS_KEY = 'canopy-theme';

function isTheme(value: unknown): value is Theme {
  return value === 'dark' || value === 'light';
}

/**
 * Load persisted theme. Returns null if none stored.
 * Never throws — falls through to localStorage on any Tauri-side error.
 */
export async function loadPersistedTheme(): Promise<Theme | null> {
  if (isTauri()) {
    try {
      const { load } = await import('@tauri-apps/plugin-store');
      const store = await load(STORE_FILE, { defaults: {}, autoSave: true });
      const saved = await store.get<string>(STORE_KEY);
      if (isTheme(saved)) return saved;
    } catch {
      // fall through to localStorage
    }
  }

  if (typeof localStorage === 'undefined') return null;
  const saved = localStorage.getItem(LS_KEY);
  return isTheme(saved) ? saved : null;
}

/**
 * Persist theme. Fire-and-forget; silently falls back to localStorage on failure.
 */
export async function persistTheme(theme: Theme): Promise<void> {
  if (isTauri()) {
    try {
      const { load } = await import('@tauri-apps/plugin-store');
      const store = await load(STORE_FILE, { defaults: {}, autoSave: true });
      await store.set(STORE_KEY, theme);
      return;
    } catch {
      // fall through to localStorage
    }
  }

  if (typeof localStorage !== 'undefined') {
    localStorage.setItem(LS_KEY, theme);
  }
}
