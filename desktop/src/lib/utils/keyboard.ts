/**
 * Keyboard shortcut helpers.
 * Global shortcuts registered in +layout.svelte.
 */

import { ui } from '$lib/stores/ui.svelte.js';

/**
 * Canonical Canopy keyboard shortcuts. Keep in sync with docs/02-frontend-design.md §8.
 */
export function handleGlobalShortcut(e: KeyboardEvent): void {
  if (!e.metaKey || !e.shiftKey) return;

  switch (e.key) {
    case 'D':
      e.preventDefault();
      ui.toggleTheme();
      break;
    case 'L':
      e.preventDefault();
      ui.toggleSidebar();
      break;
    case 'W':
      e.preventDefault();
      ui.toggleWorkspaceSwitcher();
      break;
    default:
      // no-op; future shortcuts land here
      break;
  }
}
