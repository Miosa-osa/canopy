/**
 * Theme Registry — multi-theme store with xterm palette sync.
 *
 * Each ThemeDefinition carries both:
 *   - `colors`   → mapped to Canopy CSS custom props (--bg, --fg, etc.)
 *   - `terminal` → passed directly to xterm.js Terminal({ theme })
 *
 * The active theme is persisted to localStorage under `canopy.theme.registry.id`.
 * CSS vars are applied to document.documentElement on every theme change.
 *
 * Does NOT touch theme.svelte.ts — additive layer only.
 * CSS prefix: tr- (theme-registry)
 */

// ── Types ──────────────────────────────────────────────────────────────────────

export interface ThemeColors {
  bg: string;
  bgElevated: string;
  bgInset: string;
  surface: string;
  fg: string;
  fgMuted: string;
  fgSubtle: string;
  border: string;
  accent: string;
  accentFg: string;
  signalSuccess: string;
  signalWarning: string;
  signalError: string;
  signalThinking: string;
}

export interface ThemeTerminal {
  background: string;
  foreground: string;
  cursor: string;
  selectionBackground: string;
  black: string;
  red: string;
  green: string;
  yellow: string;
  blue: string;
  magenta: string;
  cyan: string;
  white: string;
  brightBlack: string;
  brightRed: string;
  brightGreen: string;
  brightYellow: string;
  brightBlue: string;
  brightMagenta: string;
  brightCyan: string;
  brightWhite: string;
}

export interface ThemeDefinition {
  id: string;
  name: string;
  variant: "dark" | "light";
  colors: ThemeColors;
  terminal: ThemeTerminal;
}

// ── Preset definitions ─────────────────────────────────────────────────────────

