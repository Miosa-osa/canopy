/**
 * Global UI state — Svelte 5 runes.
 * L0: always loaded. ≤ 4 global stores, no sprawl.
 * Pattern: Svelte 5 class-based store per FOUNDATION.md §4.
 */

type Theme = "dark" | "light";

const LS_WORKSPACE_KEY = "canopy.currentWorkspaceSlug";
const LS_WORKSPACE_RAIL_KEY = "canopy.showWorkspaceRail";
const LS_SIDEBAR_COLLAPSED_KEY = "canopy.sidebar.collapsed";
/** Below this viewport width the sidebar auto-collapses on first construction. */
const NARROW_VIEWPORT_PX = 800;

class UIStore {
  theme = $state<Theme>("dark");
  sidebarCollapsed = $state(false);
  commandPaletteOpen = $state(false);
  keywordSearchOpen = $state(false);
  newSessionModalOpen = $state(false);
  currentWorkspaceSlug = $state<string | null>(null);
  workspaceSwitcherOpen = $state(false);
  showWorkspaceRail = $state(false);

  constructor() {
    // Lazy-read persisted workspace slug on first construction (SSR-safe).
    if (typeof localStorage !== "undefined") {
      const saved = localStorage.getItem(LS_WORKSPACE_KEY);
      if (saved) this.currentWorkspaceSlug = saved;
      this.showWorkspaceRail =
        localStorage.getItem(LS_WORKSPACE_RAIL_KEY) === "true";

      // Sidebar collapsed state — persisted preference wins; otherwise
      // auto-collapse on narrow viewports for first-run mobile users.
      const persistedCollapsed = localStorage.getItem(LS_SIDEBAR_COLLAPSED_KEY);
      if (persistedCollapsed !== null) {
        this.sidebarCollapsed = persistedCollapsed === "true";
      } else if (
        typeof window !== "undefined" &&
        window.innerWidth < NARROW_VIEWPORT_PX
      ) {
        this.sidebarCollapsed = true;
      }
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

  /** Set sidebar collapsed state and persist to localStorage (SSR-safe). */
  setSidebarCollapsed(collapsed: boolean): void {
    this.sidebarCollapsed = collapsed;
    if (typeof localStorage !== "undefined") {
      localStorage.setItem(LS_SIDEBAR_COLLAPSED_KEY, String(collapsed));
    }
  }

  toggleSidebar(): void {
    this.setSidebarCollapsed(!this.sidebarCollapsed);
  }

  openCommandPalette() {
    this.commandPaletteOpen = true;
  }

  closeCommandPalette() {
    this.commandPaletteOpen = false;
  }

  openKeywordSearch(): void {
    this.keywordSearchOpen = true;
  }

  closeKeywordSearch(): void {
    this.keywordSearchOpen = false;
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

  openNewSessionModal(): void {
    this.newSessionModalOpen = true;
  }

  closeNewSessionModal(): void {
    this.newSessionModalOpen = false;
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

  setWorkspaceRail(show: boolean): void {
    this.showWorkspaceRail = show;
    if (typeof localStorage !== "undefined") {
      localStorage.setItem(LS_WORKSPACE_RAIL_KEY, String(show));
    }
  }

  toggleWorkspaceRail(): void {
    this.setWorkspaceRail(!this.showWorkspaceRail);
  }
}

export const ui = new UIStore();
