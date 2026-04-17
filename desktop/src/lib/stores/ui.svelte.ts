/**
 * Global UI state — Svelte 5 runes.
 * L0: always loaded. ≤ 4 global stores, no sprawl.
 * Pattern: Svelte 5 class-based store per FOUNDATION.md §4.
 */

type Theme = 'dark' | 'light';

class UIStore {
  theme = $state<Theme>('dark');
  sidebarCollapsed = $state(false);
  commandPaletteOpen = $state(false);

  setTheme(next: Theme) {
    this.theme = next;
    if (typeof document !== 'undefined') {
      document.documentElement.setAttribute('data-theme', next);
    }
  }

  toggleTheme() {
    this.setTheme(this.theme === 'dark' ? 'light' : 'dark');
  }

  toggleSidebar() {
    this.sidebarCollapsed = !this.sidebarCollapsed;
  }

  openCommandPalette() {
    this.commandPaletteOpen = true;
  }

  closeCommandPalette() {
    this.commandPaletteOpen = false;
  }
}

export const ui = new UIStore();