export const themes: ThemeDefinition[] = [
  // 1. Canopy Dark (matches existing Multica OKLCh palette, dark mode)
  {
    id: "canopy-dark",
    name: "Canopy Dark",
    variant: "dark",
    colors: {
      bg: "oklch(0.18 0.005 285.823)",
      bgElevated: "oklch(0.21 0.006 285.885)",
      bgInset: "oklch(0.274 0.006 286.033)",
      surface: "oklch(0.21 0.006 285.885)",
      fg: "oklch(0.985 0 0)",
      fgMuted: "oklch(0.705 0.015 286.067)",
      fgSubtle: "oklch(0.552 0.016 285.938)",
      border: "oklch(1 0 0 / 10%)",
      accent: "oklch(0.65 0.16 255)",
      accentFg: "oklch(0.985 0 0)",
      signalSuccess: "oklch(0.65 0.15 145)",
      signalWarning: "oklch(0.70 0.16 85)",
      signalError: "oklch(0.704 0.191 22.216)",
      signalThinking: "oklch(0.65 0.16 255)",
    },
    terminal: {
      background: "transparent",
      foreground: "#e5e5e5",
      cursor: "#7ec8e3",
      selectionBackground: "#3a3a5c",
      black: "#1c1c2e",
      red: "#e06c75",
      green: "#78d97c",
      yellow: "#fbbf24",
      blue: "#60a5fa",
      magenta: "#a78bfa",
      cyan: "#34d399",
      white: "#abb2bf",
      brightBlack: "#4a4a6a",
      brightRed: "#f87171",
      brightGreen: "#86efac",
      brightYellow: "#fde68a",
      brightBlue: "#93c5fd",
      brightMagenta: "#c4b5fd",
      brightCyan: "#6ee7b7",
      brightWhite: "#f5f5f7",
    },
  },

  // 2. Canopy Light (matches existing Multica OKLCh palette, light mode)
  {
    id: "canopy-light",
    name: "Canopy Light",
    variant: "light",
    colors: {
      bg: "oklch(1 0 0)",
      bgElevated: "oklch(1 0 0)",
      bgInset: "oklch(0.967 0.001 286.375)",
      surface: "oklch(0.985 0 0)",
      fg: "oklch(0.141 0.005 285.823)",
      fgMuted: "oklch(0.552 0.016 285.938)",
      fgSubtle: "oklch(0.705 0.015 286.067)",
      border: "oklch(0.92 0.004 286.32)",
      accent: "oklch(0.55 0.16 255)",
      accentFg: "oklch(0.985 0 0)",
      signalSuccess: "oklch(0.55 0.16 145)",
      signalWarning: "oklch(0.75 0.16 85)",
      signalError: "oklch(0.577 0.245 27.325)",
      signalThinking: "oklch(0.55 0.16 255)",
    },
    terminal: {
      background: "#fafafa",
      foreground: "#383a42",
      cursor: "#2257a0",
      selectionBackground: "#c8d3e6",
      black: "#e5e5e5",
      red: "#e45649",
      green: "#50a14f",
      yellow: "#c18401",
      blue: "#2257a0",
      magenta: "#a626a4",
      cyan: "#0184bc",
      white: "#696c77",
      brightBlack: "#c8c8c8",
      brightRed: "#e06c75",
      brightGreen: "#98c379",
      brightYellow: "#d19a66",
      brightBlue: "#61afef",
      brightMagenta: "#c678dd",
      brightCyan: "#56b6c2",
      brightWhite: "#383a42",
    },
  },

  // 3. Tokyo Night
  {
    id: "tokyo-night",
    name: "Tokyo Night",
    variant: "dark",
    colors: {
      bg: "#1a1b26",
      bgElevated: "#24283b",
      bgInset: "#1f2335",
      surface: "#24283b",
      fg: "#c0caf5",
      fgMuted: "#9aa5ce",
      fgSubtle: "#565f89",
      border: "#292e42",
      accent: "#7aa2f7",
      accentFg: "#1a1b26",
      signalSuccess: "#9ece6a",
      signalWarning: "#e0af68",
      signalError: "#f7768e",
      signalThinking: "#7aa2f7",
    },
    terminal: {
      background: "#1a1b26",
      foreground: "#c0caf5",
      cursor: "#c0caf5",
      selectionBackground: "#33467c",
      black: "#15161e",
      red: "#f7768e",
      green: "#9ece6a",
      yellow: "#e0af68",
      blue: "#7aa2f7",
      magenta: "#bb9af7",
      cyan: "#7dcfff",
      white: "#a9b1d6",
      brightBlack: "#414868",
      brightRed: "#f7768e",
      brightGreen: "#9ece6a",
      brightYellow: "#e0af68",
      brightBlue: "#7aa2f7",
      brightMagenta: "#bb9af7",
      brightCyan: "#7dcfff",
      brightWhite: "#c0caf5",
    },
  },

  // 4. Dracula
  {
    id: "dracula",
    name: "Dracula",
    variant: "dark",
    colors: {
      bg: "#282a36",
      bgElevated: "#343746",
      bgInset: "#21222c",
      surface: "#343746",
      fg: "#f8f8f2",
      fgMuted: "#6272a4",
      fgSubtle: "#44475a",
      border: "#44475a",
      accent: "#bd93f9",
      accentFg: "#282a36",
      signalSuccess: "#50fa7b",
      signalWarning: "#ffb86c",
      signalError: "#ff5555",
      signalThinking: "#8be9fd",
    },
    terminal: {
      background: "#282a36",
      foreground: "#f8f8f2",
      cursor: "#f8f8f2",
      selectionBackground: "#44475a",
      black: "#21222c",
      red: "#ff5555",
      green: "#50fa7b",
      yellow: "#f1fa8c",
      blue: "#bd93f9",
      magenta: "#ff79c6",
      cyan: "#8be9fd",
      white: "#f8f8f2",
      brightBlack: "#6272a4",
      brightRed: "#ff6e6e",
      brightGreen: "#69ff94",
      brightYellow: "#ffffa5",
      brightBlue: "#d6acff",
      brightMagenta: "#ff92df",
      brightCyan: "#a4ffff",
      brightWhite: "#ffffff",
    },
  },

  // 5. Solarized Dark
  {
    id: "solarized-dark",
    name: "Solarized Dark",
    variant: "dark",
    colors: {
      bg: "#002b36",
      bgElevated: "#073642",
      bgInset: "#00212b",
      surface: "#073642",
      fg: "#839496",
      fgMuted: "#657b83",
      fgSubtle: "#586e75",
      border: "#073642",
      accent: "#268bd2",
      accentFg: "#fdf6e3",
      signalSuccess: "#859900",
      signalWarning: "#b58900",
      signalError: "#dc322f",
      signalThinking: "#268bd2",
    },
    terminal: {
      background: "#002b36",
      foreground: "#839496",
      cursor: "#839496",
      selectionBackground: "#073642",
      black: "#073642",
      red: "#dc322f",
      green: "#859900",
      yellow: "#b58900",
      blue: "#268bd2",
      magenta: "#d33682",
      cyan: "#2aa198",
      white: "#eee8d5",
      brightBlack: "#002b36",
      brightRed: "#cb4b16",
      brightGreen: "#586e75",
      brightYellow: "#657b83",
      brightBlue: "#839496",
      brightMagenta: "#6c71c4",
      brightCyan: "#93a1a1",
      brightWhite: "#fdf6e3",
    },
  },

  // 6. Solarized Light
  {
    id: "solarized-light",
    name: "Solarized Light",
    variant: "light",
    colors: {
      bg: "#fdf6e3",
      bgElevated: "#fff8e7",
      bgInset: "#eee8d5",
      surface: "#fff8e7",
      fg: "#586e75",
      fgMuted: "#657b83",
      fgSubtle: "#93a1a1",
      border: "#d6cdb5",
      accent: "#268bd2",
      accentFg: "#fdf6e3",
      signalSuccess: "#859900",
      signalWarning: "#b58900",
      signalError: "#dc322f",
      signalThinking: "#268bd2",
    },
    terminal: {
      background: "#fdf6e3",
      foreground: "#657b83",
      cursor: "#586e75",
      selectionBackground: "#eee8d5",
      black: "#073642",
      red: "#dc322f",
      green: "#859900",
      yellow: "#b58900",
      blue: "#268bd2",
      magenta: "#d33682",
      cyan: "#2aa198",
      white: "#eee8d5",
      brightBlack: "#002b36",
      brightRed: "#cb4b16",
      brightGreen: "#586e75",
      brightYellow: "#657b83",
      brightBlue: "#839496",
      brightMagenta: "#6c71c4",
      brightCyan: "#93a1a1",
      brightWhite: "#fdf6e3",
    },
  },
];

