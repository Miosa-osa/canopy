<script lang="ts">
/**
 * Root layout — inset card shell (Core-OSS pattern, docs/02-frontend-design.md §5).
 *
 * Responsibilities (deliberately scoped):
 *   1. Mount theme (load persisted, apply to <html>).
 *   2. Register global keyboard shortcuts.
 *   3. Render the shell geometry (sidebar + inset main).
 *
 * Persistence logic, keyboard map, and theme toggle chrome are composed from
 * smaller modules to keep this file under the 150-LOC god-file limit.
 */
import '../app.css';
import { onMount } from 'svelte';
import ThemeToggle from '$lib/design/primitives/ThemeToggle.svelte';
import { loadPersistedTheme, persistTheme } from '$lib/stores/theme-persistence.js';
import { ui } from '$lib/stores/ui.svelte.js';
import { handleGlobalShortcut } from '$lib/utils/keyboard.js';

let { children } = $props();

onMount(async () => {
  const saved = await loadPersistedTheme();
  if (saved) ui.setTheme(saved);
});

$effect(() => {
  const theme = ui.theme;
  if (typeof document === 'undefined') return;
  document.documentElement.setAttribute('data-theme', theme);
  void persistTheme(theme);
});
</script>

<svelte:window onkeydown={handleGlobalShortcut} />

<div class="shell">
  <aside
    class="sidebar"
    class:collapsed={ui.sidebarCollapsed}
    aria-label="Primary navigation"
  >
    <div class="sidebar-wordmark">
      <span class="wordmark-text">Canopy</span>
    </div>

    <nav class="sidebar-nav" aria-label="Main menu">
      <div class="nav-placeholder" aria-hidden="true"></div>
    </nav>

    <div class="sidebar-footer" aria-label="Sidebar footer">
      <div class="footer-placeholder" aria-hidden="true"></div>
    </div>
  </aside>

  <div class="main-container">
    <main>
      {@render children()}
    </main>
  </div>
</div>

<ThemeToggle />

<style>
  .shell {
    background: var(--sidebar);
    display: flex;
    height: 100vh;
    overflow: hidden;
  }

  .sidebar {
    width: 220px;
    display: flex;
    flex-direction: column;
    flex-shrink: 0;
    transition: width var(--dur-normal) var(--ease-io);
    overflow: hidden;
  }

  .sidebar.collapsed {
    width: 48px;
  }

  .sidebar-wordmark {
    padding: var(--space-4) var(--space-3);
    display: flex;
    align-items: center;
    gap: var(--space-2);
    min-height: 48px;
    flex-shrink: 0;
  }

  .wordmark-text {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    letter-spacing: -0.02em;
    color: var(--fg);
    white-space: nowrap;
    transition: opacity var(--dur-fast) var(--ease-out);
  }

  .sidebar.collapsed .wordmark-text {
    opacity: 0;
    pointer-events: none;
  }

  .sidebar-nav {
    flex: 1;
    padding: var(--space-2) var(--space-2);
    overflow-y: auto;
  }

  .sidebar-footer {
    padding: var(--space-3);
    flex-shrink: 0;
    border-top: 1px solid var(--border);
  }

  .main-container {
    flex: 1;
    padding: var(--space-2) var(--space-2) var(--space-2) 0;
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    min-width: 0;
  }

  main {
    flex: 1;
    background: var(--bg);
    border-radius: var(--radius-lg);
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }
</style>
