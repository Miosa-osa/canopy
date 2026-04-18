/**
 * Global UI state — Svelte 5 runes.
 * L0: always loaded. ≤ 4 global stores, no sprawl.
 * Pattern: Svelte 5 class-based store per FOUNDATION.md §4.
 */

type Theme = "dark" | "light";

const LS_WORKSPACE_KEY = "canopy.currentWorkspaceSlug";

class UIStore {
  theme = $state<Theme>("dark");
  sidebarCollapsed = $state(false);
  commandPaletteOpen = $state(false);
  currentWorkspaceSlug = $state<string | null>(null);
  workspaceSwitcherOpen = $state(false);

  constructor() {
    // Lazy-read persisted workspace slug on first construction (SSR-safe).
    if (typeof localStorage !== "undefined") {
      const saved = localStorage.getItem(LS_WORKSPACE_KEY);
      if (saved) this.currentWorkspaceSlug = saved;
    }
  }

  setTheme(next: Theme) {
    this.theme = next;
    if (typeof document !== "undefined") {
      // data-theme drives Canopy's OKLCh token selectors.
      // .dark drives Foundation primitive CSS (Modal, Tabs, etc.).
      document.documentElement.setAttribute("data-theme", next);
      document.documentElement.classList.toggle("dark", next === "dark");
    }
  }

  toggleTheme() {
    this.setTheme(this.theme === "dark" ? "light" : "dark");
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

  /** Set the active workspace slug and persist to localStorage (SSR-safe). */
  setCurrentWorkspace(slug: string | null): void {
    this.currentWorkspaceSlug = slug;
    if (typeof localStorage !== "undefined") {
      if (slug === null) {
        localStorage.removeItem(LS_WORKSPACE_KEY);
      } else {
        localStorage.setItem(LS_WORKSPACE_KEY, slug);
      }
    }
  }

  openWorkspaceSwitcher(): void {
    this.workspaceSwitcherOpen = true;
  }

  closeWorkspaceSwitcher(): void {
    this.workspaceSwitcherOpen = false;
  }

  toggleWorkspaceSwitcher(): void {
    this.workspaceSwitcherOpen = !this.workspaceSwitcherOpen;
  }
}

export const ui = new UIStore();