// ── CSS var mapping ────────────────────────────────────────────────────────────

/**
 * Maps a ThemeDefinition's colors to Canopy CSS custom property names.
 * Also sets --term-* vars so TerminalSession's CSS-var-based fallbacks stay in sync.
 */
export function getCssVars(theme: ThemeDefinition): Record<string, string> {
  const c = theme.colors;
  const t = theme.terminal;
  const isDark = theme.variant === "dark";
  return {
    // Core backgrounds
    "--bg": c.bg,
    "--bg-elevated": c.bgElevated,
    "--bg-inset": c.bgInset,
    "--surface": c.surface ?? c.bgElevated,
    "--background": c.bg,
    "--card": c.bgElevated,
    "--popover": c.bgElevated,
    "--popover-bg": c.bgElevated,
    "--muted": c.bgInset,
    "--input": c.border,
    "--input-border": c.border,

    // Sidebar (full token set)
    "--sidebar": c.bgElevated,
    "--sidebar-foreground": c.fg,
    "--sidebar-border": c.border,
    "--sidebar-accent": c.accent,
    "--sidebar-accent-foreground": c.accentFg,
    "--sidebar-primary": c.accent,
    "--sidebar-primary-foreground": c.accentFg,
    "--sidebar-ring": c.accent,
    "--color-sidebar": c.bgElevated,

    // Foreground
    "--fg": c.fg,
    "--fg-muted": c.fgMuted,
    "--fg-subtle": c.fgSubtle,
    "--foreground": c.fg,
    "--muted-foreground": c.fgMuted,
    "--card-foreground": c.fg,
    "--popover-foreground": c.fg,
    "--accent-foreground": c.accentFg,
    "--primary-foreground": c.accentFg,

    // Borders
    "--border": c.border,
    "--border-strong": isDark ? `oklch(1 0 0 / 20%)` : `oklch(0 0 0 / 15%)`,
    "--ring": c.accent,

    // Accent + brand
    "--user-accent": c.accent,
    "--user-accent-fg": c.accentFg,
    "--cnp-accent": c.accent,
    "--accent": c.accent,
    "--primary": c.accent,
    "--brand": c.signalThinking,
    "--brand-fg": c.accentFg,

    // Secondary
    "--secondary": c.bgInset,
    "--secondary-foreground": c.fg,

    // Scrollbar
    "--scrollbar-track": isDark ? "oklch(0 0 0 / 5%)" : "oklch(0 0 0 / 3%)",
    "--scrollbar-thumb": isDark ? "oklch(1 0 0 / 12%)" : "oklch(0 0 0 / 15%)",
    "--scrollbar-thumb-hover": isDark
      ? "oklch(1 0 0 / 20%)"
      : "oklch(0 0 0 / 25%)",

    // Status signals
    "--success": c.signalSuccess,
    "--warning": c.signalWarning,
    "--destructive": c.signalError,
    "--info": c.signalThinking,
    "--signal-success": c.signalSuccess,
    "--signal-running": c.signalSuccess,
    "--signal-warn": c.signalWarning,
    "--signal-warning": c.signalWarning,
    "--signal-error": c.signalError,
    "--signal-thinking": c.signalThinking,
    // Terminal CSS vars (keep TerminalSession bg/overlay in sync)
    "--term-fg": t.foreground,
    "--term-cursor": t.cursor,
    "--term-black": t.black,
    "--term-red": t.red,
    "--term-green": t.green,
    "--term-yellow": t.yellow,
    "--term-blue": t.blue,
    "--term-magenta": t.magenta,
    "--term-cyan": t.cyan,
    "--term-white": t.white,
    "--term-bright-black": t.brightBlack,
    "--term-bright-red": t.brightRed,
    "--term-bright-green": t.brightGreen,
    "--term-bright-yellow": t.brightYellow,
    "--term-bright-blue": t.brightBlue,
    "--term-bright-magenta": t.brightMagenta,
    "--term-bright-cyan": t.brightCyan,
    "--term-bright-white": t.brightWhite,

    // Legacy cnp-* aliases (used by Build, SlashCommands, Sandboxes, etc.)
    "--cnp-bg": c.bg,
    "--cnp-bg-elev": c.bgElevated,
    "--cnp-fg": c.fg,
    "--cnp-fg-muted": c.fgMuted,
    "--cnp-border": c.border,

    // Term background for terminal panes
    "--term-bg": t.background,

    // Glass panel overrides
    "--glass-bg": isDark
      ? "rgba(28, 28, 30, 0.8)"
      : "rgba(255, 255, 255, 0.85)",
    "--glass-border": isDark
      ? "rgba(255, 255, 255, 0.1)"
      : "rgba(0, 0, 0, 0.08)",
    "--glass-shadow": isDark
      ? "0 8px 32px 0 rgba(0, 0, 0, 0.3)"
      : "0 8px 32px 0 rgba(31, 38, 135, 0.08)",
  };
}

// ── Storage ────────────────────────────────────────────────────────────────────

const LS_KEY = "canopy.theme.registry.id";

function readLS(): string | null {
  if (typeof localStorage === "undefined") return null;
  return localStorage.getItem(LS_KEY);
}

function writeLS(id: string): void {
  if (typeof localStorage === "undefined") return;
  localStorage.setItem(LS_KEY, id);
}

// ── Store class ────────────────────────────────────────────────────────────────

class ThemeRegistryStore {
  activeThemeId = $state<string>("canopy-dark");

  activeTheme = $derived(
    themes.find((t) => t.id === this.activeThemeId) ?? themes[0],
  );

  constructor() {
    if (typeof localStorage === "undefined") return;

    const saved = readLS();
    if (saved && themes.some((t) => t.id === saved)) {
      this.activeThemeId = saved;
    }

    // Apply on boot (client-side only)
    this.#applyToDOM(this.activeTheme);
  }

  setTheme(id: string): void {
    const found = themes.find((t) => t.id === id);
    if (!found) return;
    this.activeThemeId = id;
    writeLS(id);
    this.#applyToDOM(found);
  }

  #applyToDOM(theme: ThemeDefinition): void {
    if (typeof document === "undefined") return;
    const vars = getCssVars(theme);
    for (const [prop, value] of Object.entries(vars)) {
      document.documentElement.style.setProperty(prop, value);
    }
    // Keep data-theme attribute + .dark class in sync
    document.documentElement.setAttribute("data-theme", theme.variant);
    document.documentElement.classList.toggle("dark", theme.variant === "dark");

    // Sync with the legacy theme store so it doesn't override on next boot
    try {
      localStorage.setItem(
        "canopy.theme.mode",
        theme.variant === "dark" ? "dark" : "light",
      );
    } catch {}
  }
}

export const themeRegistry = new ThemeRegistryStore();
